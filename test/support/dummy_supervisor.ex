defmodule Kafkaesque.DummySupervisor do
  @moduledoc false

  use Kafkaesque.ConsumerSupervisor,
    consumer_group_identifier: "dummy.consumer",
    topics: ["dummy_events"],
    message_handler: Kafkaesque.DummyConsumer,
    dead_letter_queue: "dummy.dlq"
end
