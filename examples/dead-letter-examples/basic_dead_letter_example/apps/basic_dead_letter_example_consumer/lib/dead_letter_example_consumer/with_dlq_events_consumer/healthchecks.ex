defmodule BasicDeadLetterExampleConsumer.WithDLQEventsConsumer.Healthchecks do
  @moduledoc false

  @doc """
  This healthcheck will be checking if consumer groups is online and connected
  to all registered topics and their partitions
  """
  def kafka_consumer_group_available do
    Heartbeats.Helpers.kafka_consumer_check("basic-dead-letter-example")
  end
end
