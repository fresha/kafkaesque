defmodule Kafkaesque.Decoders.ProtoDecoderTest do
  use ExUnit.Case
  use Protobuf, syntax: :proto3

  alias DummyEvent.V1.Payload
  alias Kafkaesque.Decoders.ProtoDecoder

  test "valid_message_decoded_with_schema" do
    {:ok, decoded_value} = ProtoDecoder.decode!(example_message(), schema: DummyEvent.V1.Payload)

    assert %Payload{
             :id => 1,
             :name => "something_happened",
             :flag => "error",
             :created_at => "2021-08-13T12:00:00Z"
           } == decoded_value
  end

  test "missing_schema" do
    assert_raise(KeyError, fn -> ProtoDecoder.decode!(example_message(), []) end)
  end

  defp example_message do
    Payload.encode(%Payload{
      :id => 1,
      :name => "something_happened",
      :flag => "error",
      :created_at => "2021-08-13T12:00:00Z"
    })
  end
end
