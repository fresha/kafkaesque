defmodule Kafkaesque.ConsumerTest do
  use ExUnit.Case, async: false
  use Mimic

  import ExUnit.CaptureLog

  alias DummyEvent.V1.Payload
  alias DummyEventEnvelope.V1.Payload, as: Envelope

  alias Kafkaesque.DummyConsumerV2, as: DummyConsumer

  @topic "test.dummy_events"
  describe "Handle message batch: processing successful" do
    test "messages return :ok, messages are decoded as expected" do
      message_set = Enum.map(1..10, fn _ -> dummy_message(1) end)

      {:ok, state} = DummyConsumer.init(@topic, 0, init_opts(false))
      result_1 = DummyConsumer.handle_batch(message_set, state)

      assert :ok == result_1
    end

    test "messages return {:ok, any}, messages are decoded as expected" do
      message_set = Enum.map(1..10, fn _ -> dummy_message(2) end)

      {:ok, state} = DummyConsumer.init(@topic, 0, init_opts(false))
      result_1 = DummyConsumer.handle_batch(message_set, state)

      assert :ok == result_1
    end
  end

  describe "handle message batch: plugins are invoked" do
    test "messages return :ok, messages are decoded as expected" do
      topic = "test.dummy_events_with_plugins"

      message_set = [dummy_message(1)]
      message_set = Enum.map(message_set, fn msg -> Map.put(msg, :topic, topic) end)

      {:ok, state} = DummyConsumer.init(topic, 0, init_opts(false))
      result_1 = DummyConsumer.handle_batch(message_set, state)

      assert :ok == result_1
      assert_receive :message_handled
    end

    test "messages return {:ok, any}, messages are decoded as expected" do
      topic = "test.dummy_events_with_plugins"

      message_set = [dummy_message(1)]
      message_set = Enum.map(message_set, fn msg -> Map.put(msg, :topic, topic) end)

      {:ok, state} = DummyConsumer.init(topic, 0, init_opts(false))
      result_1 = DummyConsumer.handle_batch(message_set, state)

      assert :ok == result_1
      assert_receive :message_handled
    end
  end

  describe "Handle message batch: processing unsuccessful" do
    test "simple consumer - processing errors are propagated" do
      message_set = Enum.map(1..10, fn _ -> dummy_message(3) end)

      {:ok, state} = DummyConsumer.init(@topic, 0, init_opts(false))

      capture_log(fn ->
        assert_raise Kafkaesque.MessageProcessingError, "Message processing failed due to: {:error, :failure}", fn ->
          DummyConsumer.handle_batch(message_set, state)
        end
      end)
    end
  end

  describe "Handle messages batch: retry logic" do
    # 3 times is simple consumer configuration
    @tag capture_log: true
    test "when error tuple is returned, consumer retry messages handling 3 times" do
      message_set = Enum.map(1..10, fn _ -> dummy_message(3) end)

      {:ok, state} = DummyConsumer.init(@topic, 0, init_opts(false))

      assert_raise Kafkaesque.MessageProcessingError, "Message processing failed due to: {:error, :failure}", fn ->
        DummyConsumer.handle_batch(message_set, state)
      end

      # Initial + 3 retry
      for _ <- 1..4, do: assert_received(:failure)

      refute_receive :failure
      refute_receive :exception
    end

    @tag capture_log: true
    test "when error is raised, consumer retry message handling 3 times" do
      message_set = Enum.map(1..10, fn _ -> dummy_message(4) end)

      {:ok, state} = DummyConsumer.init(@topic, 0, init_opts(false))

      assert_raise RuntimeError, fn ->
        DummyConsumer.handle_batch(message_set, state)
      end

      # Initial + 3 retry
      for _ <- 1..4, do: assert_received(:exception)

      refute_receive :failure
      refute_receive :exception
    end
  end

  describe "Handle messages batch: logger notifications" do
    test "when error tuple is returned, consumer retry messages handling 3 times" do
      message_set = Enum.map(1..10, fn _ -> dummy_message(3) end)

      {:ok, state} = DummyConsumer.init(@topic, 0, init_opts(false))

      logs =
        capture_log(fn ->
          assert_raise Kafkaesque.MessageProcessingError, "Message processing failed due to: {:error, :failure}", fn ->
            DummyConsumer.handle_batch(message_set, state)
          end
        end)

      assert logs =~ "Message handling failed with error: :failure. Retrying... "
    end

    test "when error is raised, consumer retry message handling 3 times" do
      message_set = Enum.map(1..10, fn _ -> dummy_message(4) end)

      {:ok, state} = DummyConsumer.init(@topic, 0, init_opts(false))

      logs =
        capture_log(fn ->
          assert_raise RuntimeError, fn ->
            DummyConsumer.handle_batch(message_set, state)
          end
        end)

      assert logs =~ "Message handling failed with exception: %RuntimeError{message: \"runtime error\"}. Retrying..."
    end
  end

  describe "Handle message batch: messages fail to be decoded" do
    test "simple consumer - decoding exceptions are reraised" do
      message_set = [invalid_message()]

      {:ok, state} = DummyConsumer.init(@topic, 0, init_opts(false))

      capture_log(fn ->
        assert_raise ArgumentError, fn ->
          DummyConsumer.handle_batch(message_set, state)
        end
      end)
    end
  end

  describe "Handle message batch: batch telemetry events are emitted" do
    test "telemetry events are emitted" do
      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:kafkaesque, :consume_batch, :start],
          [:kafkaesque, :consume_batch, :exception],
          [:kafkaesque, :consume_batch, :stop]
        ])

      message = dummy_message(1)

      {:ok, state} = DummyConsumer.init(@topic, 0, init_opts(false))

      DummyConsumer.handle_message_set([message], state)

      assert_received {[:kafkaesque, :consume_batch, :start], ^ref, %{count: 1, system_time: _, monotonic_time: _},
                       %{
                         topic: "test.dummy_events",
                         partition: 0,
                         batch_size: 1,
                         dead_letter_producer: nil,
                         consumer_group: "dummy.dummy.consumer",
                         consumer_group_identifier: "dummy.consumer",
                         start_time: _
                       }}

      assert_received {[:kafkaesque, :consume_batch, :stop], ^ref, %{count: 1, duration: _, monotonic_time: _},
                       %{
                         topic: "test.dummy_events",
                         partition: 0,
                         batch_size: 1,
                         dead_letter_producer: nil,
                         consumer_group: "dummy.dummy.consumer",
                         consumer_group_identifier: "dummy.consumer",
                         start_time: _
                       }}

      refute_received {[:kafkaesque, :consume_batch, :exception], ^ref, _, _}
    end

    test "telemetry events are also emitted in case of error" do
      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:kafkaesque, :consume_batch, :start],
          [:kafkaesque, :consume_batch, :stop],
          [:kafkaesque, :consume_batch, :exception]
        ])

      message = error_message(1)

      {:ok, state} = DummyConsumer.init(@topic, 0, init_opts(false))

      capture_log(fn ->
        assert_raise Kafkaesque.MessageError, fn ->
          DummyConsumer.handle_message_set([message], state)
        end
      end)

      assert_received {[:kafkaesque, :consume_batch, :start], ^ref, %{count: 1, system_time: _, monotonic_time: _},
                       %{
                         topic: "test.dummy_events",
                         partition: 0,
                         batch_size: 1,
                         dead_letter_producer: nil,
                         consumer_group: "dummy.dummy.consumer",
                         consumer_group_identifier: "dummy.consumer",
                         start_time: _
                       }}

      assert_received {[:kafkaesque, :consume_batch, :exception], ^ref, %{count: 1, duration: _, monotonic_time: _},
                       %{
                         topic: "test.dummy_events",
                         partition: 0,
                         batch_size: 1,
                         dead_letter_producer: nil,
                         consumer_group: "dummy.dummy.consumer",
                         consumer_group_identifier: "dummy.consumer",
                         start_time: _,
                         kind: :error,
                         reason: _,
                         stacktrace: _
                       }}

      refute_received {[:kafkaesque, :consume_batch, :stop], ^ref, _, _}
    end
  end

  describe "Handle message batch: messages telemetry events are emitted" do
    test "telemetry events are emitted" do
      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:kafkaesque, :consume, :start],
          [:kafkaesque, :consume, :exception],
          [:kafkaesque, :consume, :stop]
        ])

      message = dummy_message(1)

      {:ok, state} = DummyConsumer.init(@topic, 0, init_opts(false))

      capture_log(fn ->
        assert :ok = DummyConsumer.handle_batch([message], state)
      end)

      expected_metadata = %{
        topic: "test.dummy_events",
        partition: 0,
        key: "1",
        offset: 0,
        consumer_group: "dummy.dummy.consumer",
        consumer_group_identifier: "dummy.consumer"
      }

      assert_received {[:kafkaesque, :consume, :start], ^ref, _, ^expected_metadata}

      refute_received {[:kafkaesque, :consume, :exception], ^ref, _, _}

      assert_received {[:kafkaesque, :consume, :stop], ^ref, _, ^expected_metadata}
    end

    test "telemetry events are also emitted in case of error" do
      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:kafkaesque, :consume, :start],
          [:kafkaesque, :consume, :exception],
          [:kafkaesque, :consume, :stop]
        ])

      message = error_message(1)

      {:ok, state} = DummyConsumer.init(@topic, 0, init_opts(false))

      capture_log(fn ->
        assert_raise Kafkaesque.MessageError, fn ->
          DummyConsumer.handle_batch([message], state)
        end
      end)

      expected_metadata = %{
        topic: "test.dummy_events",
        partition: 0,
        key: "1",
        offset: 0,
        consumer_group: "dummy.dummy.consumer",
        consumer_group_identifier: "dummy.consumer"
      }

      assert_received {[:kafkaesque, :consume, :start], ^ref, _, ^expected_metadata}

      assert_received {[:kafkaesque, :consume, :exception], ^ref, _, _}

      refute_received {[:kafkaesque, :consume, :stop], ^ref, _, _}
    end

    test "telemetry events are also emitted in case of retry" do
      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:kafkaesque, :consume, :retry]
        ])

      message = error_message(1)

      {:ok, state} = DummyConsumer.init(@topic, 0, init_opts(false))

      capture_log(fn ->
        assert_raise Kafkaesque.MessageError, fn ->
          DummyConsumer.handle_batch([message], state)
        end
      end)

      assert_received {
        [:kafkaesque, :consume, :retry],
        ^ref,
        %{count: 1, monotonic_time: _, duration: _},
        %{retry_count: 1}
      }

      assert_received {
        [:kafkaesque, :consume, :retry],
        ^ref,
        %{count: 1, monotonic_time: _, duration: _},
        %{retry_count: 2}
      }

      assert_received {
        [:kafkaesque, :consume, :retry],
        ^ref,
        %{count: 1, monotonic_time: _, duration: _},
        %{retry_count: 3}
      }

      refute_received {
        [:kafkaesque, :consume, :retry],
        ^ref,
        %{count: 1, monotonic_time: _, duration: _},
        %{retry_count: 4}
      }
    end
  end

  describe "Handle message batch - dead letter queue checks" do
    test "if enabled, invalid messages are sent to the dead letter queue" do
      message = invalid_message()

      {:ok, state} = DummyConsumer.init(@topic, 0, init_opts(true))

      expect(Kafkaesque.DeadLetterQueue.KafkaTopicProducer, :send_to_dead_letter_queue, fn rcv_message,
                                                                                           _rcv_state,
                                                                                           opts ->
        assert rcv_message == message
        assert Keyword.get(opts, :topic) == "dummy.dlq"
        assert Keyword.get(opts, :worker_name) == "dlq_worker"
        assert Keyword.has_key?(opts, :error)

        :ok
      end)

      capture_log(fn ->
        assert :ok = DummyConsumer.handle_batch([message], state)
      end)
    end

    test "the dead letter queue topic name can be configured" do
      message = invalid_message()

      {:ok, state} = DummyConsumer.init(@topic, 0, init_opts(true, dead_letter_queue: "other.dlq"))

      expect(Kafkaesque.DeadLetterQueue.KafkaTopicProducer, :send_to_dead_letter_queue, fn rcv_message,
                                                                                           _rcv_state,
                                                                                           opts ->
        assert rcv_message == message
        assert Keyword.get(opts, :topic) == "other.dlq"
        assert Keyword.get(opts, :worker_name) == "dlq_worker"
        assert Keyword.has_key?(opts, :error)

        :ok
      end)

      capture_log(fn ->
        assert :ok = DummyConsumer.handle_batch([message], state)
      end)
    end

    test "the dead letter queue topic name can be configured per topic" do
      message = invalid_message()
      topic = "test.dummy_events_with_dead_letter"
      {:ok, state} = DummyConsumer.init(topic, 0, init_opts(true))

      message = message |> Map.put(:topic, topic)

      expect(Kafkaesque.DeadLetterQueue.KafkaTopicProducer, :send_to_dead_letter_queue, fn rcv_message,
                                                                                           _rcv_state,
                                                                                           opts ->
        assert rcv_message == message
        assert Keyword.get(opts, :topic) == "some_topic"
        assert Keyword.get(opts, :worker_name) == :some_worker
        assert Keyword.has_key?(opts, :error)

        :ok
      end)

      capture_log(fn ->
        assert :ok = DummyConsumer.handle_batch([message], state)
      end)
    end

    test "when error tuple is returned, message is send to DLQ instead of raising error" do
      message = dummy_message(3)

      {:ok, state} = DummyConsumer.init(@topic, 0, init_opts(true))

      expect(Kafkaesque.DeadLetterQueue.KafkaTopicProducer, :send_to_dead_letter_queue, fn rcv_message,
                                                                                           _rcv_state,
                                                                                           opts ->
        assert rcv_message == message
        assert Keyword.get(opts, :topic) == "dummy.dlq"
        assert Keyword.get(opts, :worker_name) == "dlq_worker"
        assert Keyword.has_key?(opts, :error)

        :ok
      end)

      capture_log(fn ->
        assert :ok = DummyConsumer.handle_batch([message], state)
      end)
    end

    test "when error is raised, consumer retry message handling 3 times" do
      message = dummy_message(4)

      {:ok, state} = DummyConsumer.init(@topic, 0, init_opts(true))

      expect(Kafkaesque.DeadLetterQueue.KafkaTopicProducer, :send_to_dead_letter_queue, fn rcv_message,
                                                                                           _rcv_state,
                                                                                           opts ->
        assert rcv_message == message
        assert Keyword.get(opts, :topic) == "dummy.dlq"
        assert Keyword.get(opts, :worker_name) == "dlq_worker"
        assert Keyword.has_key?(opts, :error)

        :ok
      end)

      capture_log(fn ->
        assert :ok = DummyConsumer.handle_batch([message], state)
      end)
    end

    test "when message is send to dead letter, other messages from batch are processed" do
      exception_message = dummy_message(4)
      valid_message = dummy_message(2)

      {:ok, state} = DummyConsumer.init(@topic, 0, init_opts(true))

      expect(Kafkaesque.DeadLetterQueue.KafkaTopicProducer, :send_to_dead_letter_queue, fn rcv_message,
                                                                                           _rcv_state,
                                                                                           opts ->
        assert rcv_message == exception_message
        assert Keyword.get(opts, :topic) == "dummy.dlq"
        assert Keyword.get(opts, :worker_name) == "dlq_worker"
        assert Keyword.has_key?(opts, :error)

        :ok
      end)

      capture_log(fn ->
        assert :ok = DummyConsumer.handle_batch([exception_message, valid_message], state)
      end)

      assert_receive :good
    end

    test "error - when message is send to dead letter, message metadata is marked as error" do
      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:kafkaesque, :consume, :start],
          [:kafkaesque, :consume, :exception],
          [:kafkaesque, :consume, :stop]
        ])

      message = dummy_message(3)
      {:ok, state} = DummyConsumer.init(@topic, 0, init_opts(true))

      expect(Kafkaesque.DeadLetterQueue.KafkaTopicProducer, :send_to_dead_letter_queue, fn rcv_message,
                                                                                           _rcv_state,
                                                                                           opts ->
        assert rcv_message == message
        assert Keyword.get(opts, :topic) == "dummy.dlq"
        assert Keyword.get(opts, :worker_name) == "dlq_worker"
        assert Keyword.has_key?(opts, :error)

        :ok
      end)

      capture_log(fn ->
        assert :ok = DummyConsumer.handle_batch([message], state)
      end)

      for _ <- 1..4, do: assert_received(:failure)

      assert_received {[:kafkaesque, :consume, :start], ^ref, _, _}

      assert_received {[:kafkaesque, :consume, :stop], ^ref, _,
                       %{
                         topic: "test.dummy_events",
                         partition: 0,
                         key: "3",
                         offset: 0,
                         consumer_group: "dummy.dummy.consumer",
                         consumer_group_identifier: "dummy.consumer",
                         error: :failure
                       }}

      refute_received {[:kafkaesque, :consume, :exception], ^ref, _, _}
    end

    test "exception - when message is send to dead letter, message metadata is marked as error" do
      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:kafkaesque, :consume, :start],
          [:kafkaesque, :consume, :exception],
          [:kafkaesque, :consume, :stop]
        ])

      message = error_message(1)
      {:ok, state} = DummyConsumer.init(@topic, 0, init_opts(true))

      expect(Kafkaesque.DeadLetterQueue.KafkaTopicProducer, :send_to_dead_letter_queue, fn rcv_message,
                                                                                           _rcv_state,
                                                                                           opts ->
        assert rcv_message == message
        assert Keyword.get(opts, :topic) == "dummy.dlq"
        assert Keyword.get(opts, :worker_name) == "dlq_worker"
        assert Keyword.has_key?(opts, :error)

        :ok
      end)

      capture_log(fn ->
        assert :ok = DummyConsumer.handle_batch([message], state)
      end)

      assert_received {[:kafkaesque, :consume, :start], ^ref, _, _}

      refute_received {[:kafkaesque, :consume, :stop], ^ref, _, _}

      assert_received {[:kafkaesque, :consume, :exception], ^ref, _,
                       %{
                         topic: "test.dummy_events",
                         partition: 0,
                         key: "1",
                         offset: 0,
                         consumer_group: "dummy.dummy.consumer",
                         consumer_group_identifier: "dummy.consumer",
                         kind: :error,
                         reason: %Kafkaesque.MessageError{description: "Error"},
                         stacktrace: _
                       }}
    end
  end

  defp invalid_message do
    "BAD VALUE"
    |> kafka_message(1)
  end

  defp error_message(id) do
    id
    |> create_message()
    |> encode_event()
    |> Base.encode64()
    |> kafka_message(1, "raise_error")
  end

  defp dummy_message(id) do
    id
    |> create_message()
    |> encode_event()
    |> Base.encode64()
    |> kafka_message(id)
  end

  def encode_event(proto_payload) do
    %Envelope{payload: {:dummy_event, proto_payload}}
    |> Envelope.encode()
  end

  defp kafka_message(
         message,
         id,
         event_type \\ "dummy_event",
         uuid \\ "7eb31508-5ad2-4228-92fe-a7e92a9b20f6"
       ) do
    %KafkaEx.Protocol.Fetch.Message{
      attributes: 0,
      crc: 1_074_722_846,
      key: "#{id}",
      offset: 0,
      partition: 0,
      timestamp: 1_614_091_714_698,
      headers: [
        {"x-datadog-trace-id", "123"},
        {"x-datadog-sampling-priority", "1"},
        {"x-datadog-parent-id", "123456789"}
      ],
      topic: "test.dummy_events",
      value: ~s({
        "uuid":"#{uuid}",
        "event_type":"#{event_type}",
        "payload":"#{message}",
        "timestamp":1614091714698}
      )
    }
  end

  defp create_message(id) do
    %Payload{
      id: id,
      name: "something_happened",
      flag: "error",
      created_at: "2021-08-13T12:00:00Z"
    }
  end

  defp init_opts(false = _dead_letter_queue_enabled) do
    %{
      consumer_group_identifier: "dummy.consumer",
      dead_letter_queue: nil,
      dead_letter_queue_worker: nil
    }
  end

  defp init_opts(true = _dead_letter_queue_enabled, extra_opts \\ []) do
    %{
      consumer_group_identifier: "dummy.consumer",
      dead_letter_queue: Keyword.get(extra_opts, :dead_letter_queue, "dummy.dlq"),
      dead_letter_queue_worker: Keyword.get(extra_opts, :dead_letter_queue_worker, "dlq_worker")
    }
  end
end
