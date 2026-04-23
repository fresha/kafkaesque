defmodule Kafkaesque.Decoders.DebeziumProtoDecoder do
  @moduledoc """
  Decoder module for Debezium proto events.

  Will emit a telemetry event that may be consumed by external libraries,
  such as `monitor`.
  """
  @behaviour Kafkaesque.Decoders.DecoderBehaviour

  import Kafkaesque.Decoders.TimestampHelper

  @impl true
  def decode!(message_value, opts) do
    schema = Keyword.fetch!(opts, :schema)

    {:ok, decoded_message} =
      message_value
      |> Jason.decode!()
      |> decode_payload(schema)

    metadata = %{
      decoder: __MODULE__,
      resource: "#{schema}:#{decoded_message.event_type}",
      schema: schema,
      event_uuid: decoded_message.event_uuid,
      event_type: decoded_message.event_type,
      timestamp: decoded_message.timestamp
    }

    :telemetry.execute([:kafkaesque, :decode], %{}, Map.new(metadata))

    {:ok, decoded_message}
  end

  defp decode_payload(payload, schema) do
    event_uuid =
      payload
      |> Map.fetch!("uuid")

    event_type =
      payload
      |> Map.fetch!("event_type")
      |> String.to_atom()

    proto_payload =
      payload
      |> Map.fetch!("payload")
      |> decode_proto_payload(schema)

    timestamp =
      payload
      |> Map.fetch!("timestamp")
      |> parse_timestamp()

    decoded_message = %{
      event_uuid: event_uuid,
      event_type: event_type,
      proto_payload: proto_payload,
      timestamp: timestamp
    }

    {:ok, decoded_message}
  end

  defp decode_proto_payload(proto_payload, schema) do
    proto_payload
    |> Base.decode64!()
    |> schema.decode()
  end
end
