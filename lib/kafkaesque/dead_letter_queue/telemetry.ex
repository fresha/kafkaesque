defmodule Kafkaesque.DeadLetterQueue.Telemetry do
  @moduledoc """
  Telemetry events for the dead letter queue.
  """

  @doc """
  Emits the following telemetry events.
  This event supports Kafka DLQ producer. In case of other DLQ plugins, it's required to be implemented.

  **Event**  | **Measurements**  | **Metadata**
  ---        | ---               | ---          |
  [:kafkaesque, :dlq_produce] | :count, :system_type | :worker_name, :dlq_topic, :topic, :partition, :key, :offset, :consumer_group
  """
  def emit_kafka_telemetry(worker_name, dead_letter_queue, message, metadata) do
    :telemetry.execute(
      [:kafkaesque, :dlq_produce],
      %{count: 1},
      %{
        source_topic: message.topic,
        source_partition: message.partition,
        source_consumer_group: metadata.consumer_group,
        message_key: message.key,
        message_offset: message.offset
      }
      |> Map.merge(legacy_metadata(worker_name, dead_letter_queue))
      |> Map.merge(new_metadata(:kafka, dead_letter_queue))
    )
  end

  defp legacy_metadata(worker_name, dead_letter_queue) do
    %{
      worker_name: worker_name,
      dlq_topic: dead_letter_queue
    }
  end

  defp new_metadata(type, destination) do
    %{
      dead_letter_type: type,
      dead_letter_destination: destination
    }
  end
end
