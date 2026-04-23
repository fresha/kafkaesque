defmodule BasicDeadLetterExampleConsumer.Application do
  @moduledoc """
  BasicDeadLetterExampleConsumer.Application
  """
  use Application

  alias BasicDeadLetterExampleConsumer.WithDLQEventsConsumer.Supervisor, as: EventsSupervisor

  @impl true
  def start(_type, _args) do
    opts = [strategy: :one_for_one, name: BasicDeadLetterExampleConsumer.Supervisor]
    kafkaesque_metrics = Monitor.Kafkaesque.kafkaesque_metrics()

    []
    |> maybe_attach_events_consumer(attach_events_consumer?())
    |> maybe_attach_kafka_producer(attach_events_consumer?())
    |> Monitor.Metrics.maybe_prepend_metrics_reporter(kafkaesque_metrics)
    |> Supervisor.start_link(opts)
  end

  defp maybe_attach_events_consumer(children, true), do: [EventsSupervisor | children]
  defp maybe_attach_events_consumer(children, _), do: children

  defp maybe_attach_kafka_producer(children, true) do
    producer_spec = %{
      id: Kafkaesque.ProducerSupervisor,
      start:
        {Kafkaesque.ProducerSupervisor, :start_link,
         [[:basic_dead_letter_example_consumer, [:my_worker]]]},
      type: :supervisor
    }

    [producer_spec | children]
  end

  defp maybe_attach_kafka_producer(children, _), do: children

  # -----------------------------------------------------------------
  defp attach_events_consumer?() do
    :basic_dead_letter_example_consumer
    |> Application.get_env(:events_consumer, [])
    |> Keyword.get(:consume_events, false)
  end
end
