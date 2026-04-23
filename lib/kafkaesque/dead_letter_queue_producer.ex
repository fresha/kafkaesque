defmodule Kafkaesque.DeadLetterQueueProducer do
  @moduledoc """
  Module that handles the producing of failed messages to the dead letter queue.
  """
  alias Kafkaesque.DeadLetterQueue.KafkaTopicProducer

  @typep worker_name :: atom() | pid()
  @typep dead_letter_queue_topic :: String.t()
  @typep message :: KafkaEx.Protocol.Fetch.Message.t()
  @typep metadata :: Kafkaesque.ConsumerMetadata.t()

  @doc """
  Produce the given message to the dead letter queue
  """
  @deprecated "Use Kafkaesque.DeadLetterQueue.KafkaTopicProducer.send_to_dead_letter_queue/3 instead"
  @spec send_to_dead_letter_queue(worker_name, dead_letter_queue_topic, message, metadata) :: :ok | no_return
  def send_to_dead_letter_queue(dead_letter_queue_worker, dead_letter_queue, message, metadata) do
    mimic_state = %Kafkaesque.Consumer.State{metadata: metadata}

    opts = [
      worker_name: dead_letter_queue_worker,
      dead_letter_topic: dead_letter_queue
    ]

    KafkaTopicProducer.send_to_dead_letter_queue(message, mimic_state, opts)
  end
end
