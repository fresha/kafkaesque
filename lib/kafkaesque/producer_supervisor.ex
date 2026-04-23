defmodule Kafkaesque.ProducerSupervisor do
  @moduledoc """
  Top level supervisor for spinning up and supervising the worker processes that produce messages to Kafka.
  """
  require Logger

  use Supervisor

  @spec start_link(app_name :: atom, worker_names :: list(atom)) ::
          {:ok, pid} | {:error, any}
  def start_link(app_name, worker_names) do
    sup_name = String.to_atom("#{app_name}.kafkaesque.producer_supervisor")
    Supervisor.start_link(__MODULE__, [worker_names], name: sup_name)
  end

  @impl true
  def init([worker_names]) do
    # Start a worker process for each `worker_name` provided
    children =
      worker_names
      |> Enum.map(&worker_spec(&1))

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp worker_spec(worker_name) do
    config = Kafkaesque.ProducerConfig.build_config()

    %{
      id: worker_name,
      start: {KafkaEx, :start_link_worker, [worker_name, config]}
    }
  end
end
