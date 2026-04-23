defmodule Kafkaesque.TestCaseTest do
  use ExUnit.Case, async: true

  alias Kafkaesque.TestCase

  describe "build_kafka_message/1" do
    test "builds a native kafka message" do
      params = %{topic: "test_topic", key: "test_key", value: "test_value", offset: 1, partition: 1}

      assert %KafkaEx.Protocol.Fetch.Message{
               attributes: 0,
               crc: nil,
               headers: [],
               key: "test_key",
               offset: 1,
               partition: 1,
               timestamp: 0,
               topic: "test_topic",
               value: "test_value"
             } == TestCase.build_kafka_message(params)
    end

    test "raises error when field is missing" do
      params = %{key: "test_key", value: "test_value", offset: 1, partition: 1}

      assert_raise KeyError, fn ->
        Kafkaesque.TestCase.build_kafka_message(params)
      end
    end
  end

  describe "build_consumer_state/1" do
    test "builds a consumer state" do
      params = %{
        consumer: Kafkaesque.DummyConsumer,
        supervisor: Kafkaesque.DummySupervisor,
        topic: "dummy_events",
        partition: 0
      }

      assert %Kafkaesque.Consumer.State{
               dead_letter_producer: {
                 Kafkaesque.DeadLetterQueue.KafkaTopicProducer,
                 [topic: "dummy.dlq", worker_name: :"Elixir.Kafkaesque.DummySupervisor.dead_letter_queue_worker"]
               },
               decoder_config: %{
                 opts: [schema: DummyEventEnvelope.V1.Payload],
                 decoder: Kafkaesque.Decoders.DebeziumProtoDecoder
               },
               metadata: %{
                 offset: nil,
                 partition: 0,
                 key: nil,
                 topic: "dummy.dummy_events",
                 consumer_group_identifier: "dummy.consumer",
                 consumer_group: "dummy.dummy.consumer"
               },
               partition: 0,
               topic: "dummy.dummy_events"
             } =
               TestCase.build_consumer_state(params)
    end
  end
end
