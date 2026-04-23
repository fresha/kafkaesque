defmodule Kafkaesque.Plugins.DummyHandleMessagePlugin do
  @moduledoc false
  @behaviour Kafkaesque.Behaviours.MessageHandlerPlugin

  @impl true
  def validate_opts!(opts) do
    case Keyword.get(opts, :result) do
      :error -> raise ArgumentError, "result must be :ok or {:ok, any}"
      _ -> :ok
    end
  end

  @impl true
  def handle_message(message, _consumer_state, _plugin_opts, next_function) do
    send(self(), :message_handled)
    next_function.(message)
  end
end
