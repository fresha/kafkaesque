defmodule Kafkaesque.Decoders.DebeziumTableDecoder do
  @moduledoc """
  Decoder module for Debezium table events.

  Will emit a telemetry event that may be consumed by external libraries,
  such as `monitor`.
  """
  @behaviour Kafkaesque.Decoders.DecoderBehaviour

  require Logger
  alias Kafkaesque.Decoders.Structs.DebeziumCDCMessage

  @impl true
  def decode!(nil, _opts), do: {:error, :tombstone}
  def decode!(<<>>, _opts), do: {:error, :tombstone}

  def decode!(message_value, opts) do
    cdc_event = Jason.decode!(message_value, keys: :atoms)

    table = cdc_event.source.table
    operation = operation(cdc_event)
    schema = cdc_event.source.schema

    decoded_message =
      %DebeziumCDCMessage{
        table: table,
        schema: schema,
        database: cdc_event.source.db,
        operation: operation,
        primary_key: primary_key(opts),
        data: cdc_event.after,
        timestamp: timestamp(cdc_event.ts_ms)
      }

    metadata = %{
      decoder: __MODULE__,
      resource: "#{schema}.#{table}:#{operation}",
      schema: schema,
      table: table,
      operation: operation
    }

    :telemetry.execute([:kafkaesque, :decode], %{}, metadata)

    {:ok, decoded_message}
  end

  defp timestamp(time_ms) do
    case DateTime.from_unix(time_ms, :millisecond) do
      {:ok, timestamp} ->
        timestamp

      _ ->
        Logger.error("Invalid timestamp: #{inspect(time_ms)}")
        DateTime.utc_now()
    end
  end

  defp operation(event) do
    case event do
      %{op: "c"} -> :insert
      %{op: "u", after: %{deleted_at: deleted_at}} when not is_nil(deleted_at) -> :soft_delete
      %{op: "u"} -> :update
      %{op: "d"} -> :delete
      %{op: "r"} -> :read
      _ -> :unknown
    end
  end

  defp primary_key(opts) do
    opts
    |> Keyword.fetch!(:message_key)
    |> Jason.decode!()
    |> Map.values()
    |> hd()
  end
end
