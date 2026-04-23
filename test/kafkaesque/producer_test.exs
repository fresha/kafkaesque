defmodule Kafkaesque.ProducerTest do
  use ExUnit.Case, async: false
  use Mimic

  describe "produce_messages/3" do
    # Functionality
    test "produce message and returns ok" do
      worker_name = :worker_name
      topic = "topic"
      message_key = "key"
      message_value = "value"

      messages = [
        %{key: message_key, value: message_value}
      ]

      expect(KafkaEx, :produce, fn request, _opts ->
        assert request.required_acks == 1
        assert request.timeout == 100
        assert request.topic == "dummy.topic"
        assert request.partition == nil

        message = List.first(request.messages)
        assert message.key == "key"
        assert message.value == "value"

        :ok
      end)

      assert :ok = Kafkaesque.Producer.produce_messages(worker_name, topic, messages)
    end

    test "returns error in case of error returned" do
      worker_name = :worker_name
      topic = "topic"
      message_key = "key"
      message_value = "value"

      messages = [
        %{key: message_key, value: message_value}
      ]

      expect(KafkaEx, :produce, fn request, _opts ->
        assert request.required_acks == 1
        assert request.timeout == 100
        assert request.topic == "dummy.topic"
        assert request.partition == nil

        message = List.first(request.messages)
        assert message.key == "key"
        assert message.value == "value"

        {:error, :unknown}
      end)

      assert {:error, :unknown} = Kafkaesque.Producer.produce_messages(worker_name, topic, messages)
    end

    test "reraise exception in case of error raised" do
      worker_name = :worker_name
      topic = "topic"
      message_key = "key"
      message_value = "value"

      messages = [
        %{key: message_key, value: message_value}
      ]

      expect(KafkaEx, :produce, fn request, _opts ->
        assert request.required_acks == 1
        assert request.timeout == 100
        assert request.topic == "dummy.topic"
        assert request.partition == nil

        message = List.first(request.messages)
        assert message.key == "key"
        assert message.value == "value"

        raise RuntimeError
      end)

      assert_raise RuntimeError, fn ->
        Kafkaesque.Producer.produce_messages(worker_name, topic, messages)
      end
    end

    # Telemetry Events
    test "emits telemetry events on success" do
      setup_telemetry_test_handlers()
      stub(KafkaEx, :produce, fn _, _ -> :ok end)

      Kafkaesque.Producer.produce_messages(:worker_name, "topic", [%{key: "key", value: "value"}])

      assert_receive {
        [:kafkaesque, :produce, :start],
        _,
        %{count: 1, system_time: _, monotonic_time: _},
        %{worker_name: :worker_name, topic: "dummy.topic", messages_count: 1}
      }

      assert_receive {
        [:kafkaesque, :produce, :stop],
        _,
        %{count: 1, monotonic_time: _, duration: _},
        %{worker_name: :worker_name, topic: "dummy.topic", messages_count: 1}
      }

      refute_receive {[:kafkaesque, :produce, :exception], _, _}
    end

    test "emits telemetry events on error" do
      setup_telemetry_test_handlers()
      stub(KafkaEx, :produce, fn _, _ -> {:error, :unknown} end)

      Kafkaesque.Producer.produce_messages(:worker_name, "topic", [%{key: "key", value: "value"}])

      assert_receive {
        [:kafkaesque, :produce, :start],
        _,
        %{count: 1, system_time: _, monotonic_time: _},
        %{worker_name: :worker_name, topic: "dummy.topic", messages_count: 1}
      }

      assert_receive {
        [:kafkaesque, :produce, :stop],
        _,
        %{count: 1, monotonic_time: _, duration: _},
        %{error: :unknown, worker_name: :worker_name, topic: "dummy.topic", messages_count: 1}
      }

      refute_receive {[:kafkaesque, :produce, :exception], _, _, _}
    end

    test "emits telemetry events on exception" do
      setup_telemetry_test_handlers()
      stub(KafkaEx, :produce, fn _, _ -> raise RuntimeError end)

      assert_raise RuntimeError, fn ->
        Kafkaesque.Producer.produce_messages(:worker_name, "topic", [%{key: "key", value: "value"}])
      end

      assert_receive {
        [:kafkaesque, :produce, :start],
        _,
        %{count: 1, system_time: _, monotonic_time: _},
        %{worker_name: :worker_name, topic: "dummy.topic", messages_count: 1}
      }

      refute_receive {
        [:kafkaesque, :produce, :stop],
        _,
        %{count: 1, monotonic_time: _, duration: _},
        %{error: :unknown, worker_name: :worker_name, topic: "dummy.topic", messages_count: 1}
      }

      assert_receive {
        [:kafkaesque, :produce, :exception],
        _,
        %{count: 1, monotonic_time: _, duration: _},
        %{
          kind: :error,
          reason: %RuntimeError{message: "runtime error"},
          stacktrace: _,
          worker_name: :worker_name,
          topic: "dummy.topic",
          messages_count: 1
        }
      }
    end
  end

  defp setup_telemetry_test_handlers do
    :telemetry_test.attach_event_handlers(self(), [
      [:kafkaesque, :produce, :start],
      [:kafkaesque, :produce, :exception],
      [:kafkaesque, :produce, :stop]
    ])
  end
end
