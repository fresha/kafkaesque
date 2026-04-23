defmodule Kafkaesque.Behaviours.MessageHandlerPlugin do
  @moduledoc """
  Behavior for message handler plugins.

  Plugins can intercept messages for side effects (logging, metrics, etc.)
  and/or transform messages before passing them to the next plugin.
  """

  @type message :: KafkaEx.Protocol.Fetch.Message.t()
  @type state :: Kafkaesque.Consumer.State.t()
  @type plugin_opts :: Keyword.t()
  @type next_function :: (message() -> any())

  @doc """
  Handle a message and continue the plugin chain.

  The plugin must call `next_function` with a (possibly modified) message
  to continue processing. The message passed to `next_function` will be
  used by subsequent plugins and the final message handler.
  """
  @callback handle_message(message(), state(), plugin_opts(), next_function()) :: any()

  @doc """
  Validate plugin options at compile time.
  """
  @callback validate_opts!(plugin_opts()) :: :ok | no_return()
end
