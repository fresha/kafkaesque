defmodule Kafkaesque.DeadLetterQueue.KafkaTopicProducerTest do
  use ExUnit.Case, async: false
  use Mimic

  alias Kafkaesque.DeadLetterQueue.KafkaTopicProducer

  describe "validate_opts!/1" do
    test "validates opts" do
      opts = [worker_name: :dlq_worker, topic: "dead-letter-topic"]
      assert :ok = KafkaTopicProducer.validate_opts!(opts)
    end

    test "raises error when worker_name is missing" do
      opts = [topic: "dead-letter-topic"]

      assert_raise ArgumentError, fn ->
        KafkaTopicProducer.validate_opts!(opts)
      end
    end

    test "raises error when topic is missing" do
      opts = [worker_name: :dlq_worker]

      assert_raise ArgumentError, fn ->
        KafkaTopicProducer.validate_opts!(opts)
      end
    end
  end

  describe "send_to_dead_letter_queue/3" do
    test "sends message to dead letter queue with options" do
      message = %KafkaEx.Protocol.Fetch.Message{
        key: "key",
        value: "value",
        topic: "dummy.topic",
        partition: 1,
        offset: 1,
        headers: []
      }

      state = %Kafkaesque.Consumer.State{
        metadata: %Kafkaesque.ConsumerMetadata{}
      }

      opts = [worker_name: :dlq_worker, topic: "dead-letter-topic"]

      expect(KafkaEx, :produce, fn request, _opts ->
        assert request.required_acks == 1
        assert request.timeout == 100
        assert request.topic == "dummy.dead-letter-topic"
        assert request.partition == nil

        message = List.first(request.messages)
        assert message.key == "key"
        assert message.value == "value"

        :ok
      end)

      assert :ok = KafkaTopicProducer.send_to_dead_letter_queue(message, state, opts)
    end

    test "emit telemetry event after sending to dead letter queue" do
      ref = :telemetry_test.attach_event_handlers(self(), [[:kafkaesque, :dlq_produce]])

      message = %KafkaEx.Protocol.Fetch.Message{
        key: "key",
        value: "value",
        topic: "dummy.topic",
        partition: 1,
        offset: 1,
        headers: []
      }

      state = %Kafkaesque.Consumer.State{
        metadata: %Kafkaesque.ConsumerMetadata{}
      }

      opts = [worker_name: :dlq_worker, topic: "dead-letter-topic"]

      expect(KafkaEx, :produce, fn _request, _opts ->
        :ok
      end)

      assert :ok = KafkaTopicProducer.send_to_dead_letter_queue(message, state, opts)
      assert_receive {[:kafkaesque, :dlq_produce], ^ref, %{count: 1}, _}
    end
  end
end
