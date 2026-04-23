defmodule Kafkaesque.ConsumerConfig do
  @moduledoc false

  @api_versions %{fetch: 3, offset_fetch: 3, offset_commit: 3}

  # Default session timeout: determines how long before the broker
  # will de-register a consumer from which it has not heard a heartbeat.
  @default_session_timeout 20_000

  # Default session timeout padding. May need adjustment on high-latency
  # clusters to avoid timing out when joining/syncing consumer groups.
  @default_session_timeout_padding 10_000

  # The policy for resetting offsets when an `:offset_out_of_range` error occurs.
  # `:earliest` will move the offset to the oldest available, `:latest` moves
  # to the most recent.
  @default_auto_offset_reset :latest

  # How long to delay committing the offset for an acknowledged message (in milliseconds).
  @default_commit_interval 10_000

  # The maximum number of acknowledged messages that the consumer will allow to be
  # uncommitted before triggering a commit.
  @default_commit_threshold 100

  # Maximum amount of time in ms to block waiting if insufficient data is
  # available at the time the request is issued.
  @default_wait_time 500

  # Maximum bytes to include in the message set for a partition.
  # This helps bound the size of the response. Default is 1,000,000
  @default_max_bytes 1_000_000

  # How frequently, in ms, to send heartbeats to the broker
  @default_heartbeat_interval 5_000

  @doc """
  Build the config to be passed when starting the consumer group.

  Options may be overridden by passing a list of key-value pairs as the second argument.
  Some of the settings are passed to the consumer group on startup, while others are
  used to configure the `KafkaEx.GenConsumer` worker. For consistency with KafkaEx, we
  expect the options to be passed as a flattened list of key-value pairs, rather than
  grouping them by usage.

  For the full list, please see KafkaEx documentation.
  https://hexdocs.pm/kafka_ex_tc/KafkaEx.ConsumerGroup.html#t:option/0
  """
  @spec build_config(String.t(), Keyword.t()) :: Keyword.t()
  def build_config(consumer_group_identifier, consumer_opts \\ []) do
    kafka_endpoint_list = Kafkaesque.Config.kafka_endpoints()

    group_config = [
      heartbeat_interval: get_opt(:heartbeat_interval, consumer_opts, @default_heartbeat_interval),
      session_timeout: get_opt(:session_timeout, consumer_opts, @default_session_timeout),
      session_timeout_padding: get_opt(:session_timeout_padding, consumer_opts, @default_session_timeout_padding),
      uris: kafka_endpoint_list
    ]

    worker_config = build_worker_config(consumer_group_identifier, consumer_opts)

    Keyword.merge(
      group_config,
      worker_config
    )
  end

  # Option values used when starting the `KafkaEx.GenConsumer` worker
  # See https://hexdocs.pm/kafka_ex/KafkaEx.GenConsumer.html#start_link/5-options
  defp build_worker_config(consumer_group_identifier, consumer_opts) do
    [
      api_versions: api_versions(),
      auto_offset_reset: get_opt(:auto_offset_reset, consumer_opts, @default_auto_offset_reset),
      commit_interval: get_opt(:commit_interval, consumer_opts, @default_commit_interval),
      commit_threshold: get_opt(:commit_threshold, consumer_opts, @default_commit_threshold),
      extra_consumer_args: build_extra_consumer_args(consumer_group_identifier, consumer_opts),
      fetch_options: [
        {:max_bytes, get_opt(:max_bytes, consumer_opts, @default_max_bytes)},
        {:wait_time, get_opt(:wait_time, consumer_opts, @default_wait_time)}
      ]
    ]
  end

  defp build_extra_consumer_args(consumer_group_identifier, consumer_opts) do
    extra_consumer_args = Keyword.get(consumer_opts, :extra_consumer_args, %{})

    if not is_map(extra_consumer_args) do
      raise ArgumentError, "extra_consumer_args must be a map"
    end

    Map.merge(
      extra_consumer_args,
      %{
        consumer_group_identifier: consumer_group_identifier,
        dead_letter_queue: Keyword.get(consumer_opts, :dead_letter_queue),
        dead_letter_queue_worker: Keyword.get(consumer_opts, :dead_letter_queue_worker)
      }
    )
  end

  defp api_versions do
    Application.get_env(:kafka_ex, :api_versions, @api_versions)
  end

  defp get_opt(key, opts, default) do
    case Keyword.get(opts, key) do
      nil -> default
      "" -> default
      other -> other
    end
  end
end
