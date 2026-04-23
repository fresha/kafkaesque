defmodule Kafkaesque.Consumer.Telemetry do
  @moduledoc """
  Telemetry events for Kafkaesque.
  """
  @type monotonic_time :: integer
  @type system_time :: integer
  @type message :: KafkaEx.Protocol.Fetch.Message.t()
  @type message_set :: [KafkaEx.Protocol.Fetch.Message.t()]
  @type result :: :ok | {:ok, any} | {:ok, :dead_letter_queue, any} | {:error, any}
  @type kind :: :error | :exception
  @type reason :: any
  @type stacktrace :: Exception.stacktrace()
  @type state :: map

  @monitor_trace_context Application.compile_env!(:kafkaesque, :monitor_trace_context)

  @doc """
  Emit a telemetry event for a consumer worker connection.

  ---------------------------------------------------------------------------
  Worker Events
  **Event**  | **Measurements**  | **Metadata**
  ---        | ---               | ---          |
  [:kafkaesque, :consumer_worker, :connection] | N/A | consumer_state
  ---------------------------------------------------------------------------
  """
  @spec emit_worker_connection(map()) :: :ok
  def emit_worker_connection(metadata) do
    :telemetry.execute(
      [:kafkaesque, :consumer_worker, :connection],
      %{count: 1},
      metadata
    )
  end

  @doc """
  Emit a telemetry event for a consumer batch start.

  ---------------------------------------------------------------------------
  Batch Events
  **Event**  | **Measurements**  | **Metadata**
  ---        | ---               | ---          |
  [:kafkaesque, :consume_batch, :start]     | :count, :monotonic_time, :system_time            | :topic, :partition, :batch_size, :consumer_group, :consumer_group_identifier
  ---------------------------------------------------------------------------
  """
  @spec emit_consumer_batch_start(monotonic_time(), message_set(), state()) :: :ok
  def emit_consumer_batch_start(start_monotonic_time, message_set, state) do
    :telemetry.execute(
      [:kafkaesque, :consume_batch, :start],
      %{count: 1, monotonic_time: start_monotonic_time, system_time: current_system_time()},
      batch_metadata(message_set, state)
    )
  end

  @doc """
  Emit a telemetry event for a consumer batch stop.

  ---------------------------------------------------------------------------
  Batch Events
  **Event**  | **Measurements**  | **Metadata**
  ---        | ---               | ---          |
  [:kafkaesque, :consume_batch, :stop]      | :count, :monotonic_time, :duration, :system_time | :topic, :partition, :batch_size, :consumer_group, :consumer_group_identifier, :error
  ---------------------------------------------------------------------------
  """
  @spec emit_consumer_batch_stop(monotonic_time(), message_set(), state()) :: :ok
  def emit_consumer_batch_stop(start_monotonic_time, message_set, state) do
    monotonic_time = current_monotonic_time()
    duration = duration(monotonic_time, start_monotonic_time)

    :telemetry.execute(
      [:kafkaesque, :consume_batch, :stop],
      %{count: 1, monotonic_time: monotonic_time, duration: duration},
      batch_metadata(message_set, state)
    )
  end

  @doc """
  Emit a telemetry event for a consumer batch exception.

  ---------------------------------------------------------------------------
  Batch Events
  **Event**  | **Measurements**  | **Metadata**
  ---        | ---               | ---          |
  [:kafkaesque, :consume_batch, :exception] | :count, :monotonic_time, :duration, :system_time | :topic, :partition, :batch_size, :consumer_group, :consumer_group_identifier, :kind, :reason, :stacktrace
  ---------------------------------------------------------------------------
  """
  @spec emit_consumer_batch_exception(monotonic_time(), message_set(), state(), any, Exception.stacktrace()) :: :ok
  def emit_consumer_batch_exception(start_monotonic_time, message_set, state, error, stacktrace) do
    monotonic_time = current_monotonic_time()
    duration = duration(monotonic_time, start_monotonic_time)

    metadata = batch_metadata(message_set, state)
    metadata = extend_metadata(metadata, %{kind: :error, reason: error, stacktrace: stacktrace})

    :telemetry.execute(
      [:kafkaesque, :consume_batch, :exception],
      %{count: 1, monotonic_time: monotonic_time, duration: duration},
      metadata
    )
  end

  defp batch_metadata(messages_set, state) do
    batch_size = length(messages_set)
    topic = state.metadata.topic
    partition = state.metadata.partition
    consumer_group = state.metadata.consumer_group
    consumer_group_identifier = state.metadata.consumer_group_identifier

    state
    |> Map.from_struct()
    |> Map.drop([:decoder_config, :metadata])
    |> Map.merge(%{
      topic: topic,
      batch_size: batch_size,
      partition: partition,
      consumer_group: consumer_group,
      consumer_group_identifier: consumer_group_identifier
    })
  end

  @doc """
  Emit a telemetry event for a message start.

    # ---------------------------------------------------------------------------
  # Message Events
  # **Event**  | **Measurements**  | **Metadata**
  # ---        | ---               | ---          |
  # [:kafkaesque, :consume, :start] | :count, :monotonic_time, :system_time | :topic, :partition, :key, :offset, :consumer_group, :consumer_group_identifier
  # [:kafkaesque, :consume, :stop] | :count, :monotonic_time, :duration, :system_time | :topic, :partition, :key, :offset, :consumer_group, :consumer_group_identifier, :error
  # [:kafkaesque, :consume, :exception] | :count, :monotonic_time, :duration, :system_time | :topic, :partition, :key, :offset, :consumer_group, :consumer_group_identifier, :kind, :reason, :stacktrace
  # ---------------------------------------------------------------------------
  """
  @spec emit_consume_start(message(), state()) :: :ok
  def emit_consume_start(message, state) do
    tracing_headers = extract_tracing_headers(message.headers)
    :ok = @monitor_trace_context.attach_context_from_headers(tracing_headers)

    :telemetry.execute(
      [:kafkaesque, :consume, :start],
      %{count: 1, monotonic_time: state.start_time, system_time: current_system_time()},
      state.metadata
    )
  end

  @doc """
  Emit a telemetry event for a message stop.

  ---------------------------------------------------------------------------
  Message Events
  **Event**  | **Measurements**  | **Metadata**
  ---        | ---               | ---          |
  [:kafkaesque, :consume, :start] | :count, :monotonic_time, :system_time | :topic, :partition, :key, :offset, :consumer_group, :consumer_group_identifier
  ---------------------------------------------------------------------------
  """
  @spec emit_consume_stop(result(), state()) :: :ok
  def emit_consume_stop(result, state) do
    metadata =
      case result do
        :ok -> state.metadata
        {:ok, :dead_letter_queue, error} -> Map.merge(state.metadata, %{error: error})
        {:error, error} -> extend_metadata(state.metadata, %{error: error})
      end

    monotonic_time = current_monotonic_time()
    duration = duration(monotonic_time, state.start_time)

    :telemetry.execute(
      [:kafkaesque, :consume, :stop],
      %{count: 1, monotonic_time: current_monotonic_time(), duration: duration},
      metadata
    )
  end

  @doc """
  Emit a telemetry event for a message exception.

  ---------------------------------------------------------------------------
  Message Events
  **Event**  | **Measurements**  | **Metadata**
  ---        | ---               | ---          |
  [:kafkaesque, :consume, :stop] | :count, :monotonic_time, :duration, :system_time | :topic, :partition, :key, :offset, :consumer_group, :consumer_group_identifier, :error
  ---------------------------------------------------------------------------
  """
  @spec emit_consume_exception(state, %{kind: kind, reason: reason, stacktrace: stacktrace}) :: :ok
  def emit_consume_exception(state, %{kind: kind, reason: reason, stacktrace: stacktrace}) do
    metadata = extend_metadata(state.metadata, %{kind: kind, reason: reason, stacktrace: stacktrace})

    monotonic_time = current_monotonic_time()
    duration = duration(monotonic_time, state.start_time)

    :telemetry.execute(
      [:kafkaesque, :consume, :exception],
      %{count: 1, monotonic_time: monotonic_time, duration: duration},
      metadata
    )
  end

  @doc """
  Emit a telemetry event for a message retry.

  ---------------------------------------------------------------------------
  Retry Events
  **Event**  | **Measurements**  | **Metadata**
  ---        | ---               | ---          |
  [:kafkaesque, :consume, :retry] | :count, :monotonic_time, :duration | :topic, :partition, :key, :offset, :consumer_group, :consumer_group_identifier, :retry_count
  ---------------------------------------------------------------------------
  """
  @spec emit_consume_retry(state(), integer(), integer()) :: :ok
  def emit_consume_retry(state, retry_num, max_retries) do
    monotonic_time = current_monotonic_time()
    duration = duration(monotonic_time, state.start_time)

    retry_count = max_retries - retry_num + 1
    metadata = extend_metadata(state.metadata, %{retry_count: retry_count})

    :telemetry.execute(
      [:kafkaesque, :consume, :retry],
      %{count: 1, monotonic_time: monotonic_time, duration: duration},
      metadata
    )
  end

  # ---------------------------------------------------------------------------
  # Tracing Helpers
  # ---------------------------------------------------------------------------
  @dd_context_field "trace_context"

  defp extract_tracing_headers(nil), do: []

  defp extract_tracing_headers(headers) do
    with {@dd_context_field, value} when is_binary(value) <-
           Enum.find(headers, fn {header, _} -> header == @dd_context_field end),
         {:ok, trace_context} <- Jason.decode(value) do
      Enum.to_list(trace_context)
    else
      _ -> headers
    end
  end

  # ---------------------------------------------------------------------------
  # Telemetry helpers
  # ---------------------------------------------------------------------------
  def current_monotonic_time, do: System.monotonic_time(:millisecond)

  defp duration(monotonic_time, start_monotonic_time), do: monotonic_time - start_monotonic_time
  defp current_system_time, do: System.system_time(:millisecond)

  defp extend_metadata(metadata, args) do
    metadata |> Map.merge(args)
  end
end
