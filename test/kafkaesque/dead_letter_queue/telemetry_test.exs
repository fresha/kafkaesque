defmodule Kafkaesque.DeadLetterQueue.TelemetryTest do
  use ExUnit.Case, async: true

  alias Kafkaesque.DeadLetterQueue.Telemetry

  describe "emit_kafka_telemetry/4" do
    setup do
      ref = :telemetry_test.attach_event_handlers(self(), [[:kafkaesque, :dlq_produce]])

      {:ok, %{handler_ref: ref}}
    end

    test "emits telemetry event", %{handler_ref: ref} do
      message = %KafkaEx.Protocol.Fetch.Message{
        key: "key",
        value: "value",
        topic: "topic",
        partition: 1,
        offset: 1
      }

      state = %Kafkaesque.Consumer.State{
        dead_letter_producer: {:module, %{topic: "dead-letter-topic", worker_name: self()}},
        metadata: %Kafkaesque.ConsumerMetadata{}
      }

      Telemetry.emit_kafka_telemetry(self(), "dead-letter-topic", message, state.metadata)

      expected_metadata = %{
        worker_name: self(),
        dlq_topic: "dead-letter-topic",
        source_topic: message.topic,
        source_partition: message.partition,
        source_consumer_group: state.metadata.consumer_group,
        message_key: message.key,
        message_offset: message.offset,
        dead_letter_destination: "dead-letter-topic",
        dead_letter_type: :kafka
      }

      assert_receive {
        [:kafkaesque, :dlq_produce],
        ^ref,
        %{count: 1},
        ^expected_metadata
      }
    end
  end
end
