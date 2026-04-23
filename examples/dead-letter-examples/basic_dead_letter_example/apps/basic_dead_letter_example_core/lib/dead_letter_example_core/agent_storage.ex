defmodule BasicDeadLetterExampleCore.AgentStorage do
  @moduledoc """
  Documentation for `BasicDeadLetterExampleCore.AgentStorage`.
  """

  def start_link do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  @doc """
  Puts value in the storage by key
  """
  def put(key, value) do
    Agent.update(__MODULE__, &Map.put(&1, key, value))
  end

  @doc """
  Gets value from the storage by key
  """
  def get(key) do
    Agent.get(__MODULE__, &Map.get(&1, key))
  end
end
