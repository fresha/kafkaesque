defmodule Kafkaesque.Integration.MessagesHandlingTest do
  use ExUnit.Case, async: false
  import Testcontainers.ExUnit

  alias Testcontainers.Container

  alias Kafkaesque.Integration.AgentHandler
  alias Kafkaesque.Integration.AgentStorage

  container(:kafka, Testcontainers.KafkaContainer.new())

  describe "produce & consume messages" do
    test "produces and consumes messages", %{kafka: kafka} do
      # [GIVEN] Environment is setup
      setup_env(kafka)
      start_client(:producer, kafka)
      :timer.sleep(1_000)

      # [GIVEN] Topics are created
      create_topic(:producer, "dummy.proto-event-topic", [])
      create_topic(:producer, "dummy.binary-topic-with-plugin", [])
      create_topic(:producer, "dummy.binary-topic-with-dlq", [])
      create_topic(:producer, "dummy.dead-letter-topic", [])
      :timer.sleep(500)

      # [GIVEN] Consumer is connected to Kafka
      AgentHandler.start_link([])
      AgentStorage.start_link([])
      start_supervised(Kafkaesque.Integration.ConsumerGroup.Supervisor)
      :timer.sleep(500)

      # [WHEN] Debezium Event is produced
      dummy_event =
        %DummyEvent.V1.Payload{id: 1, name: "something_happened", flag: "error"}
        |> then(&%DummyEventEnvelope.V1.Payload{payload: {:dummy_event, &1}})
        |> DummyEventEnvelope.V1.Payload.encode()
        |> DummyEventEnvelope.V1.Payload.decode()

      uuid = "7eb31508-5ad2-4228-92fe-a7e92a9b20f6"

      %{
        uuid: uuid,
        event_type: :dummy_event,
        payload: dummy_event |> DummyEventEnvelope.V1.Payload.encode() |> Base.encode64(),
        timestamp: ~U[2021-02-23 14:48:24.890000Z] |> DateTime.to_unix(:millisecond)
      }
      |> Jason.encode!()
      |> then(&produce_event(:producer, "dummy.proto-event-topic", &1, uuid))

      # [WHEN] Binary Event is produced for topic with plugin
      pluggable_event = "pluggable event"
      produce_event(:producer, "dummy.binary-topic-with-plugin", pluggable_event, uuid)

      # [WHEN] Binary Event is produced for topic with dlq
      dead_letter_event = "dead letter event"
      produce_event(:producer, "dummy.binary-topic-with-dlq", dead_letter_event, uuid)

      # Wait for events to be consumed
      :timer.sleep(5_000)

      # [THEN] Only Debezium & Pluggable Events are consumed
      [debezium_event, binary_event] = AgentStorage.get(AgentStorage) |> Enum.sort()
      assert binary_event == pluggable_event
      assert debezium_event == dummy_event

      # [THEN] Only plugable event was passed to plugin
      [handled_event] = AgentHandler.get(AgentHandler)
      assert handled_event == pluggable_event

      # [THEN] Only DLQ event was passed to DLQ
      [
        %{
          partitions: [
            %{message_set: [%{value: value}]}
          ]
        }
      ] = fetch_event(:producer, "dummy.binary-topic-with-dlq")

      assert value == dead_letter_event
    end
  end

  defp setup_env(kafka) do
    old_uri = Application.get_env(:kafkaesque, :kafka_uris)
    Application.put_env(:kafkaesque, :kafka_uris, "localhost:#{Container.mapped_port(kafka, 9092)}")

    ExUnit.Callbacks.on_exit(fn -> Application.put_env(:kafkaesque, :kafka_uris, old_uri) end)
  end

  defp start_client(worker, kafka) do
    uris = [{"localhost", Container.mapped_port(kafka, 9092)}]
    {:ok, pid} = KafkaEx.create_worker(worker, uris: uris, consumer_group: "kafka_ex")
    ExUnit.Callbacks.on_exit(fn -> :ok = KafkaEx.stop_worker(pid) end)
    {:ok, pid}
  end

  defp create_topic(worker_name, topic_name, opts) do
    request = %KafkaEx.Protocol.CreateTopics.TopicRequest{
      topic: topic_name,
      num_partitions: Keyword.get(opts, :num_partitions, 1),
      replication_factor: Keyword.get(opts, :replication_factor, 1),
      replica_assignment: Keyword.get(opts, :replica_assignment, [])
    }

    KafkaEx.create_topics([request], worker_name: worker_name)
  end

  defp produce_event(worker_name, topic_name, payload, uuid) do
    %KafkaEx.Protocol.Produce.Request{
      topic: topic_name,
      partition: 0,
      required_acks: 0,
      api_version: 3,
      messages: [
        %KafkaEx.Protocol.Produce.Message{
          key: "key",
          value: payload,
          headers: [{"id", uuid}],
          timestamp: :os.system_time(:millisecond)
        }
      ]
    }
    |> KafkaEx.produce(worker_name: worker_name)
  end

  defp fetch_event(worker_name, topic_name) do
    KafkaEx.fetch(topic_name, 0, offset: 0, worker_name: worker_name)
  end
end
