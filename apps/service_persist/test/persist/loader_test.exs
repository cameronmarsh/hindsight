defmodule Persist.LoaderTest do
  use ExUnit.Case
  require Temp.Env

  import Mox

  @instance Persist.Application.instance()

  Temp.Env.modify([
    %{
      app: :service_persist,
      key: Persist.Loader,
      set: [
        writer: Persist.WriterMock,
        broadway: BroadwayMock
      ]
    }
  ])

  setup :set_mox_global
  setup :verify_on_exit!

  setup do
    Process.flag(:trap_exit, true)
    Brook.Test.clear_view_state(@instance, "transformations")

    transform =
      Transform.new!(
        id: "transform-1",
        dataset_id: "ds1",
        subset_id: "fake-name",
        dictionary: [
          %Dictionary.Type.String{name: "name"},
          %Dictionary.Type.Integer{name: "age"}
        ],
        steps: []
      )

    Brook.Test.with_event(@instance, fn ->
      Persist.Transformations.persist(transform)
    end)

    load =
      Load.Persist.new!(
        id: "load-1",
        dataset_id: "ds1",
        subset_id: "fake-name",
        source: "topic-a",
        destination: "table-a"
      )

    on_exit(fn ->
      Persist.Load.Supervisor.kill_all_children()
    end)

    [load: load, transform: transform]
  end

  describe "start writer" do
    setup do
      BroadwayMock
      |> stub(:start_link, fn _ -> {:ok, :broadway_pid} end)

      :ok
    end

    test "will start persist writer", %{load: load, transform: transform} do
      test = self()

      Persist.WriterMock
      |> expect(:start_link, fn init_arg ->
        send(test, {:start_link, init_arg})
        {:ok, :writer_pid}
      end)

      {:ok, pid} = Persist.Loader.start_link(load: load)

      assert_receive {:start_link, init_arg}
      assert load == Keyword.get(init_arg, :load)
      assert transform.dictionary == Keyword.get(init_arg, :dictionary)

      assert_down(pid)
    end

    test "will retry starting writer if it fails to start", %{load: load} do
      test = self()
      {:ok, agent} = Agent.start_link(fn -> 2 end, name: :test_agent)

      Persist.WriterMock
      |> expect(:start_link, 3, fn init_arg ->
        send(test, {:start_link, init_arg})

        case Agent.get_and_update(:test_agent, fn s -> {s, s - 1} end) do
          0 -> {:ok, :writer_id}
          n -> {:error, "remaining #{n}"}
        end
      end)

      {:ok, pid} = Persist.Loader.start_link(load: load)

      Enum.each(1..3, fn _ -> assert_receive {:start_link, _} end)

      assert_down(pid)
      assert_down(agent)
    end

    test "will die if fails to start writer", %{load: load} do
      Persist.WriterMock
      |> expect(:start_link, 4, fn _ -> {:error, "failure"} end)

      assert {:error, "failure"} = Persist.Loader.start_link(load: load)
    end
  end

  describe "broadway" do
    setup do
      test = self()

      Persist.WriterMock
      |> stub(:start_link, fn _ -> {:ok, :writer_pid} end)
      |> stub(:write, fn :writer_pid, msgs, opts ->
        send(test, {:write, msgs, opts})
        :ok
      end)

      :ok
    end

    test "will start broadway", %{load: load, transform: %{dictionary: dictionary} = transform} do
      test = self()

      BroadwayMock
      |> expect(:start_link, fn init_arg ->
        send(test, {:start_link, init_arg})
        {:ok, :broadway_pid}
      end)

      {:ok, pid} = Persist.Loader.start_link(load: load)
      assert_receive {:start_link, init_arg}
      assert load == Keyword.get(init_arg, :load)
      assert transform == Keyword.get(init_arg, :transform)
      write_function = Keyword.get(init_arg, :writer)
      write_function.([:ok])

      assert_receive {:write, [:ok], [dictionary: ^dictionary]}
      assert_down(pid)
    end

    test "will retry starting broadway", %{load: load} do
      test = self()
      {:ok, agent} = Agent.start_link(fn -> 3 end, name: :test_agent)

      BroadwayMock
      |> stub(:start_link, fn init_arg ->
        send(test, {:start_link, init_arg})

        case Agent.get_and_update(:test_agent, fn s -> {s, s - 1} end) do
          0 -> {:ok, :broadway_pid}
          n -> {:error, "remaining, #{n}"}
        end
      end)

      assert {:ok, pid} = Persist.Loader.start_link(load: load)

      Enum.each(1..4, fn _ -> assert_receive {:start_link, _} end)

      assert_down(pid)
      assert_down(agent)
    end
  end

  defp assert_down(pid) do
    ref = Process.monitor(pid)
    Process.exit(pid, :kill)
    assert_receive {:DOWN, ^ref, _, _, _}
  end
end
