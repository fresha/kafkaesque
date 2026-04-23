defmodule Kafkaesque.Decoders.DebeziumProtoDecoderTest do
  use ExUnit.Case
  use Protobuf, syntax: :proto3

  alias Kafkaesque.Decoders.DebeziumProtoDecoder

  test "valid_message_decoded_with_schema" do
    message_value = generate_message_with_schema("CAESEnNvbWV0aGluZ19oYXBwZW5lZBoFZXJyb3IiFDIwMjEtMDgtMTNUMTI6MDA6MDBa")

    ref = :telemetry_test.attach_event_handlers(self(), [[:kafkaesque, :decode]])

    {:ok, decoded_value} = DebeziumProtoDecoder.decode!(message_value, decoder_opts())

    expected_proto_payload = %DummyEvent.V1.Payload{
      id: 1,
      name: "something_happened",
      flag: "error",
      created_at: "2021-08-13T12:00:00Z"
    }

    expected_value = %{
      event_uuid: "7eb31508-5ad2-4228-92fe-a7e92a9b20f6",
      event_type: :dummy_event,
      proto_payload: expected_proto_payload,
      timestamp: ~U[2021-02-23 14:48:24.890000Z]
    }

    assert decoded_value == expected_value

    assert_received {[:kafkaesque, :decode], ^ref, %{},
                     %{
                       decoder: Kafkaesque.Decoders.DebeziumProtoDecoder,
                       schema: DummyEvent.V1.Payload,
                       resource: "Elixir.DummyEvent.V1.Payload:dummy_event",
                       event_uuid: "7eb31508-5ad2-4228-92fe-a7e92a9b20f6",
                       event_type: :dummy_event,
                       timestamp: ~U[2021-02-23 14:48:24.890000Z]
                     }}
  end

  test "invalid_message_fails_decoding" do
    # Not a valid Proto event
    message_value_1 = generate_message_with_schema("U09NRV9WQUxVRQ==")

    # Not a valid base64 encoded string
    message_value_2 = generate_message_with_schema("SOME_VALUE")

    # Missing event_type key
    message_value_3 = generate_message_with_schema("SOME_VALUE", remove_keys: ["event_type"])

    assert_raise(
      Protobuf.DecodeError,
      fn ->
        DebeziumProtoDecoder.decode!(message_value_1, decoder_opts())
      end
    )

    assert_raise(
      ArgumentError,
      fn ->
        DebeziumProtoDecoder.decode!(message_value_2, decoder_opts())
      end
    )

    assert_raise(KeyError, fn -> DebeziumProtoDecoder.decode!(message_value_3, decoder_opts()) end)
  end

  defp decoder_opts, do: [{:schema, DummyEvent.V1.Payload}]

  defp generate_message_with_schema(payload) do
    generate_message_with_schema(payload, [])
  end

  defp generate_message_with_schema(value, opts) do
    remove_keys = Keyword.get(opts, :remove_keys, [])

    schema = %{
      "schema" => %{
        "type" => "struct",
        "fields" => [
          %{"type" => "string", "optional" => false, "field" => "uuid"},
          %{"type" => "string", "optional" => false, "field" => "event_type"},
          %{"type" => "bytes", "optional" => false, "field" => "payload"},
          %{"type" => "string", "optional" => false, "field" => "timestamp"}
        ],
        "optional" => false,
        "name" => "dummy_events"
      }
    }

    payload =
      Map.drop(
        %{
          "uuid" => "7eb31508-5ad2-4228-92fe-a7e92a9b20f6",
          "event_type" => "dummy_event",
          "payload" => value,
          "timestamp" => 1_614_091_704_890
        },
        remove_keys
      )

    {:ok, message_value} = Jason.encode(Map.merge(schema, payload))
    message_value
  end
end
