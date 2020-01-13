defmodule Extract.Steps.Context do
  @type source_opts :: [
          read: :lines | :bytes,
          byte_count: integer()
        ]

  @type source :: (source_opts -> Enumerable.t())

  @type t() :: %__MODULE__{
          response: Tesla.Env.t(),
          variables: map,
          source: source
        }
  defstruct response: nil, variables: %{}, source: nil

  @spec new() :: %__MODULE__{}
  def new() do
    %__MODULE__{source: fn _ -> [] end}
  end

  @spec get_stream(context :: t, source_opts) :: Enumerable.t()
  def get_stream(%__MODULE__{source: function}, opts \\ []) when is_function(function, 1) do
    function.(opts)
  end

  @spec set_response(context :: t, response :: Tesla.Env.t()) :: t
  def set_response(context, response) do
    Map.put(context, :response, response)
  end

  @spec add_variable(context :: t, name :: String.t(), value :: String.t()) :: t
  def add_variable(context, name, value) do
    new_variables = Map.put(context.variables, name, value)
    Map.put(context, :variables, new_variables)
  end

  @spec set_source(context :: t, source) :: t
  def set_source(context, source) do
    Map.put(context, :source, source)
  end

  @spec apply_variables(context :: t, string :: String.t()) :: String.t()
  def apply_variables(context, string) do
    context.variables
    |> Enum.reduce(string, fn {name, value}, buffer ->
      String.replace(buffer, "<" <> name <> ">", value)
    end)
  end

  @spec lines_or_bytes(source_opts) :: :line | integer()
  def lines_or_bytes(opts) do
    case Keyword.get(opts, :read) do
      nil -> :line
      :lines -> :line
      :bytes -> Keyword.get(opts, :byte_count, 100)
    end
  end
end