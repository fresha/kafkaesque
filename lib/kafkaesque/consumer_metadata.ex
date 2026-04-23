defmodule Kafkaesque.ConsumerMetadata do
  @moduledoc """
  Struct defining the metadata of a consumed message
  """
  alias KafkaEx.Protocol.Fetch.Message

  defstruct [
    :topic,
    :partition,
    :key,
    :offset,
    :consumer_group,
    :consumer_group_identifier
  ]

  @type t :: %__MODULE__{
          topic: String.t(),
          partition: integer,
          key: String.t(),
          offset: integer,
          consumer_group: String.t(),
          consumer_group_identifier: String.t()
        }

  @type initial_metadata :: %__MODULE__{
          topic: String.t(),
          partition: integer,
          consumer_group: String.t(),
          consumer_group_identifier: String.t()
        }

  @spec init_metadata(String.t(), integer(), String.t()) :: initial_metadata()
  def init_metadata(topic, partition, consumer_group_identifier) do
    consumer_group = Kafkaesque.Config.kafka_prefix_prepend(consumer_group_identifier)

    %__MODULE__{
      topic: topic,
      partition: partition,
      consumer_group: consumer_group,
      consumer_group_identifier: consumer_group_identifier
    }
  end

  @spec build(Message.t(), String.t()) :: t()
  def build(%Message{topic: topic, partition: partition, key: key, offset: offset}, consumer_group_identifier) do
    build(topic, partition, key, offset, consumer_group_identifier)
  end

  @spec build(String.t(), integer(), String.t(), integer(), String.t()) :: t()
  def build(topic, partition, key, offset, consumer_group_identifier) do
    consumer_group = Kafkaesque.Config.kafka_prefix_prepend(consumer_group_identifier)

    %__MODULE__{
      topic: topic,
      partition: partition,
      key: key,
      offset: offset,
      consumer_group: consumer_group,
      consumer_group_identifier: consumer_group_identifier
    }
  end
end
