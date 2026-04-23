defmodule Kafkaesque.Integration.AgentStorage do
  @moduledoc false

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
