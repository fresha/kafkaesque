defmodule Kafkaesque.ConfigTest do
  use ExUnit.Case, async: false

  setup do
    kafka_prefix = Application.get_env(:kafkaesque, :kafka_prefix)
    kafka_uris = Application.get_env(:kafkaesque, :kafka_uris)
    healthchecks_enabled = Application.get_env(:kafkaesque, :healthchecks_enabled)

    Application.put_env(:kafkaesque, :consumer_opts, wait_time: 500, max_bytes: 1_000_000)

    on_exit(fn ->
      Application.put_env(:kafkaesque, :kafka_prefix, kafka_prefix)
      Application.put_env(:kafkaesque, :kafka_uris, kafka_uris)
      Application.put_env(:kafkaesque, :healthchecks_enabled, healthchecks_enabled)
      Application.delete_env(:kafkaesque, :healthchecks_warmup_time_in_seconds)
    end)

    :ok
  end

  describe "get/1" do
    test "Get config" do
      Application.put_env(:kafkaesque, :kafka_prefix, "dummy")
      Application.put_env(:kafkaesque, :kafka_uris, "broker1,broker2,broker3")

      assert Kafkaesque.Config.get(:kafka_prefix) == "dummy"
      assert Kafkaesque.Config.get(:kafka_uris) == "broker1,broker2,broker3"

      consumer_opts = Kafkaesque.Config.get(:consumer_opts)
      assert Keyword.get(consumer_opts, :wait_time) == 500
      assert Keyword.get(consumer_opts, :max_bytes) == 1_000_000
    end

    test "Get config - consumer opts" do
      Application.put_env(:kafkaesque, :kafka_prefix, "dummy")
      Application.put_env(:kafkaesque, :kafka_uris, "broker1,broker2,broker3")
      Application.put_env(:kafkaesque, :consumer_opts, wait_time: 1000, max_bytes: 5_000)

      consumer_opts = Kafkaesque.Config.get(:consumer_opts)
      assert Keyword.get(consumer_opts, :wait_time) == 1000
      assert Keyword.get(consumer_opts, :max_bytes) == 5_000
    end

    test "Kafka endpoints" do
      Application.put_env(:kafkaesque, :kafka_uris, "broker1:9200,broker2:9200,broker3:9200")
      expected_endpoints = [{"broker1", 9200}, {"broker2", 9200}, {"broker3", 9200}]

      assert expected_endpoints == Kafkaesque.Config.kafka_endpoints()
    end

    test "Kafka prefix" do
      Application.put_env(:kafkaesque, :kafka_prefix, "dummy")

      assert "dummy.events" == Kafkaesque.Config.kafka_prefix_prepend("events")
      assert "events" == Kafkaesque.Config.topic_identifier("dummy.events")
    end

    test "raises error when config is invalid" do
      Application.delete_env(:kafkaesque, :kafka_prefix)
      Application.delete_env(:kafkaesque, :kafka_uris)

      assert_raise(ArgumentError, fn ->
        Kafkaesque.Config.get(:kafka_uris)
      end)
    end

    test "healthchecks_enabled integer - 0" do
      Application.put_env(:kafkaesque, :healthchecks_enabled, "0")

      assert Kafkaesque.Config.healthchecks_enabled?() == false
    end

    test "healthchecks_enabled integer - 1" do
      Application.put_env(:kafkaesque, :healthchecks_enabled, "1")

      assert Kafkaesque.Config.healthchecks_enabled?() == true
    end

    test "healthchecks_enabled system variable" do
      System.put_env("HEALTHCHECKS_ENABLED", "1")

      Application.put_env(:kafkaesque, :healthchecks_enabled, {:system, "HEALTHCHECKS_ENABLED"})

      assert Kafkaesque.Config.healthchecks_enabled?() == true
    end

    test "healthchecks_warmup_time_in_seconds default value" do
      assert Kafkaesque.Config.get(:healthchecks_warmup_time_in_seconds) == 0
    end

    test "healthchecks_warmup_time_in_seconds set value" do
      Application.put_env(:kafkaesque, :healthchecks_warmup_time_in_seconds, 100)

      assert Kafkaesque.Config.get(:healthchecks_warmup_time_in_seconds) == 100
    end
  end
end
