defmodule Kafkaesque.Consumer.PluginHandlerTest do
  use ExUnit.Case, async: true

  alias Kafkaesque.Consumer.PluginHandler
  alias KafkaEx.Protocol.Fetch.Message

  defmodule LoggingPlugin do
    @behaviour Kafkaesque.Behaviours.MessageHandlerPlugin

    def validate_opts!(_opts), do: :ok

    def handle_message(message, _state, _opts, next_function) do
      Process.put(:logged_message, message.key)
      next_function.(message)
    end
  end

  defmodule TransformPlugin do
    @behaviour Kafkaesque.Behaviours.MessageHandlerPlugin

    def validate_opts!(_opts), do: :ok

    def handle_message(message, _state, opts, next_function) do
      transformed = %{message | value: opts[:transform_to] || message.value}
      next_function.(transformed)
    end
  end

  defmodule ConditionalPlugin do
    @behaviour Kafkaesque.Behaviours.MessageHandlerPlugin

    def validate_opts!(_opts), do: :ok

    def handle_message(message, _state, opts, next_function) do
      if opts[:condition].(message) do
        next_function.(message)
      else
        {:skip, :condition_not_met}
      end
    end
  end

  test "applies single plugin" do
    message = %Message{value: "test", key: "key1"}
    plugins = [{LoggingPlugin, []}]

    result =
      PluginHandler.apply_plugins(plugins, message, %{}, fn msg, _state ->
        {:processed, msg}
      end)

    assert {:processed, ^message} = result
    assert Process.get(:logged_message) == "key1"
  end

  test "applies multiple plugins in sequence" do
    message = %Message{value: "test", key: "key1"}

    plugins = [
      {LoggingPlugin, []},
      {TransformPlugin, [transform_to: "transformed"]}
    ]

    result =
      PluginHandler.apply_plugins(plugins, message, %{}, fn msg, _state ->
        msg.value
      end)

    assert result == "transformed"
    assert Process.get(:logged_message) == "key1"
  end
end
