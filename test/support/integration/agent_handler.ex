defmodule Kafkaesque.Integration.AgentHandler do
  @moduledoc false
  @behaviour Kafkaesque.Behaviours.MessageHandlerPlugin

  @impl true
  def validate_opts!(_opts), do: :ok

  @impl true
  def handle_message(%{value: value} = message, _consumer_state, plugin_opts, next_function) do
    __MODULE__.put(plugin_opts[:agent], value)
    next_function.(message)
  end

  def start_link(initial_value) do
    Agent.start_link(fn -> initial_value end, name: __MODULE__)
  end

  def put(name, value) do
    Agent.update(name, fn state -> [value | state] end)
  end

  def get(name) do
    Agent.get(name, fn state -> state end)
  end
end
