defmodule BasicDeadLetterExampleCore do
  @moduledoc """
  Documentation for `BasicDeadLetterExampleCore`.

  Core module for Dead Letter Example app, a place where all domain based logic should be implemented.
  """

  @doc """
  Entry point action to domain, in this case a simple string matching :)
  """
  @spec ping(binary) :: {:ok, :pong} | {:error, :invalid_data}
  def ping(message), do: process_message(message)

  defp process_message(message) do
    case message do
      "hello" <> _ ->
        BasicDeadLetterExampleCore.AgentStorage.put(:ping, message)

      _ ->
        {:error, :invalid_data}
    end
  end
end
