defmodule Kafkaesque.DeadLetterQueue.KafkaTopicProducer do
  @moduledoc """
  Module that handles the producing of failed messages to the dead letter queue.
  """
  @behaviour Kafkaesque.Behaviours.DeadLetterProducer
  import Kafkaesque.DeadLetterQueue.Telemetry, only: [emit_kafka_telemetry: 4]

  @required_opts [:worker_name, :topic]

  @impl true
  def validate_opts!(opts) do
    @required_opts
    |> Enum.reduce([], fn opt, acc ->
      case Keyword.get(opts, opt) do
        nil -> acc ++ [opt]
        _ -> acc
      end
    end)
    |> case do
      [] -> :ok
      missing_opts -> raise ArgumentError, "Missing required opts: #{inspect(missing_opts)}"
    end
  end

  @doc """
  Produce the given message to the dead letter queue
  """
  @impl true
  def send_to_dead_letter_queue(message, state, opts) do
    worker_name = Keyword.fetch!(opts, :worker_name)
    dead_letter_topic = Keyword.fetch!(opts, :topic)
    messages = [%{key: message.key, value: message.value, headers: [{"source_topic", message.topic}]}]

    :ok = Kafkaesque.Producer.produce_messages(worker_name, dead_letter_topic, messages)
    emit_kafka_telemetry(worker_name, dead_letter_topic, message, state.metadata)
  end
end
