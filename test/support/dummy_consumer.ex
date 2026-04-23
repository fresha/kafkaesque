defmodule Kafkaesque.DummyConsumer do
  @moduledoc false

  alias DummyEventEnvelope.V1.Payload, as: Envelope

  use Kafkaesque.Consumer,
    commit_strategy: :sync,
    consumer_group_identifier: "dummy.consumer",
    decoders: %{
      "dummy_events" => %{
        decoder: Kafkaesque.Decoders.DebeziumProtoDecoder,
        opts: [schema: Envelope]
      }
    },
    retries: 3

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

  @expected_payload_4 %DummyEvent.V1.Payload{
    id: 4,
    name: "something_happened",
    flag: "error",
    created_at: "2021-08-13T12:00:00Z"
  }

  @impl true
  def handle_decoded_message(%{
        event_type: :dummy_event,
        proto_payload: %Envelope{payload: {:dummy_event, @expected_payload_1}}
      }) do
    :ok
  end

  def handle_decoded_message(%{
        event_type: :dummy_event,
        proto_payload: %Envelope{payload: {:dummy_event, @expected_payload_2}}
      }) do
    send(self(), :good)
    {:ok, :good}
  end

  def handle_decoded_message(%{
        event_type: :dummy_event,
        proto_payload: %Envelope{payload: {:dummy_event, @expected_payload_3}}
      }) do
    send(self(), :failure)

    {:error, :failure}
  end

  def handle_decoded_message(%{
        event_type: :dummy_event,
        proto_payload: %Envelope{payload: {:dummy_event, @expected_payload_4}}
      }) do
    send(self(), :exception)

    raise RuntimeError
  end

  def handle_decoded_message(%{event_type: :raise_error}) do
    raise Kafkaesque.MessageError, description: "Error"
  end
end
