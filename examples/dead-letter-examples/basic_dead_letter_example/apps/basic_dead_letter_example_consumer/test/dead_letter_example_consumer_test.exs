defmodule BasicDeadLetterExampleConsumerTest do
  use ExUnit.Case, async: false

  import Testcontainers.ExUnit
  import BasicDeadLetterExampleConsumer.Support.KafkaHelpers

  container(:kafka, Testcontainers.KafkaContainer.new())

  describe "integration test scenario" do
    test "processes a message with dead letter", %{kafka: kafka} do
      {:ok, _agent} = BasicDeadLetterExampleCore.AgentStorage.start_link()

      # [GIVEN] Kafka is running
      setup_env(kafka)
      {:ok, _client_pid} = start_client(:client, kafka)

      # [GIVEN] Topic exists
      %{topic_errors: [%{error_code: :no_error}]} = create_topic(:client, "ping-events", [])

      # [GIVEN] DLQ topic exists
      %{topic_errors: [%{error_code: :no_error}]} =
        create_topic(:client, "basic-dead-letter-example.ping-events.dead-letter", [])

      # [WHEN] Event Supervisor is connected to topic
      start_supervised!(%{
        id: Kafkaesque.ProducerSupervisor,
        start:
          {Kafkaesque.ProducerSupervisor, :start_link,
           [:basic_dead_letter_example_consumer, [:my_worker]]}
      })

      start_supervised!(BasicDeadLetterExampleConsumer.WithDLQEventsConsumer.Supervisor)
      :timer.sleep(5_000)

      # [WHEN] Invalid messages is published to the topic
      :ok = produce_event(:client, "ping-events", "hallo")
      :timer.sleep(2_000)

      # [THEN] Message is not consumed
      assert BasicDeadLetterExampleCore.AgentStorage.get(:ping) == nil

      # [WHEN] One of consumer is started to consume messages
      BasicDeadLetterExampleConsumer.OneOffConsumer.Consumer.run()
      :timer.sleep(5_000)

      # [THEN] Message is consumed
      assert BasicDeadLetterExampleCore.AgentStorage.get(:ping) == "hello: hallo"
    end
  end
end
