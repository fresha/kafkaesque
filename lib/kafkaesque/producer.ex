defmodule Kafkaesque.Producer do
  @moduledoc """
  Kafkaesque.Producer is a wrapper around KafkaEx. Producer that simplifies the
  producer API and adds monitoring and metrics.

  Emits the following telemetry events.
    **Event**  | **Measurements**  | **Metadata**
    ---        | ---               | ---          |
    [:kafkaesque, :produce, :start]     | :count, :system_time, :monotonic_time | :telemetry_span_context, :worker_name, :topic
    [:kafkaesque, :produce, :stop]      | :count, :monotonic_time, :duration    | :error, :telemetry_span_context, :worker_name, :topic
    [:kafkaesque, :produce, :exception] | :count, :monotonic_time, :duration    | :kind, :reason, :stacktrace, :telemetry_span_context, :worker_name, :topic
  See https://hexdocs.pm/telemetry/telemetry.html#span/3 for more information on the telemetry events.
  """
  @behaviour Kafkaesque.Behaviours.ProducerBehaviour

  alias Kafkaesque.Encoders.MessageEncoder

  @impl true
  def produce_messages(worker_name, topic, messages, opts \\ []) do
    do_produce_batch(worker_name, topic, messages, opts)
  end

  @impl true
  @deprecated "Use produce_messages/3 or produce_messages/4 instead"
  def produce(worker_name, topic, message_key, message_value, opts \\ []) do
    messages = [%{key: message_key, value: message_value}]
    do_produce_batch(worker_name, topic, messages, opts)
  end

  @impl true
  @deprecated "Use produce_messages/3 or produce_messages/4 instead"
  def produce_batch(worker_name, topic, message_key, message_values, opts \\ []) do
    messages = Enum.map(message_values, &%{key: message_key, value: &1})
    do_produce_batch(worker_name, topic, messages, opts)
  end

  # ---------------------------------------------------------------------------
  # Private functions
  # ---------------------------------------------------------------------------
  defp do_produce_batch(worker_name, topic, messages, opts) do
    monotonic_time = System.monotonic_time(:millisecond)
    metadata = %{worker_name: worker_name, topic: Kafkaesque.Config.kafka_prefix_prepend(topic)}
    messages_count = length(messages)

    try do
      emit_produce_start(messages_count, monotonic_time, metadata)

      topic
      |> MessageEncoder.build_request(messages, opts)
      |> send_request(worker_name)
      |> tap(&emit_produce_stop(&1, messages_count, monotonic_time, metadata))
    rescue
      error ->
        metadata = Map.merge(metadata, %{kind: :error, reason: error, stacktrace: __STACKTRACE__})
        emit_produce_exception(messages_count, monotonic_time, metadata)
        reraise error, __STACKTRACE__
    end
  end

  defp send_request(request, worker_name) do
    client_opts = [{:worker_name, worker_name}]

    request
    |> KafkaEx.produce(client_opts)
    |> parse_reply()
  end

  defp parse_reply(:ok), do: :ok
  defp parse_reply({:ok, _code}), do: :ok
  defp parse_reply({:error, error}), do: {:error, error}
  defp parse_reply(:leader_not_available), do: {:error, :leader_not_available}
  defp parse_reply(nil), do: {:error, :unknown}
  defp parse_reply(other), do: {:error, other}

  # ---------------------------------------------------------------------------
  # Telemetry events
  # ---------------------------------------------------------------------------
  defp emit_produce_start(messages_count, monotonic_time, metadata) do
    :telemetry.execute(
      [:kafkaesque, :produce, :start],
      %{count: 1, system_time: System.system_time(:millisecond), monotonic_time: monotonic_time},
      Map.merge(metadata, %{messages_count: messages_count})
    )
  end

  defp emit_produce_stop(result, messages_count, start_monotonic_time, metadata) do
    monotonic_time = System.monotonic_time(:millisecond)
    duration = monotonic_time - start_monotonic_time

    error =
      case result do
        :ok -> nil
        {:error, error} -> error
      end

    :telemetry.execute(
      [:kafkaesque, :produce, :stop],
      %{count: 1, monotonic_time: monotonic_time, duration: duration},
      Map.merge(metadata, %{error: error, messages_count: messages_count})
    )
  end

  defp emit_produce_exception(messages_count, start_monotonic_time, metadata) do
    monotonic_time = System.monotonic_time(:millisecond)
    duration = monotonic_time - start_monotonic_time

    :telemetry.execute(
      [:kafkaesque, :produce, :exception],
      %{count: 1, monotonic_time: monotonic_time, duration: duration},
      Map.merge(metadata, %{messages_count: messages_count})
    )
  end
end
