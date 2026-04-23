defmodule Kafkaesque.ProducerConfig do
  @moduledoc false

  @spec build_config() :: Keyword.t()
  def build_config do
    kafka_endpoint_list = Kafkaesque.Config.kafka_endpoints()

    [
      server_impl: KafkaEx.New.Client,
      consumer_group: :no_consumer_group,
      uris: kafka_endpoint_list
    ]
  end
end
