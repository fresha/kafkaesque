defmodule Kafkaesque.Consumer.Config do
  @moduledoc """
  Configuration for a `Kafkaesque.Consumer`.
  This module is responsible for building a configuration map from the provided options.
  """
  @default_initial_backoff 100

  @doc """
  Build a configuration map from the provided options.
  """
  @spec build(Keyword.t()) :: map()
  def build(opts) do
    decoders = Keyword.get(opts, :decoders, nil)
    topics_config = Keyword.get(opts, :topics_config, nil)
    validate_config_opts!(topics_config, :handle_message_plugins)
    validate_config_opts!(topics_config, :dead_letter_producer)

    topics_config =
      cond do
        !is_nil(decoders) && !is_nil(topics_config) ->
          raise ArgumentError, "only one of :decoders or :topics_config can be provided"

        is_nil(decoders) && is_nil(topics_config) ->
          raise ArgumentError, "either :decoders or :topics_config must be provided"

        !is_nil(decoders) ->
          convert_legacy_decoders_to_topics_config(decoders)

        !is_nil(topics_config) ->
          topics_config

        true ->
          raise ArgumentError, "either :decoders or :topics_config must be provided"
      end

    %{
      consumer_group_identifier: Keyword.fetch!(opts, :consumer_group_identifier),
      commit_strategy: Keyword.fetch!(opts, :commit_strategy),
      retries: Keyword.fetch!(opts, :retries),
      initial_backoff: Keyword.get(opts, :initial_backoff, @default_initial_backoff),
      topics_config: topics_config
    }
  end

  defp convert_legacy_decoders_to_topics_config(decoders) do
    Enum.into(decoders, %{}, fn {topic, %{decoder: decoder, opts: opts}} ->
      {
        topic,
        %{
          decoder_config: {decoder, opts},
          handle_message_plugins: [],
          dead_letter_producer: nil
        }
      }
    end)
  end

  defp validate_config_opts!(nil, _), do: :ok

  defp validate_config_opts!(topics_config, key) do
    topics_config
    |> Enum.reduce([], fn {_topic, opts}, acc ->
      case Map.get(opts, key) do
        plugin when is_tuple(plugin) -> acc ++ [plugin]
        plugins when is_list(plugins) -> acc ++ plugins
        nil -> acc
      end
    end)
    |> Enum.each(&validate_plugin_opts!/1)
  end

  defp validate_plugin_opts!({plugin, opts}) do
    plugin.validate_opts!(opts)
  end
end
