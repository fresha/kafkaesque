defmodule BasicDeadLetterExampleConsumer.WithDLQEventsConsumer.ConsumerSupervisor do
  @moduledoc """
  Supervisor for Events Consumer Area
  - It's responsible for starting a supervision tree with workers per each topic/partition pair.
  - We don't have a dead letter queue here, as we don't want to have global dead letter queue for all topics.
  """

  use Kafkaesque.ConsumerSupervisor,
    consumer_group_identifier: "basic-dead-letter-example",
    topics: ["ping-events"],
    message_handler: BasicDeadLetterExampleConsumer.WithDLQEventsConsumer.MessagesHandler,
    dead_letter_queue: nil
end
