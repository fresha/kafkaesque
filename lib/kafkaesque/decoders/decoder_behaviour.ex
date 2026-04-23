defmodule Kafkaesque.Decoders.DecoderBehaviour do
  @moduledoc """
  Behaviour for all decoders
  """

  @callback decode!(message_value :: binary, opts :: Keyword.t()) ::
              {:ok, map} | {:error, any} | no_return
end
