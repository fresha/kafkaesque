defmodule Kafkaesque.Plugins.ConsumerWithPluginsTest do
  use ExUnit.Case, async: false

  alias Kafkaesque.Support.Plugins.ConsumerWithPlugins

  describe "single before plugin" do
    setup do
      Process.put(:store, [])
      :ok
    end

    test "calls plugin before message is handled" do
      state = build_consumer_state("with_before_plugin")
      message = build_message("success")

      :ok = ConsumerWithPlugins.handle_batch([message], state)

      assert [:handled, :before_plugin_success] == Process.get(:store)
    end

    test "when plugins returns error, message is not handled and error is raised" do
      state = build_consumer_state("with_before_plugin")
      message = build_message("error")

      assert_raise Kafkaesque.MessageProcessingError, fn ->
        ConsumerWithPlugins.handle_batch([message], state)
      end

      assert [:before_plugin_error] == Process.get(:store)
    end
  end

  describe "single after plugin" do
    setup do
      Process.put(:store, [])
      :ok
    end

    test "calls plugin after message is handled" do
      state = build_consumer_state("with_after_plugin")
      message = build_message("success")

      :ok = ConsumerWithPlugins.handle_batch([message], state)

      assert [:after_plugin_success, :handled] == Process.get(:store)
    end

    test "when plugin returns error, message is handled anyway but error is raised" do
      state = build_consumer_state("with_after_plugin")
      message = build_message("error")

      assert_raise Kafkaesque.MessageProcessingError, fn ->
        ConsumerWithPlugins.handle_batch([message], state)
      end

      assert [:after_plugin_error, :handled] == Process.get(:store)
    end
  end

  describe "wrapper plugin" do
    setup do
      Process.put(:store, [])
      :ok
    end

    test "calls before and after plugins" do
      state = build_consumer_state("with_wrapper_plugin")
      message = build_message("success")

      :ok = ConsumerWithPlugins.handle_batch([message], state)

      assert [:wrapper_after_plugin_success, :handled, :wrapper_before_plugin_success] == Process.get(:store)
    end

    test "when wrapper plugin returns error, message is not handled and error is raised" do
      state = build_consumer_state("with_wrapper_plugin")
      message = build_message("error")

      assert_raise Kafkaesque.MessageProcessingError, fn ->
        ConsumerWithPlugins.handle_batch([message], state)
      end

      assert [:wrapper_after_plugin_error, :handled, :wrapper_before_plugin_error] == Process.get(:store)
    end
  end

  describe "multiple plugins" do
    setup do
      Process.put(:store, [])
      :ok
    end

    test "plugins are called in order they are defined" do
      state = build_consumer_state("many_plugins")
      message = build_message("success")

      :ok = ConsumerWithPlugins.handle_batch([message], state)

      assert [:wrapper_after_plugin_success, :handled, :wrapper_before_plugin_success, :before_plugin_success] ==
               Process.get(:store)
    end
  end

  defp build_consumer_state(topic) do
    Kafkaesque.TestCase.build_consumer_state(%{
      consumer: ConsumerWithPlugins,
      supervisor: Kafkaesque.Support.Plugins.Supervisor,
      topic: topic,
      partition: 0
    })
  end

  defp build_message(value) do
    %KafkaEx.Protocol.Fetch.Message{
      topic: "with_before_plugin",
      key: "key",
      value: value,
      offset: 0,
      partition: 0,
      headers: [],
      timestamp: 0
    }
  end
end
