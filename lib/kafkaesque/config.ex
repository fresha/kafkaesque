defmodule Kafkaesque.Config do
  @moduledoc """
  Manages configuration for Kafkaesque library.
  """

  @default_config %{
    kafka_uris: nil,
    kafka_prefix: nil,
    healthchecks_enabled: false,
    healthchecks_warmup_time_in_seconds: 0,
    consumer_opts: []
  }

  @spec get(atom()) :: any()
  def get(key) do
    get(key, Map.get(@default_config, key))
  end

  @spec get(atom(), any()) :: any()
  def get(key, fallback) do
    value =
      case Application.get_env(:kafkaesque, key, fallback) do
        {:system, varname} -> System.get_env(varname)
        {:system, varname, default} -> System.get_env(varname) || default
        value -> value
      end

    if value == nil or value == "" do
      invalid_arg(key)
    end

    value
  end

  @spec kafka_endpoints :: [{String.t(), integer}]
  def kafka_endpoints do
    :kafka_uris
    |> get()
    |> String.split(",")
    |> Enum.map(fn url ->
      [host, port] = String.split(url, ":")
      {host, String.to_integer(port)}
    end)
  end

  @spec healthchecks_enabled? :: boolean
  def healthchecks_enabled? do
    case get(:healthchecks_enabled) do
      value when value in [1, "1", true, "true"] -> true
      _ -> false
    end
  end

  @spec kafka_prefix_prepend(String.t()) :: String.t()
  def kafka_prefix_prepend(arg) do
    kafka_prefix = get(:kafka_prefix)
    "#{kafka_prefix}.#{arg}"
  end

  @spec topic_identifier(String.t()) :: String.t()
  def topic_identifier(topic_name) do
    [_kafka_prefix, result] = String.split(topic_name, ".", parts: 2)
    result
  end

  defp invalid_arg(arg) do
    raise ArgumentError, "Invalid value provided for #{arg}, please check configuration!"
  end
end
