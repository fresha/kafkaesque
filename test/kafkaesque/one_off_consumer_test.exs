defmodule OneOffConsumerTest do
  use ExUnit.Case, async: false
  use ExUnit.CaseTemplate
  use Mimic

  import ExUnit.CaptureLog
  import Testcontainers.ExUnit

  alias DummyEventEnvelope.V1.Payload
  alias Testcontainers.Container

  container(:kafka, Testcontainers.KafkaContainer.new())

  @topic "test-topic"
  @consumer_group_identifier "test-group"

  @valid_consumer_options [
    consumer_group_identifier: @consumer_group_identifier,
    topics: [@topic],
    decoders: [
      {@topic, %{decoder: Kafkaesque.Decoders.DebeziumProtoDecoder, opts: [schema: Payload]}}
    ],
    max_idle_time: 0
  ]

  describe "Kafkaesque.OneOffConsumer" do
    setup do
      Mimic.copy(Kafkaesque.Consumer.Config)
      :ok
    end

    test "validates required options", %{kafka: kafka} do
      setup_env(kafka)

      consumer_group_identifier_missing = Keyword.delete(@valid_consumer_options, :consumer_group_identifier)
      topics_missing = Keyword.delete(@valid_consumer_options, :topics)
      decoders_missing = Keyword.delete(@valid_consumer_options, :decoders)

      assert_raise KeyError, ~r/key :consumer_group_identifier not found in/, fn ->
        defmodule InvalidConsumer1 do
          use Kafkaesque.OneOffConsumer, consumer_group_identifier_missing
        end
      end

      assert_raise KeyError, ~r/key :topics not found in:/, fn ->
        defmodule InvalidConsumer2 do
          use Kafkaesque.OneOffConsumer, topics_missing
        end
      end

      assert_raise KeyError, ~r/key :decoders not found in:/, fn ->
        defmodule InvalidConsumer3 do
          use Kafkaesque.OneOffConsumer, decoders_missing
        end
      end
    end

    test "propagates options to Kafkaesque.Consumer.Config", %{kafka: kafka} do
      setup_env(kafka)

      options =
        @valid_consumer_options
        |> Keyword.put(:retries, 3)
        |> Keyword.put(:initial_backoff, 200)

      # Assert that the config is built with the correct options
      expect(Kafkaesque.Consumer.Config, :build, fn opts ->
        assert opts === [
                 commit_strategy: :sync,
                 decoders: [{@topic, %{decoder: Kafkaesque.Decoders.DebeziumProtoDecoder, opts: [schema: Payload]}}],
                 consumer_group_identifier: @consumer_group_identifier,
                 retries: 3,
                 initial_backoff: 200
               ]
      end)

      capture_log(&OneOffConsumerTest.OneOffConsumerFactory.create(options).run/0)

      verify!()
    end

    test "terminates after idle time", %{kafka: kafka} do
      setup_env(kafka)

      # Assert that the config is built with the correct options
      expect(Kafkaesque.Consumer.Config, :build, fn opts ->
        assert opts ===
                 [
                   commit_strategy: :sync,
                   decoders: [{@topic, %{decoder: Kafkaesque.Decoders.DebeziumProtoDecoder, opts: [schema: Payload]}}],
                   consumer_group_identifier: @consumer_group_identifier,
                   retries: 0,
                   initial_backoff: nil
                 ]
      end)

      logs = capture_log(&OneOffConsumerTest.OneOffConsumerFactory.create(@valid_consumer_options).run/0)

      assert logs =~ "One-off consumer started"
      assert logs =~ "One-off consumer exceeded idle time, terminating..."
      assert logs =~ "One-off consumer terminated"

      verify!()
    end

    test "propagates auto_offset_reset to Kafkaesque.ConsumerConfig via env", %{kafka: kafka} do
      setup_env(kafka)

      old = Application.get_env(:kafkaesque, :consumer_opts)
      on_exit(fn -> Application.put_env(:kafkaesque, :consumer_opts, old) end)

      capture_log(&OneOffConsumerTest.OneOffConsumerFactory.create(@valid_consumer_options).run/0)

      assert Application.get_env(:kafkaesque, :consumer_opts)[:auto_offset_reset] == :earliest
    end

    defp setup_env(kafka) do
      old_uri = Application.get_env(:kafkaesque, :kafka_uris)
      Application.put_env(:kafkaesque, :kafka_uris, "localhost:#{Container.mapped_port(kafka, 9092)}")

      ExUnit.Callbacks.on_exit(fn -> Application.put_env(:kafkaesque, :kafka_uris, old_uri) end)
    end
  end

  defmodule OneOffConsumerFactory do
    # Creates a dynamic one-off consumer module with the given options
    def create(opts \\ []) do
      module_name =
        Module.concat([
          __MODULE__,
          "DynamicConsumer#{System.unique_integer([:positive])}"
        ])

      module_definition =
        quote do
          use Kafkaesque.OneOffConsumer, unquote(Macro.escape(opts))

          @impl true
          def handle_decoded_message(_message), do: :ok

          def run do
            run_consumer(:earliest)
          end
        end

      Module.create(module_name, module_definition, __ENV__)
      module_name
    end
  end
end
