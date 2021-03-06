defmodule Dictionary.Type.Latitude do
  use Definition, schema: Dictionary.Type.Latitude.V1
  use Dictionary.JsonEncoder

  defstruct version: 1, name: nil, description: ""

  defimpl Dictionary.Type.Normalizer, for: __MODULE__ do
    def normalize(_latitude, value) do
      parse(value)
      |> Ok.map(&validate/1)
    end

    defp parse(float) when is_float(float), do: Ok.ok(float)

    defp parse(string) when is_binary(string) do
      case Float.parse(string) do
        {float, _} -> Ok.ok(float)
        _ -> {:error, :invalid_latitude}
      end
    end

    defp parse(integer) when is_integer(integer), do: Ok.ok(integer / 1)

    def validate(float) when -90.0 <= float and float <= 90.0, do: {:ok, float}
    def validate(_float), do: {:error, :invalid_latitude}
  end
end

defmodule Dictionary.Type.Latitude.V1 do
  use Definition.Schema

  def s do
    schema(%Dictionary.Type.Latitude{
      version: version(1),
      name: required_string(),
      description: string()
    })
  end
end
