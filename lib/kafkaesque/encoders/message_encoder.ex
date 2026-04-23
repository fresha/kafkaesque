defmodule Kafkaesque.Encoders.MessageEncoder do
  @moduledoc """
  Kafkaesque.Encoders.MessageEncoder is module responsible for
  encoding messages to be sent to Kafka, directly via Kafkaesque.Producer
  """
  @api_version 3

  # Default max time in milliseconds the server can await the receipt
  # of the number of acknowledgements in required_acks
  @default_timeout 100

  # Indicates how many acknowledgements the servers should receive before
  # responding to the request. By default only wait for the partition leader
  # to acknowledge the message
  @default_required_acks :one

  alias KafkaEx.Protocol.Produce.Message, as: ProduceMessage
  alias KafkaEx.Protocol.Produce.Request, as: ProduceRequest

  @doc """
  Validates, parses and builds protocol-friendly message
  """
  def build_request(topic_name, messages, opts) do
    validate_messages!(messages)

    full_topic_name = Kafkaesque.Config.kafka_prefix_prepend(topic_name)
    partition = :partition |> get_opt(opts, nil)
    timeout = :timeout |> get_opt(opts, @default_timeout)
    required_acks = :required_acks |> get_opt(opts, @default_required_acks) |> parse_ack()

    %ProduceRequest{
      api_version: @api_version,
      topic: full_topic_name,
      partition: partition,
      timeout: timeout,
      required_acks: required_acks,
      messages: Enum.map(messages, &build_message_record(&1))
    }
  end

  @doc """
  Validates, parses and builds protocol-friendly message
  """
  @deprecated "Use build_request/3 instead"
  @spec build_request(binary, any, any, Keyword.t()) :: ProduceRequest.t()
  def build_request(topic_name, message_key, message_values, opts) do
    full_topic_name = Kafkaesque.Config.kafka_prefix_prepend(topic_name)
    partition = :partition |> get_opt(opts, nil)
    timeout = :timeout |> get_opt(opts, @default_timeout)
    required_acks = :required_acks |> get_opt(opts, @default_required_acks) |> parse_ack()

    %ProduceRequest{
      api_version: @api_version,
      topic: full_topic_name,
      partition: partition,
      timeout: timeout,
      required_acks: required_acks,
      messages: Enum.map(message_values, &build_message_record(message_key, &1))
    }
  end

  # ---------------------------------------------------------------------------
  # Private functions
  # ---------------------------------------------------------------------------

  defp validate_messages!([m | _] = messages) do
    case Enum.all?(messages, &(&1.key == m.key)) do
      true -> :ok
      false -> raise ArgumentError, "All messages must have the same key"
    end
  end

  # ---------------------------------------------------------------------------
  defp get_opt(key, opts, default) do
    case Keyword.get(opts, key) do
      nil -> default
      "" -> default
      other -> other
    end
  end

  # ---------------------------------------------------------------------------
  defp build_message_record(message) do
    %{
      key: encode_key(message.key),
      value: encode_value(message.value),
      headers: build_headers(Map.get(message, :headers, [])),
      timestamp: :os.system_time(:millisecond)
    }
  end

  defp build_message_record(key, value) do
    %ProduceMessage{
      key: encode_key(key),
      value: encode_value(value),
      headers: build_headers([]),
      timestamp: :os.system_time(:millisecond)
    }
  end

  defp encode_key(key) when is_binary(key) and key != <<>>, do: key
  defp encode_key(key) when not is_nil(key), do: "#{key}"

  defp encode_value(value) when is_nil(value), do: <<>>
  defp encode_value(%{__struct__: struct} = value), do: struct.encode(value)
  defp encode_value(value), do: "#{value}"

  defp build_headers(headers) do
    trace_headers = monitor_trace_context().headers_from_current_context()
    trace_keys = Enum.map(trace_headers, &elem(&1, 0))

    headers
    |> ensure_id_header()
    |> Enum.reject(&(elem(&1, 0) in trace_keys))
    |> Enum.concat(trace_headers)
  end

  defp ensure_id_header(headers) do
    if Enum.any?(headers, &(elem(&1, 0) == "id")) do
      headers
    else
      [{"id", Uniq.UUID.uuid7()} | headers]
    end
  end

  # ---------------------------------------------------------------------------
  defp monitor_trace_context do
    Application.fetch_env!(:kafkaesque, :monitor_trace_context)
  end

  # ---------------------------------------------------------------------------
  defp parse_ack(:one), do: 1
  defp parse_ack(:all), do: -1
  defp parse_ack(:none), do: 0
end
