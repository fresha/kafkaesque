defmodule BasicDeadLetterExampleConsumer.WithDLQEventsConsumer.Supervisor do
  @moduledoc """
  Supervisor for Events Consumer Area
  """
  use Supervisor
  require Logger

  alias BasicDeadLetterExampleConsumer.WithDLQEventsConsumer.ConsumerSupervisor
  alias BasicDeadLetterExampleConsumer.WithDLQEventsConsumer.Healthchecks

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    opts = [strategy: :one_for_one, name: __MODULE__]

    []
    |> attach_consumer()
    |> register_metrics()
    |> tap(&register_checks/1)
    |> Supervisor.init(opts)
  end

  # -----------------------------------------------------------------
  defp attach_consumer(children), do: [ConsumerSupervisor | children]

  # -----------------------------------------------------------------
  defp register_checks(_) do
    Heartbeats.register_liveness_check([&Healthchecks.kafka_consumer_group_available/0])
  end

  # -----------------------------------------------------------------
  defp register_metrics(children) do
    children
  end
end
