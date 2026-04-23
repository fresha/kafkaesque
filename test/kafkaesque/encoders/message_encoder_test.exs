defmodule Kafkaesque.Encoders.MessageEncoderTest do
  use ExUnit.Case, async: true
  use Mimic
  alias Kafkaesque.Encoders.MessageEncoder

  describe "build_request/3" do
    test "builds a request with default options" do
      topic = "topic"
      messages = [%{key: "key", value: "value"}]
      opts = []

      expect_uuid(1)
      request = MessageEncoder.build_request(topic, messages, opts)

      assert_request(request, [])
    end

    test "builds a request with custom options" do
      topic = "topic"
      messages = [%{key: "key", value: "value"}]

      opts = [timeout: 200, required_acks: :all, partition: 1]
      expected_opts = [timeout: 200, required_acks: -1, partition: 1]

      expect_uuid(1)
      request = MessageEncoder.build_request(topic, messages, opts)

      assert_request(request, expected_opts)
    end

    test "builds a request with a nil value" do
      topic = "topic"
      messages = [%{key: "key", value: nil}]
      opts = []

      expect_uuid(1)
      request = MessageEncoder.build_request(topic, messages, opts)

      assert_request(request, value: "")
    end

    test "builds a request with a binary key" do
      topic = "topic"
      messages = [%{key: "key", value: "value"}]
      opts = []

      expect_uuid(1)
      request = MessageEncoder.build_request(topic, messages, opts)

      assert_request(request, [])
    end

    test "builds a request with a non-binary key" do
      topic = "topic"
      messages = [%{key: 1, value: "value"}]
      opts = []

      expect_uuid(1)
      request = MessageEncoder.build_request(topic, messages, opts)

      assert_request(request, key: "1")
    end

    test "adds a headers to the request" do
      topic = "topic"
      messages = [%{key: "key", value: "value", headers: [{"header_key", "header_value"}]}]
      opts = []

      expect_uuid(1)
      request = MessageEncoder.build_request(topic, messages, opts)

      assert_request(request, headers: [{"header_key", "header_value"}])
    end

    test "allows to add a custom id to the headers" do
      topic = "topic"
      messages = [%{key: "key", value: "value", headers: [{"id", "custom_uuid"}]}]
      opts = []

      request = MessageEncoder.build_request(topic, messages, opts)

      assert_request(request, id: "custom_uuid")
    end

    test "raises an error when messages don't have a unique key" do
      topic = "topic"
      messages = [%{key: "key", value: "value"}, %{key: "key1", value: "value"}]
      opts = []

      assert_raise ArgumentError, "All messages must have the same key", fn ->
        MessageEncoder.build_request(topic, messages, opts)
      end
    end
  end

  defp assert_request(request, expected_opts) do
    assert request.api_version == 3
    assert request.topic == "dummy.#{Keyword.get(expected_opts, :topic, "topic")}"
    assert request.partition == Keyword.get(expected_opts, :partition, nil)
    assert request.timeout == Keyword.get(expected_opts, :timeout, 100)
    assert request.required_acks == Keyword.get(expected_opts, :required_acks, 1)

    Enum.each(request.messages, &assert_message_record(&1, expected_opts))
  end

  defp assert_message_record(record, expected_opts) do
    default_id = Keyword.get(expected_opts, :id, "019006a0-53e3-7b2a-899d-30e9816eb483")
    headers = [{"id", default_id}] ++ Keyword.get(expected_opts, :headers, [])

    assert record.key == Keyword.get(expected_opts, :key, "key")
    assert record.value == Keyword.get(expected_opts, :value, "value")
    assert record.headers == headers
    assert record.timestamp
  end

  defp expect_uuid(num) do
    expect(Uniq.UUID, :uuid7, num, fn -> "019006a0-53e3-7b2a-899d-30e9816eb483" end)
  end
end
