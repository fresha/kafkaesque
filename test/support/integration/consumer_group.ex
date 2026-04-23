defmodule Kafkaesque.Integration.ConsumerGroup do
  @moduledoc """
  Documentation for `Kafkaesque.Integration.ConsumerGroup`.
  This is a module that implements the Kafkaesque.Consumer behaviour and used in integration tests
  """

  defmodule Supervisor do
    @moduledoc false
    use Kafkaesque.ConsumerSupervisor,
      consumer_group_identifier: "integration-consumer-group",
      topics: [
        "proto-event-topic",
        "binary-topic-with-plugin",
        "binary-topic-with-dlq"
      ],
      message_handler: Kafkaesque.Integration.ConsumerGroup.MessageHandler,
      dead_letter_queue: nil
  end

  defmodule MessageHandler do
    @moduledoc false

    alias DummyEventEnvelope.V1.Payload, as: Envelope

    alias Kafkaesque.DeadLetterQueue.KafkaTopicProducer
    alias Kafkaesque.Integration.AgentHandler
    alias Kafkaesque.Integration.AgentStorage

    use Kafkaesque.Consumer,
      commit_strategy: :sync,
      consumer_group_identifier: "integration-consumer-group",
      topics_config: %{
        "proto-event-topic" => %{
          decoder_config: {Kafkaesque.Decoders.DebeziumProtoDecoder, [schema: Envelope]},
          dead_letter_producer: nil,
          handle_message_plugins: []
        },
        "binary-topic-with-plugin" => %{
          decoder_config: nil,
          dead_letter_producer: nil,
          handle_message_plugins: [{AgentHandler, [agent: AgentHandler]}]
        },
        "binary-topic-with-dlq" => %{
          decoder_config: nil,
          dead_letter_producer: {KafkaTopicProducer, [topic: "dead-letter-topic", worker_name: :producer]},
          handle_message_plugins: []
        }
      },
      retries: 2

    def handle_decoded_message(%{proto_payload: payload}) do
      AgentStorage.put(AgentStorage, payload)
      :ok
    end

    def handle_decoded_message(binary_event) when is_binary(binary_event) do
      case binary_event do
        "pluggable event" ->
          AgentStorage.put(AgentStorage, binary_event)
          :ok

        _result ->
          {:error, :unknown_event}
      end
    end
  end
end
