defmodule Kafkaesque.Decoders.CommandDecoder do
  @moduledoc """
  Decoder with observability features.

  Will emit a telemetry event that may be consumed by external libraries, such as `monitor`.

  The decoding itself is delegated to the `Kafkaesque.Decoders.ProtoDecoder` module.

  ## Options

    * `:schema` - (required) the protobuf module to decode the message with
    * `:payload_field` - the field name containing the command payload in the envelope.
      Defaults to `:command_payload`. Some command envelopes may use `:payload` instead.

  ## Example

      decoders: %{
        "my-topic" => %{
          decoder: Kafkaesque.Decoders.CommandDecoder,
          opts: [schema: MyCommandEnvelope, payload_field: :payload]
        }
      }

  """
  @behaviour Kafkaesque.Decoders.DecoderBehaviour

  alias Kafkaesque.Decoders.ProtoDecoder

  @default_payload_field :command_payload

  @impl true
  def decode!(message_value, opts) do
    {:ok, decoded_message} = ProtoDecoder.decode!(message_value, opts)

    payload_field = Keyword.get(opts, :payload_field, @default_payload_field)

    envelope = decoded_message.__struct__ |> to_string() |> String.trim_leading("Elixir.")
    {command, _} = Map.get(decoded_message, payload_field, {:unknown, nil})

    metadata = %{
      decoder: __MODULE__,
      envelope: envelope,
      command: command,
      resource: "#{envelope}:#{command}"
    }

    :telemetry.execute([:kafkaesque, :decode], %{}, metadata)

    {:ok, decoded_message}
  end
end
