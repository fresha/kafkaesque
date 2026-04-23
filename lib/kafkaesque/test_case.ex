defmodule Kafkaesque.TestCase do
  @moduledoc """
  Helper functions for testing
  """

  defmacro __using__(_opts) do
    quote do
      import Kafkaesque.TestCase
    end
  end

  @doc """
  Builds a native kafka message
  """
  def build_kafka_message(params) do
    %KafkaEx.Protocol.Fetch.Message{
      topic: Map.fetch!(params, :topic),
      key: Map.fetch!(params, :key),
      value: Map.fetch!(params, :value),
      offset: Map.fetch!(params, :offset),
      partition: Map.fetch!(params, :partition),
      headers: Map.get(params, :headers, []),
      timestamp: Map.get(params, :timestamp, 0)
    }
  end

  @doc """
  Builds a consumer state
  """
  def build_consumer_state(params) do
    topic = Kafkaesque.Config.kafka_prefix_prepend(Map.fetch!(params, :topic))
    partition = Map.fetch!(params, :partition)

    supervisor = Map.fetch!(params, :supervisor)

    extra_args = %{
      consumer_group_identifier: supervisor.consumer_group_identifier,
      dead_letter_queue: supervisor.dead_letter_queue,
      dead_letter_queue_worker: supervisor.dead_letter_queue_worker
    }

    consumer = Map.fetch!(params, :consumer)

    case consumer.init(topic, partition, extra_args) do
      {:ok, state} -> state
      {:error, reason} -> raise(reason)
    end
  end
end
