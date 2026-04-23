defmodule Kafkaesque.ConsumerSupervisor do
  @moduledoc """
  Top level supervisor for spinning up and supervising the consumer group subscribed to
  one or more topics.

  The following options are required:
  - consumer_group_identifier - a unique identifier for the consumer group, excluding the Kafka prefix;
  - topics - a list of topics to subscribe to;
  - message_handler - a module that implements the Kafkaesque.Consumer behaviour.
  - dead_letter_queue - the topic to use for dead letter messages; if set to `nil`, then the support for DLQ
    will be disabled and the failed messages will raise errors, otherwise they will be sent to the specified topic
    and the processing will continue without blocking the message consumption.

  Additionally, one may specify:
  - consumer_opts - a list of options to pass to the KafkaEx.ConsumerGroup.start_link/4 function.
    For the full list of options, see https://hexdocs.pm/kafka_ex_tc/KafkaEx.ConsumerGroup.html#t:option/0.

  Example:

  ```elixir
  defmodule MyProject.ConsumerSupervisor do
    use Kafkaesque.ConsumerSupervisor,
      consumer_group_identifier: "my_consumer_group",
      topics: [ "topic1", "topic2", "topic3" ],
      message_handler: MyProject.MessagesHandler,
      consumer_opts: [
        {:commit_interval, 10_000},
        {:max_bytes, 1_000_000},
        {:session_timeout, 20_000},
        {:wait_time, 500},
        {:extra_consumer_args, %{message: "hello world"}}
      ],
      dead_letter_queue: "my_consumer_group.dead_letter"
  end
  ```
  """

  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts], generated: true do
      require Logger

      use Supervisor

      @consumer_group_identifier Keyword.fetch!(opts, :consumer_group_identifier)
      @consumer_opts Keyword.get(opts, :consumer_opts, [])
      @topics Keyword.fetch!(opts, :topics)
      @message_handler Keyword.fetch!(opts, :message_handler)
      @dead_letter_queue Keyword.fetch!(opts, :dead_letter_queue)

      @spec start_link(_args :: any) :: {:ok, pid} | {:error, any}
      def start_link(_args) do
        Supervisor.start_link(__MODULE__, [], name: __MODULE__)
      end

      # -------------------------------------------------------------------------------
      @impl true
      def init([]) do
        healthchecks_enabled = Kafkaesque.Config.healthchecks_enabled?()
        opts = [strategy: :one_for_one, name: __MODULE__]

        [consumer_group_worker_spec()]
        |> append_dead_letter_queue_sup(@dead_letter_queue)
        |> append_healthcheck_srv(healthchecks_enabled)
        |> Supervisor.init(opts)
        |> tap(&emit_supervisor_connection/1)
      end

      # -------------------------------------------------------------------------------
      # Attributes getters
      @spec message_handler() :: module()
      def message_handler, do: @message_handler

      @spec dead_letter_queue() :: String.t() | nil
      def dead_letter_queue, do: @dead_letter_queue

      @spec consumer_group_identifier() :: String.t()
      def consumer_group_identifier, do: @consumer_group_identifier

      @spec dead_letter_queue_worker() :: atom() | nil
      def dead_letter_queue_worker do
        if @dead_letter_queue do
          String.to_atom("#{__MODULE__}.dead_letter_queue_worker")
        end
      end

      # -------------------------------------------------------------------------------
      defp consumer_group_worker_spec do
        consumer_opts = merge_consumer_opts()
        consumer_group_name = Kafkaesque.Config.kafka_prefix_prepend(@consumer_group_identifier)
        consumer_group_config = Kafkaesque.ConsumerConfig.build_config(@consumer_group_identifier, consumer_opts)

        %{
          id: KafkaEx.ConsumerGroup,
          start:
            {KafkaEx.ConsumerGroup, :start_link,
             [@message_handler, consumer_group_name, topics(), consumer_group_config]}
        }
      end

      # -------------------------------------------------------------------------------
      defp append_healthcheck_srv(children, true) do
        [
          %{
            id: Kafkaesque.ConsumerHealthServer,
            start: {Kafkaesque.ConsumerHealthServer, :start_link, [@consumer_group_identifier, topics()]}
          }
          | children
        ]
      end

      defp append_healthcheck_srv(children, _), do: children

      # -------------------------------------------------------------------------------
      defp append_dead_letter_queue_sup(children, nil), do: children

      defp append_dead_letter_queue_sup(children, _) do
        [
          %{
            id: Kafkaesque.DeadLetterQueue.Supervisor,
            start: {Kafkaesque.ProducerSupervisor, :start_link, [__MODULE__, [dead_letter_queue_worker()]]}
          }
          | children
        ]
      end

      # -------------------------------------------------------------------------------
      defp topics do
        Enum.map(@topics, &Kafkaesque.Config.kafka_prefix_prepend(&1))
      end

      # -------------------------------------------------------------------------------
      defp emit_supervisor_connection(_) do
        consumer_group = Kafkaesque.Config.kafka_prefix_prepend(@consumer_group_identifier)
        dead_letter_queue_tag = if @dead_letter_queue, do: "present", else: "absent"

        :telemetry.execute(
          [:kafkaesque, :consumer_supervisor, :connection],
          %{count: 1},
          %{
            name: __MODULE__,
            consumer_group_identifier: @consumer_group_identifier,
            consumer_group: consumer_group,
            dead_letter_queue_presence: dead_letter_queue_tag
          }
        )
      end

      defp env_consumer_opts do
        Application.get_env(:kafkaesque, :consumer_opts, [])
      end

      defp merge_consumer_opts do
        @consumer_opts
        |> Keyword.merge(
          dead_letter_queue: @dead_letter_queue,
          dead_letter_queue_worker: dead_letter_queue_worker()
        )
        |> Keyword.merge(env_consumer_opts())
      end
    end
  end
end
