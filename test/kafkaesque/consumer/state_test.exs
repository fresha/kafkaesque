defmodule Kafkaesque.Consumer.StateTest do
  use ExUnit.Case, async: true
  alias Kafkaesque.Consumer.State

  describe "init/4" do
    test "initializes state with valid configuration" do
      # Setup
      topic = "test.test-topic"
      partition = 0

      consumer_config = %{
        consumer_group_identifier: "test-consumer-group",
        commit_strategy: :async,
        retries: 3,
        initial_backoff: 100,
        topics_config: %{
          "test-topic" => %{
            decoder_config: {TestDecoder, [schema: TestSchema]},
            handle_message_plugins: [{TestPlugin, [param: "value"]}]
          }
        }
      }

      supervisor_args = %{
        consumer_group_identifier: "test-consumer-group",
        dead_letter_queue: "dead-letter-topic",
        dead_letter_queue_worker: self()
      }

      # Act
      state = State.init(topic, partition, consumer_config, supervisor_args)

      # Assert
      assert state.topic == topic
      assert state.partition == partition
      assert is_integer(state.start_time)
      assert state.decoder_config == %{decoder: TestDecoder, opts: [schema: TestSchema]}
      assert length(state.handle_message_plugins) == 1
      assert hd(state.handle_message_plugins) == {TestPlugin, [param: "value"]}
      assert state.metadata.topic == topic
      assert state.metadata.partition == partition
      assert state.metadata.consumer_group_identifier == "test-consumer-group"

      assert state.dead_letter_producer == {
               Kafkaesque.DeadLetterQueue.KafkaTopicProducer,
               [topic: "dead-letter-topic", worker_name: self()]
             }
    end

    test "initializes state with valid configuration and dead letter producer" do
      # Setup
      topic = "test.test-topic"
      partition = 0

      consumer_config = %{
        consumer_group_identifier: "test-consumer-group",
        commit_strategy: :async,
        retries: 3,
        initial_backoff: 100,
        topics_config: %{
          "test-topic" => %{
            decoder_config: {TestDecoder, [schema: TestSchema]},
            dead_letter_producer:
              {Kafkaesque.DeadLetterQueue.KafkaTopicProducer, [topic: "dead-letter-topic", worker_name: self()]},
            handle_message_plugins: [{TestPlugin, [param: "value"]}]
          }
        }
      }

      supervisor_args = %{consumer_group_identifier: "test-consumer-group"}

      # Act
      state = State.init(topic, partition, consumer_config, supervisor_args)

      # Assert
      assert state.topic == topic
      assert state.partition == partition
      assert is_integer(state.start_time)
      assert state.decoder_config == %{decoder: TestDecoder, opts: [schema: TestSchema]}
      assert length(state.handle_message_plugins) == 1
      assert hd(state.handle_message_plugins) == {TestPlugin, [param: "value"]}
      assert state.metadata.topic == topic
      assert state.metadata.partition == partition
      assert state.metadata.consumer_group_identifier == "test-consumer-group"

      assert state.dead_letter_producer == {
               Kafkaesque.DeadLetterQueue.KafkaTopicProducer,
               [topic: "dead-letter-topic", worker_name: self()]
             }
    end

    test "validates consumer group identifier when provided in supervisor args" do
      topic = "test.test-topic"
      partition = 0

      consumer_config = %{
        consumer_group_identifier: "test-consumer-group",
        commit_strategy: :async,
        retries: 3,
        initial_backoff: 100,
        topics_config: %{
          "test-topic" => %{decoder_config: {TestDecoder, []}}
        }
      }

      mismatched_args = %{
        consumer_group_identifier: "mismatched-consumer-group"
      }

      assert_raise ArgumentError, "Consumer group identifier does not match the one specified in the supervisor.", fn ->
        State.init(topic, partition, consumer_config, mismatched_args)
      end
    end

    test "initializes with empty plugins when none configured" do
      topic = "test.test-topic"
      partition = 0

      config = %{
        consumer_group_identifier: "test-consumer-group",
        commit_strategy: :async,
        retries: 3,
        initial_backoff: 100,
        topics_config: %{
          "test-topic" => %{decoder_config: {TestDecoder, []}}
        }
      }

      supervisor_args = %{
        consumer_group_identifier: "test-consumer-group"
      }

      state = State.init(topic, partition, config, supervisor_args)
      assert state.handle_message_plugins == []
    end
  end
end
