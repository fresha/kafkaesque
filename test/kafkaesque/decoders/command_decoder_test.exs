defmodule Kafkaesque.Decoders.CommandDecoderTest do
  use ExUnit.Case, async: true

  alias DummyCommand.V1.Payload
  alias Kafkaesque.Decoders.CommandDecoder

  describe "decode!" do
    test "valid_message_decoded_with_schema" do
      ref = :telemetry_test.attach_event_handlers(self(), [[:kafkaesque, :decode]])

      {:ok, decoded_value} = CommandDecoder.decode!(example_message(), schema: DummyCommand.V1.Payload)

      assert %Payload{
               command_uuid: "123e4567-e89b-12d3-a456-426614174000",
               command_timestamp: 1_628_865_600,
               command_payload: {:dummy_command, "something_happened"}
             } == decoded_value

      assert_received {[:kafkaesque, :decode], ^ref, %{},
                       %{
                         decoder: Kafkaesque.Decoders.CommandDecoder,
                         envelope: "DummyCommand.V1.Payload",
                         resource: "DummyCommand.V1.Payload:dummy_command",
                         command: :dummy_command
                       }}
    end

    test "missing_schema" do
      assert_raise(KeyError, fn ->
        CommandDecoder.decode!(example_message(), [])
      end)
    end
  end

  defp example_message do
    Payload.encode(%Payload{
      command_uuid: "123e4567-e89b-12d3-a456-426614174000",
      command_timestamp: 1_628_865_600,
      command_payload: {:dummy_command, "something_happened"}
    })
  end
end
