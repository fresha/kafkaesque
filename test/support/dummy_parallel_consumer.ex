defmodule Kafkaesque.DummyParallelConsumer do
  @moduledoc false

  alias DummyEventEnvelope.V1.Payload, as: Envelope

  use Kafkaesque.Consumer,
    commit_strategy: :async,
    consumer_group_identifier: "dummy.consumer",
    decoders: %{
      "dummy_events" => %{
        decoder: Kafkaesque.Decoders.DebeziumProtoDecoder,
        opts: [schema: Envelope]
      }
    },
    retries: 1,
    initial_backoff: 500

  @max_concurrency 5

  @expected_payload_1 %DummyEvent.V1.Payload{
    id: 1,
    name: "something_happened",
    flag: "error",
    created_at: "2021-08-13T12:00:00Z"
  }

  @expected_payload_2 %DummyEvent.V1.Payload{
    id: 2,
    name: "something_happened",
    flag: "error",
    created_at: "2021-08-13T12:00:00Z"
  }

  @expected_payload_3 %DummyEvent.V1.Payload{
    id: 3,
    name: "something_happened",
    flag: "error",
    created_at: "2021-08-13T12:00:00Z"
  }

  def handle_parallel_message(message, state) do
    handle_message(message, state)
  end

  @impl Kafkaesque.Consumer
  def handle_batch(message_set, state) do
    {:ok, pid} = Task.Supervisor.start_link()

    updated_state = %Kafkaesque.Consumer.State{state | start_time: System.monotonic_time(:microsecond)}

    pid
    |> Task.Supervisor.async_stream_nolink(message_set, &handle_parallel_message(&1, updated_state),
      max_concurrency: @max_concurrency
    )
    |> Stream.run()
  end

  @impl Kafkaesque.Consumer
  def handle_decoded_message(%{
        event_type: :dummy_event,
        proto_payload: %Envelope{payload: {:dummy_event, @expected_payload_1}}
      }) do
    :ok
  end

  @impl Kafkaesque.Consumer
  def handle_decoded_message(%{
        event_type: :dummy_event,
        proto_payload: %Envelope{payload: {:dummy_event, @expected_payload_2}}
      }) do
    {:ok, :good}
  end

  @impl Kafkaesque.Consumer
  def handle_decoded_message(%{
        event_type: :dummy_event,
        proto_payload: %Envelope{payload: {:dummy_event, @expected_payload_3}}
      }) do
    {:error, :failure}
  end

  @impl Kafkaesque.Consumer
  def handle_decoded_message(%{event_type: :raise_error}) do
    raise Kafkaesque.MessageError, description: "Error"
  end

  @impl Kafkaesque.Consumer
  def handle_error({:error, :failure, []}, %Message{} = _message, _state) do
    # Ensure handle_error is called with the same reason
    {:error, :failure}
  end
end
