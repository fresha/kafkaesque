defmodule Kafkaesque.Plugins.BeforePlugin do
  @moduledoc false
  @behaviour Kafkaesque.Behaviours.MessageHandlerPlugin

  def validate_opts!(_opts), do: :ok

  def handle_message(message, _s, _opt, next_function) do
    case message.value do
      "success" ->
        update_store(:before_plugin_success)
        next_function.(message)

      "error" ->
        update_store(:before_plugin_error)
        {:error, :plugin_error}
    end
  end

  defp update_store(value) do
    store = Process.get(:store)
    Process.put(:store, [value | store])
  end
end
