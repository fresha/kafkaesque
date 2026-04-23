defmodule Kafkaesque.Behaviours.DeadLetterProducer do
  @moduledoc """
  Behaviour for all dead letter plugins

  Dead Letters are specific plugins that are used to handle messages that fail to process
  through the main consumer group. The dead letter plugin is responsible for sending the
  message to a dead letter.

  # ADR 1
  We've decided to use dead letter plugin as separated behaviour, as they are critically different
  from the other plugins and we want to keep them separated.

  # ADR 2
  Default Telemetry events for dead letter plugins are defined in `Kafkaesque.DeadLetterQueue.Telemetry`
  end they are designed for Kafka DLQ producer.
  """

  @type message :: KafkaEx.Protocol.Fetch.Message.t()
  @type state :: Kafkaesque.Consumer.State.t()

  @type plugin_opts :: Keyword.t()

  @typep success :: :ok | {:ok, :dead_letter_queue, any}
  @typep error :: {:error, any}

  @doc """
  The callback for validating the plugin options.
  This is called on application compilation, and should be used to validate the options passed to the plugin.
  """
  @callback validate_opts!(plugin_opts) :: :ok | no_return

  @doc """
  The callback for processing each message.
  Should return:
  - :ok | {:ok, :dead_letter_queue, any} - if the message is processed successfully
  - any_other - if the message processing fails
  """
  @callback send_to_dead_letter_queue(message, state, plugin_opts) :: success | error | no_return
end
