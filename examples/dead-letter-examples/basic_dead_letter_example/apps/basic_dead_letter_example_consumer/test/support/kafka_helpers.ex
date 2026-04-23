defmodule BasicDeadLetterExampleConsumer.Support.KafkaHelpers do
  @moduledoc """
  Helper functions for kafka tests
  """

  alias Testcontainers.Container

  @doc """
  Starts client connected to test containers based kafka runtime
  """
  def start_client(worker, kafka) do
    uris = [{"localhost", Container.mapped_port(kafka, 9092)}]
    {:ok, pid} = KafkaEx.create_worker(worker, uris: uris, consumer_group: "kafka_ex")
    ExUnit.Callbacks.on_exit(fn -> :ok = KafkaEx.stop_worker(pid) end)
    {:ok, pid}
  end

  @doc """
  Setup kafkaesque config
  """
  def setup_env(kafka) do
    old_uri = Application.get_env(:kafkaesque, :kafka_uris)

    Application.put_env(
      :kafkaesque,
      :kafka_uris,
      "localhost:#{Container.mapped_port(kafka, 9092)}"
    )

    ExUnit.Callbacks.on_exit(fn -> Application.put_env(:kafkaesque, :kafka_uris, old_uri) end)
  end

  @doc """
  Creates a topic in test containers based kafka runtime
  """
  def create_topic(worker_name, topic_name, opts) do
    request = %KafkaEx.Protocol.CreateTopics.TopicRequest{
      topic: "test.#{topic_name}",
      num_partitions: Keyword.get(opts, :num_partitions, 1),
      replication_factor: Keyword.get(opts, :replication_factor, 1),
      replica_assignment: Keyword.get(opts, :replica_assignment, [])
    }

    KafkaEx.create_topics([request], worker_name: worker_name)
  end

  @doc """
  Produce an event to topic partition 0
  """
  def produce_event(worker_name, topic_name, payload) do
    KafkaEx.produce("test.#{topic_name}", 0, payload, worker_name: worker_name)
  end
end
