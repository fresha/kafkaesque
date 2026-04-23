defmodule Kafkaesque.OneOffConsumer do
  @moduledoc """
  A behaviour module for implementing a Kafka consumer and processing the messages.

  It inherits Kafkaesque.Consumer capabilities and can be used in tasks as a one-off consumer
  that will reprocess all messages in the topic(s) from the earliest offset and stop after defined idle time.

  See Kafkaesque.Consumer docs for more information about the behaviour and its callbacks.

  `Kafkaesque.OneOffConsumer` must be configured with options:
  - `consumer_group_identifier`: name of the consumer group; (see `Kafkaesque.Consumer` for more information)
  - `topics`: list of subscribed topics in the consumer group;
  - `decoders`: list of decoders for each topic. (see `Kafkaesque.Consumer` for more information)
  - `max_idle_time`: the number of seconds of maximum consumer inactivity before it shuts down

  Additionally you can pass the `auto_offset_reset` parameter to the `run_consumer` function to determine whether
  you want to start consuming messages from the beginning or only new ones. `:earliest` will move the offset to
  the oldest available, `:latest` moves to the most recent. If anything else is specified, the error will simply
  be raised.

  Example:
  ```
  use Kafkaesque.OneOffConsumer,
    consumer_group_identifier: "smser.dlq-retry-task-1",
    topics: ["smser.commands.dead-letter"],
    decoders: %{
      "smser.commands.dead-letter" => %{
        decoder: Kafkaesque.Decoders.MonitoredDebeziumDecoder,
        opts: [schema: Commands.Smser.V1.SmserCommandEnvelope]
      }
    },
    max_idle_time: 60

  def run do
    run_consumer(:earliest)       # :earliest | :latest
  end

  @impl true
  def handle_decoded_message(_message) do
    # business logic here
    :ok
  end

  @impl true
  def handle_error({kind, reason, stacktrace}, message, state) do
    # Place your specific error handling here
    # or just return :ok to ignore errors
    :ok
  end
  ```
  """

  defmacro __using__(opts) do
    quote bind_quoted: [
            opts: opts
          ] do
      module = __MODULE__
      max_idle_time = Keyword.get(opts, :max_idle_time, 20)
      consumer_group_identifier = Keyword.fetch!(opts, :consumer_group_identifier)
      topics = Keyword.fetch!(opts, :topics)
      decoders = Keyword.fetch!(opts, :decoders)
      retries = Keyword.get(opts, :retries, 0)
      initial_backoff = Keyword.get(opts, :initial_backoff)

      require Logger

      defmodule ConsumerSupervisor do
        @moduledoc false

        use Kafkaesque.ConsumerSupervisor,
          consumer_group_identifier: consumer_group_identifier,
          topics: topics,
          message_handler: module,
          dead_letter_queue: nil
      end

      defmodule IdleTimer do
        @moduledoc false

        use Agent

        def start_link(_opts) do
          Agent.start_link(fn -> DateTime.utc_now() end, name: __MODULE__)
        end

        def reset_idle_time do
          Agent.update(__MODULE__, fn _ -> DateTime.utc_now() end)
        end

        def get_idle_time do
          Agent.get(__MODULE__, &DateTime.diff(DateTime.utc_now(), &1, :second))
        end
      end

      use Kafkaesque.Consumer,
        commit_strategy: :sync,
        decoders: decoders,
        consumer_group_identifier: consumer_group_identifier,
        retries: retries,
        initial_backoff: initial_backoff

      @impl Kafkaesque.Consumer
      def handle_batch(message_set, state) do
        :"#{unquote(module)}.IdleTimer".reset_idle_time()
        super(message_set, state)
      end

      defp run_consumer(auto_offset_reset \\ :earliest) do
        Application.put_env(:kafkaesque, :consumer_opts, [{:auto_offset_reset, auto_offset_reset}])

        {:ok, consumer_supervisor_pid} = :"#{unquote(module)}.ConsumerSupervisor".start_link([])
        {:ok, idle_timer_pid} = :"#{unquote(module)}.IdleTimer".start_link([])

        Logger.info("One-off consumer started, consumer_group_identifier: #{unquote(consumer_group_identifier)}")

        wait_for_consumer()

        Logger.info(
          "One-off consumer exceeded idle time, terminating...",
          idle_time: unquote(max_idle_time)
        )

        Supervisor.stop(consumer_supervisor_pid)
        Agent.stop(idle_timer_pid)

        Logger.info("One-off consumer terminated")
      end

      defp wait_for_consumer do
        idle_time = :"#{unquote(module)}.IdleTimer".get_idle_time()

        unless idle_time >= unquote(max_idle_time) do
          Process.sleep(500)
          wait_for_consumer()
        end
      end
    end
  end
end
