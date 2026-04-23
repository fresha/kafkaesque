defmodule Kafkaesque.Consumer.ConfigTest do
  use ExUnit.Case, async: true

  alias Kafkaesque.Consumer.Config

  describe "build/1" do
    test "returns valid config with topics_config" do
      opts = [
        consumer_group_identifier: :test_group,
        commit_strategy: :async,
        retries: 3,
        topics_config: %{
          "test_topic" => %{decoder_config: {TestDecoder, [schema: TestSchema]}}
        }
      ]

      config = Config.build(opts)

      assert config.consumer_group_identifier == :test_group
      assert config.commit_strategy == :async
      assert config.retries == 3
      assert config.initial_backoff == 100
      assert config.topics_config == %{"test_topic" => %{decoder_config: {TestDecoder, [schema: TestSchema]}}}
    end

    test "returns valid config with legacy decoders format" do
      opts = [
        consumer_group_identifier: :test_group,
        commit_strategy: :sync,
        retries: 0,
        decoders: %{
          "test_topic" => %{decoder: TestDecoder, opts: [schema: TestSchema]}
        }
      ]

      config = Config.build(opts)

      assert config.consumer_group_identifier == :test_group
      assert config.commit_strategy == :sync
      assert config.retries == 0
      assert config.initial_backoff == 100

      assert config.topics_config == %{
               "test_topic" => %{
                 decoder_config: {TestDecoder, [schema: TestSchema]},
                 dead_letter_producer: nil,
                 handle_message_plugins: []
               }
             }
    end

    test "uses provided initial_backoff value" do
      opts = [
        consumer_group_identifier: :test_group,
        commit_strategy: :async,
        retries: 3,
        initial_backoff: 500,
        topics_config: %{
          "test_topic" => %{decoder_config: {TestDecoder, []}}
        }
      ]

      config = Config.build(opts)

      assert config.initial_backoff == 500
    end

    test "raises when both decoders and topics_config are provided" do
      opts = [
        consumer_group_identifier: :test_group,
        commit_strategy: :async,
        retries: 3,
        decoders: %{"test_topic" => %{decoder: TestDecoder, opts: []}},
        topics_config: %{"test_topic" => %{decoder_config: {TestDecoder, []}}}
      ]

      assert_raise ArgumentError, "only one of :decoders or :topics_config can be provided", fn ->
        Config.build(opts)
      end
    end

    test "raises when neither decoders nor topics_config are provided" do
      opts = [
        consumer_group_identifier: :test_group,
        commit_strategy: :async,
        retries: 3
      ]

      assert_raise ArgumentError, "either :decoders or :topics_config must be provided", fn ->
        Config.build(opts)
      end
    end

    test "raises when consumer_group_identifier is missing" do
      opts = [
        commit_strategy: :async,
        retries: 3,
        topics_config: %{"test_topic" => %{decoder_config: {TestDecoder, []}}}
      ]

      assert_raise KeyError, fn ->
        Config.build(opts)
      end
    end

    test "raises when commit_strategy is missing" do
      opts = [
        consumer_group_identifier: :test_group,
        retries: 3,
        topics_config: %{"test_topic" => %{decoder_config: {TestDecoder, []}}}
      ]

      assert_raise KeyError, fn ->
        Config.build(opts)
      end
    end

    test "raises when retries is missing" do
      opts = [
        consumer_group_identifier: :test_group,
        commit_strategy: :async,
        topics_config: %{"test_topic" => %{decoder_config: {TestDecoder, []}}}
      ]

      assert_raise KeyError, fn ->
        Config.build(opts)
      end
    end

    test "raises error when plugin opts are invalid" do
      opts = [
        consumer_group_identifier: :test_group,
        commit_strategy: :async,
        retries: 3,
        topics_config: %{
          "test_topic" => %{
            decoder_config: {TestDecoder, []},
            handle_message_plugins: [
              {Kafkaesque.Plugins.DummyHandleMessagePlugin, [result: :error]}
            ]
          }
        }
      ]

      assert_raise ArgumentError, fn ->
        Config.build(opts)
      end
    end
  end
end
