defmodule Kafkaesque.ConsumerConfigTest do
  use ExUnit.Case, async: false

  alias Kafkaesque.ConsumerConfig

  describe "build_config/1" do
    test "returns default consumer config list" do
      expected_config = [
        heartbeat_interval: 5_000,
        session_timeout: 20_000,
        session_timeout_padding: 10_000,
        uris: [{"broker1", 9200}, {"broker2", 9200}, {"broker3", 9200}],
        api_versions: %{fetch: 3, offset_fetch: 3, offset_commit: 3},
        auto_offset_reset: :latest,
        commit_interval: 10_000,
        commit_threshold: 100,
        extra_consumer_args: %{
          consumer_group_identifier: "test.consumer",
          dead_letter_queue: nil,
          dead_letter_queue_worker: nil
        },
        fetch_options: [
          {:max_bytes, 1_000_000},
          {:wait_time, 500}
        ]
      ]

      assert expected_config == ConsumerConfig.build_config("test.consumer")
    end

    test "override consumer config" do
      expected_config = [
        heartbeat_interval: 5_000,
        session_timeout: 30_000,
        session_timeout_padding: 10_000,
        uris: [{"broker1", 9200}, {"broker2", 9200}, {"broker3", 9200}],
        api_versions: %{fetch: 3, offset_fetch: 3, offset_commit: 3},
        auto_offset_reset: :latest,
        commit_interval: 15_000,
        commit_threshold: 100,
        extra_consumer_args: %{
          consumer_group_identifier: "test.consumer",
          dead_letter_queue: nil,
          dead_letter_queue_worker: nil
        },
        fetch_options: [
          {:max_bytes, 3_000_000},
          {:wait_time, 1_000}
        ]
      ]

      assert expected_config ==
               ConsumerConfig.build_config("test.consumer", [
                 {:commit_interval, 15_000},
                 {:max_bytes, 3_000_000},
                 {:session_timeout, 30_000},
                 {:wait_time, 1_000}
               ])
    end

    test "when extra consumer args are specified" do
      expected_config = [
        heartbeat_interval: 5_000,
        session_timeout: 30_000,
        session_timeout_padding: 10_000,
        uris: [{"broker1", 9200}, {"broker2", 9200}, {"broker3", 9200}],
        api_versions: %{fetch: 3, offset_fetch: 3, offset_commit: 3},
        auto_offset_reset: :latest,
        commit_interval: 15_000,
        commit_threshold: 100,
        extra_consumer_args: %{
          consumer_group_identifier: "test.consumer",
          dead_letter_queue: nil,
          dead_letter_queue_worker: nil,
          feature_enabled: true
        },
        fetch_options: [
          {:max_bytes, 3_000_000},
          {:wait_time, 1_000}
        ]
      ]

      assert expected_config ==
               ConsumerConfig.build_config("test.consumer", [
                 {:commit_interval, 15_000},
                 {:extra_consumer_args, %{feature_enabled: true}},
                 {:max_bytes, 3_000_000},
                 {:session_timeout, 30_000},
                 {:wait_time, 1_000}
               ])
    end

    test "when dead letter queue is enabled" do
      expected_config = [
        heartbeat_interval: 5_000,
        session_timeout: 30_000,
        session_timeout_padding: 10_000,
        uris: [{"broker1", 9200}, {"broker2", 9200}, {"broker3", 9200}],
        api_versions: %{fetch: 3, offset_fetch: 3, offset_commit: 3},
        auto_offset_reset: :latest,
        commit_interval: 15_000,
        commit_threshold: 100,
        extra_consumer_args: %{
          consumer_group_identifier: "test.consumer",
          dead_letter_queue: "test.consumer.dead_letter",
          dead_letter_queue_worker: "consumer.dead_letter",
          feature_enabled: true
        },
        fetch_options: [
          {:max_bytes, 3_000_000},
          {:wait_time, 1_000}
        ]
      ]

      assert expected_config ==
               ConsumerConfig.build_config("test.consumer", [
                 {:commit_interval, 15_000},
                 {:extra_consumer_args, %{feature_enabled: true}},
                 {:max_bytes, 3_000_000},
                 {:session_timeout, 30_000},
                 {:wait_time, 1_000},
                 {:dead_letter_queue, "test.consumer.dead_letter"},
                 {:dead_letter_queue_worker, "consumer.dead_letter"}
               ])
    end

    test "raises an error if `extra_consumer_args` is not a map" do
      assert_raise ArgumentError, "extra_consumer_args must be a map", fn ->
        ConsumerConfig.build_config("test.consumer", [
          {:extra_consumer_args, 123}
        ])
      end
    end
  end
end
