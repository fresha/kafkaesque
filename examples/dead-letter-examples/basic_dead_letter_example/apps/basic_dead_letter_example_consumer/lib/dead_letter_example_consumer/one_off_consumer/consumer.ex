defmodule BasicDeadLetterExampleConsumer.OneOffConsumer.Consumer do
  @moduledoc """
  This module will be receiving messages from any topics to which its consumer group is subscribed.
  - Messages will be incoming in batches containing messages from one partition.
  - Basic approach we support in Fresha is to process message after message.
  """
  use Kafkaesque.OneOffConsumer,
    consumer_group_identifier: "basic_dead_letter_example.ping_events.dead_letter_group",
    topics: ["basic-dead-letter-example.ping-events.dead-letter"],
    decoders: %{
      "basic-dead-letter-example.ping-events.dead-letter" => %{decoder: nil, opts: []}
    },
    max_idle_time: 5

  def run do
    # :earliest | :latest
    run_consumer(:earliest)
  end

  def handle_decoded_message(message) do
    BasicDeadLetterExampleCore.ping("hello: #{message}")
  end
end
