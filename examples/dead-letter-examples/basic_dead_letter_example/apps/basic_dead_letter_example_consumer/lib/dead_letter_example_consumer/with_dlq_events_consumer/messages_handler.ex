defmodule BasicDeadLetterExampleConsumer.WithDLQEventsConsumer.MessagesHandler do
  @moduledoc """
  This module will be receiving messages from any topics to which its consumer group is subscribed.
  - Messages will be incoming in batches containing messages from one partition.
  - Basic approach we support in Fresha is to process message after message.
  """

  use Kafkaesque.Consumer,
    commit_strategy: :sync,
    consumer_group_identifier: "basic-dead-letter-example",
    topics_config: %{
      "ping-events" => %{
        decoder_config: {nil, []},
        dead_letter_producer: {
          Kafkaesque.DeadLetterQueue.KafkaTopicProducer,
          topic: "basic-dead-letter-example.ping-events.dead-letter", worker_name: :my_worker
        }
      }
    },
    retries: 2

  @impl true
  def handle_decoded_message(message) do
    BasicDeadLetterExampleCore.ping(message)
  end
end
