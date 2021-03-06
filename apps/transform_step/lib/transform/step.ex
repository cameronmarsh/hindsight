defprotocol Transform.Step do
  @spec transform_dictionary(step :: t, dictionary :: Dictionary.t()) ::
          {:ok, Dictionary.t()} | {:error, term}
  def transform_dictionary(step, dictionary)

  @spec create_function(step :: t, dictionary :: Dictionary.t()) ::
          {:ok, Transformer.transform_function()} | {:error, term}
  def create_function(step, dictionary)
end
