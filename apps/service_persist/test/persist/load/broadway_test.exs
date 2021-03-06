defmodule Persist.Load.BroadwayTest do
  use ExUnit.Case
  import Mox
  require Temp.Env
  import AssertAsync

  alias Writer.DLQ.DeadLetter
  @moduletag capture_log: true

  Temp.Env.modify([
    %{
      app: :service_persist,
      key: Persist.Load.Broadway,
      update: fn config ->
        Keyword.put(config, :dlq, Persist.DLQMock)
      end
    }
  ])

  setup do
    Process.flag(:trap_exit, true)

    transform =
      Transform.new!(
        id: "transform-1",
        dataset_id: "ds1",
        subset_id: "sb1",
        dictionary: [
          %Dictionary.Type.String{name: "name"},
          %Dictionary.Type.Integer{name: "age"}
        ],
        steps: [
          Transform.MoveField.new!(from: "name", to: "fullname")
        ]
      )

    load =
      Load.Persist.new!(
        id: "load-1",
        dataset_id: "ds1",
        subset_id: "fake-name",
        source: "topic-a",
        destination: "table-a"
      )

    [load: load, transform: transform]
  end

  setup :set_mox_global
  setup :verify_on_exit!

  test "will decode message and pass to writer", %{load: load, transform: transform} do
    test = self()

    writer = fn msgs ->
      send(test, {:write, msgs})
      :ok
    end

    {:ok, broadway} =
      Persist.Load.Broadway.start_link(load: load, transform: transform, writer: writer)

    messages = [
      %{value: %{"name" => "bob", "age" => 21} |> Jason.encode!()},
      %{value: %{"name" => "joe", "age" => 43} |> Jason.encode!()}
    ]

    ref = Broadway.test_messages(broadway, messages)

    expected = [
      %{"fullname" => "bob", "age" => 21},
      %{"fullname" => "joe", "age" => 43}
    ]

    assert_receive {:write, ^expected}

    assert_receive {:ack, ^ref, successful, []}
    assert 2 == length(successful)
    assert_down(broadway)
  end

  test "sends message to dlq if it fails to decode", %{load: load, transform: transform} do
    test = self()

    writer = fn msgs ->
      send(test, {:write, msgs})
      :ok
    end

    Persist.DLQMock
    |> expect(:write, fn messages ->
      send(test, {:dlq, messages})
      :ok
    end)

    {:ok, broadway} =
      Persist.Load.Broadway.start_link(load: load, transform: transform, writer: writer)

    messages = [
      %{value: %{"name" => "bob", "age" => 21} |> Jason.encode!()},
      %{value: "{\"one\""}
    ]

    ref = Broadway.test_messages(broadway, messages)

    {:error, reason} = messages |> Enum.at(1) |> Map.get(:value) |> Jason.decode()

    expected_dead_letter =
      DeadLetter.new(
        dataset_id: "ds1",
        original_message: Enum.at(messages, 1),
        app_name: "service_persist",
        reason: reason
      )

    assert_receive {:write, [%{"fullname" => "bob", "age" => 21}]}
    assert_receive {:dlq, [^expected_dead_letter]}

    assert_receive {:ack, ^ref, [%{data: %{"fullname" => "bob", "age" => 21}}], []}
    assert_receive {:ack, ^ref, [], [%{data: ^expected_dead_letter}]}
    assert_down(broadway)
  end

  defp assert_down(pid) do
    Process.exit(pid, :normal)
    assert_receive {:EXIT, ^pid, _}, 10_000

    assert_async do
      assert [] == Persist.Load.Registry.registered_processes()
    end
  end
end
