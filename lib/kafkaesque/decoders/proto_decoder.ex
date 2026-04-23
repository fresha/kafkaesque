defmodule Kafkaesque.Decoders.ProtoDecoder do
  @moduledoc """
  Decoder module for plain proto events. Recommended for use
  with kafka based commands servers
  """
  @behaviour Kafkaesque.Decoders.DecoderBehaviour

  @impl true
  def decode!(message_value, opts) do
    schema = Keyword.fetch!(opts, :schema)

    decoded_message = schema.decode(message_value)
    {:ok, decoded_message}
  end
end
