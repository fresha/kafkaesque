defmodule Kafkaesque.ProducerConfigTest do
  use ExUnit.Case, async: false

  alias Kafkaesque.ProducerConfig

  describe "build_config/1" do
    test "returns default consumer config list" do
      expected_config = [
        server_impl: KafkaEx.New.Client,
        consumer_group: :no_consumer_group,
        uris: [{"broker1", 9200}, {"broker2", 9200}, {"broker3", 9200}]
      ]

      assert expected_config == ProducerConfig.build_config()
    end
  end
end
