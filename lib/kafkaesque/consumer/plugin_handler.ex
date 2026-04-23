defmodule Kafkaesque.Consumer.PluginHandler do
  @moduledoc """
  Simplified plugin handler with unified plugin type.
  """

  @type plugin :: {module(), Keyword.t()}
  @type message :: KafkaEx.Protocol.Fetch.Message.t()
  @type consumer_state :: Kafkaesque.Consumer.State.t()

  @doc """
  Apply plugins in sequence. Each plugin receives the message and can modify it
  before passing it to the next plugin in the chain.
  """
  @spec apply_plugins([plugin()], message(), consumer_state(), function()) :: any()
  def apply_plugins(plugins, message, consumer_state, last_function) do
    do_apply_plugin(plugins, message, consumer_state, last_function)
  end

  defp do_apply_plugin([], message, consumer_state, last_function) do
    last_function.(message, consumer_state)
  end

  defp do_apply_plugin([{plugin, plugin_opts} | tail_plugins], message, state, last_function) do
    plugin.handle_message(message, state, plugin_opts, fn modified_message ->
      do_apply_plugin(tail_plugins, modified_message, state, last_function)
    end)
  end
end
