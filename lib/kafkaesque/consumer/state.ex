defmodule Kafkaesque.Consumer.State do
  @moduledoc """
  This module represents the state of a Kafkaesque consumer.

  It encapsulates all the data needed for message processing and provides
  initialization functionality to create a valid state from configuration
  and supervisor arguments.

  The state contains:
    - `topic` - The Kafka topic to which the consumer is subscribed
    - `partition` - The Kafka partition being consumed
    - `start_time` - Timestamp when processing started (for metrics)
    - `commit_strategy` - Commit strategy. `:sync` or `:async` where `:sync` commits
      offsets at the end of each message set and `:async` commits offsets
      periodically or when the worker terminates
    - `max_retries` - Maximum number of retries for message processing. In case of set as 3,
      the message will be retried 3 times which means 4 attempts in total.
    - `dead_letter_producer` - Dead Letter callback module and options.
    - `decoder_config` - Configuration for message decoding
    - `handle_message_plugins` - List of plugins to process messages
    - `metadata` - Additional metadata about the consumer
  """
  import Kafkaesque.Consumer.Telemetry, only: [current_monotonic_time: 0]
  alias Kafkaesque.DeadLetterQueue.KafkaTopicProducer

  @type plugin :: {module(), Keyword.t()}
  @type decoder_config :: %{decoder: module() | nil, opts: Keyword.t()}

  @type t :: %__MODULE__{
          topic: String.t(),
          partition: integer,
          start_time: integer,
          commit_strategy: :sync | :async,
          max_retries: non_neg_integer(),
          initial_backoff: non_neg_integer(),
          # Deprecated. Replaced by `dead_letter_producer`
          dead_letter_producer: plugin(),
          decoder_config: decoder_config(),
          handle_message_plugins: [plugin()],
          metadata: map()
        }

  defstruct [
    :topic,
    :partition,
    :start_time,
    :commit_strategy,
    :max_retries,
    :initial_backoff,
    :dead_letter_producer,
    :decoder_config,
    :handle_message_plugins,
    :metadata
  ]

  @doc """
  Initializes the state of the consumer.

  Takes the topic, partition, consumer configuration, and supervisor arguments
  to create a fully initialized state struct. Handles setup of all consumer components
  including metadata, decoder configuration, and message processing plugins.

  ## Parameters
    - `topic` - The Kafka topic name
    - `partition` - The Kafka partition number
    - `consumer_config` - Configuration map from Consumer.Config
    - `supervisor_args` - Arguments passed from the supervisor

  ## Returns
    - A fully initialized `%State{}` struct
  """
  def init(topic, partition, consumer_config, supervisor_args) do
    topic_identifier = Kafkaesque.Config.topic_identifier(topic)
    validate_consumer_group_identifier!(consumer_config, supervisor_args)

    # Global Config for Dead Letter
    dlq_topic = Map.get(supervisor_args, :dead_letter_queue)
    dlq_worker = Map.get(supervisor_args, :dead_letter_queue_worker)

    # Topic Config for Dead Letter
    dlq_producer = get_dead_letter_producer(consumer_config, topic_identifier)

    %__MODULE__{
      topic: topic,
      partition: partition,
      start_time: current_monotonic_time(),
      commit_strategy: consumer_config.commit_strategy,
      max_retries: consumer_config.retries,
      initial_backoff: consumer_config.initial_backoff,
      dead_letter_producer: build_dead_letter_producer(dlq_producer, dlq_worker, dlq_topic),
      decoder_config: get_decoder_config(consumer_config, topic_identifier),
      handle_message_plugins: get_topic_handle_message_plugins(consumer_config, topic_identifier),
      metadata: init_metadata(topic, partition, consumer_config)
    }
  end

  defp init_metadata(topic, partition, %{consumer_group_identifier: consumer_group_identifier}) do
    topic
    |> Kafkaesque.ConsumerMetadata.init_metadata(partition, consumer_group_identifier)
    |> Map.from_struct()
  end

  defp get_decoder_config(%{topics_config: topics_config}, topic_identifier) do
    case topics_config |> Map.fetch!(topic_identifier) |> Map.get(:decoder_config) do
      {decoder, opts} -> %{decoder: decoder, opts: opts}
      decoder -> %{decoder: decoder}
    end
  end

  # --------------------------------------------------------------------
  defp get_dead_letter_producer(%{topics_config: topics_config}, topic_identifier) do
    topics_config
    |> Map.fetch!(topic_identifier)
    |> Map.get(:dead_letter_producer)
  end

  defp build_dead_letter_producer(nil, nil, nil), do: nil
  defp build_dead_letter_producer({_, _} = dlq, _, _), do: dlq

  defp build_dead_letter_producer(_, worker, topic) do
    {KafkaTopicProducer, [topic: topic, worker_name: worker]}
  end

  # --------------------------------------------------------------------
  defp get_topic_handle_message_plugins(%{topics_config: topics_config}, topic_identifier) do
    topics_config
    |> Map.fetch!(topic_identifier)
    |> Map.get(:handle_message_plugins, [])
  end

  @doc false
  defp validate_consumer_group_identifier!(config, extra_args) do
    unless Map.get(extra_args, :consumer_group_identifier) == config.consumer_group_identifier do
      raise ArgumentError, "Consumer group identifier does not match the one specified in the supervisor."
    end
  end
end
