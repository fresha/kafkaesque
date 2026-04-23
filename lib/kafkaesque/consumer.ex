# credo:disable-for-this-file Credo.Check.Refactor.LongQuoteBlocks
defmodule Kafkaesque.Consumer do
  @moduledoc """
  A behaviour module for implementing a Kafka consumer and processing the messages.
  It implements KafkaEx.GenConsumer behaviour.

  Its purpose is to abstract common Kafka consumer interaction and boilerplate
  and allow users to only focus on business logic.

  By default this behaviour processes message sets coming from a given Kafka
  topic and partition. Messages are handled one by one, though this mechanism
  can be overridden by implementing `c:handle_batch/2` callback.

  Most commonly, modules that process one message at a time must only implement
  a callback providing the business logic to run on each decoded value:
  `c:handle_decoded_message/1`.

  A `Kafkaesque.Consumer` must be configured with the following options:
    - `consumer_group_identifier`: an atom uniquely identifying the consumer group
      (excluding the kafka prefix).

    - `commit_strategy`: `sync` or `async`, the mechanism for committing offsets.
      If `sync`, then offsets will be committed at the end of each message set that
      is processed; if `async`, then offsets are committed periodically (or when the
      worker terminates). This is controlled by two configuration settings -
      `:commit_interval` and `:commit_threshold`, which can be specified in `:kafka_ex` config.

    # DEPRECATED
    - `decoders`: a map of topic => %{decoder: decoder_module, opts: Keyword.t()}
      For each topic, the user may specify a map representing the module to use when
      decoding a message and a list of options to be passed on to the function.
      `Kafkaesque` library provides a list of predefined decoders which can be used,
      see `Kafkaesque.Decoders.*`

    -  `topics_config`: a map of topic => %{decoder_config: {module, opts}, handle_message_plugins: [module]}
      For each topic, the user may specify a map representing the module to use when
      decoding a message and a list of options to be passed on to the function.
      `Kafkaesque` library provides a list of predefined decoders which can be used,
      see `Kafkaesque.Decoders.*`
      Additionally, the user may specify a list of modules to be used as plugins
      for the `handle_decoded_message` callback. These plugins are invoked in the
      order they are specified.

    - `retries`: positive integer, the maximum number of times to re-call
      `handle_decoded_message/1`. Set it to 0 to disable retries.

  The following optional settings may be added to enable message processing retry:
    - `initial_backoff`: milliseconds; we use an exponential backoff in between retries,
      starting from this value; by default 100ms, but users may customize it.

  `Kafkaesque.Consumer` emits the telemetry events defined in `Kafkaesque.Consumer.Telemetry`.

  Example:
  ```elixir
  use Kafkaesque.Consumer,
    commit_strategy: :async,
    # Deprecated in favour of topics_config
    decoders: %{
      "appointment_events" => %{decoder: DomainEventDecoder, opts: [schema: AppointmentEventEnvelope]},
      "debezium_row" => %{decoder: DebeziumRowDecoder, opts: []},
      "dummy_events" => %{decoder: nil}
    },
    # New config
    topics_config: %{
      "appointment_events" => %{
         decoder_config: {DomainEventDecoder, [schema: AppointmentEventEnvelope]},
         dead_letter_producer: {KafkaTopicProducer, [topic: "dead_letter_queue", worker_name: :my_worker]},
         handle_message_plugins: []
      },
      "commands" => %{decoder: {DebeziumProtoDecoder, []}},
      "dummy_events" => %{decoder: nil}
    },
    consumer_group_identifier: "my_consumer",
    retries: 0,
    # optional, if not set the following values will be used:
    initial_backoff: 100

  @impl true
  def handle_decoded_message(message_value) do
    # business logic here
    :ok
  end
  """
  alias KafkaEx.Protocol.Fetch.Message

  @type message_value :: any

  @doc """
  Callback function for message batch processing, invoked by `handle_message_set/2`.

  Useful to override when messages are processed in parallel, instead of
  one at a time. The default implementation iterates over each message and invokes
  `handle_message/2`.
  """
  @callback handle_batch([Message.t()], state :: term) :: :ok | {:error, any} | no_return

  @doc """
  Callback function for a single message handling. Invoked by `handle_batch/2`.

  The default implementation provides the following steps:
    - first decode the message using the provided decoder / schema for the topic;
    - if the decoding is successful, follow through with the actual message processing;
    - otherwise we handle the error, see `handle_error/3`;

  If `retry` parameter is configured it will retry a message specified number of times in case of
    - exception being raised ex. Postgrex errors
    - error return from `handle_decoded_message` implementation that is not `:ok` or `{:ok, any}`
  """
  @callback handle_message(Message.t(), state :: term) :: :ok | {:error, any} | no_return

  @doc """
  This callback is where the business logic resides.
  Must be implemented by all modules that use this behaviour.
  """
  @callback handle_decoded_message(message_value :: message_value) ::
              :ok | {:ok, any} | {:error, any} | no_return

  @doc """
  Callback function for handling a message processing failure.
  Invoked by `handle_message/2`

  By default it just logs the reason of failure. If the dead letter queue is configured,
  the failed message is sent to the specified topic.
  Custom implementations may run dedicated business logic in case of error.
  """
  @callback handle_error(
              {kind :: :error | :exit | :throw, reason :: any, stacktrace :: Exception.stacktrace() | nil},
              message :: Message.t(),
              state :: term
            ) :: :ok | {:ok, :dead_letter_queue, any} | no_return

  defmacro __using__(opts) do
    quote generated: true do
      require Logger

      @behaviour Kafkaesque.Consumer

      use KafkaEx.GenConsumer
      import Kafkaesque.Consumer.Telemetry

      alias Kafkaesque.Consumer.PluginHandler
      alias Kafkaesque.Consumer.State

      @config Kafkaesque.Consumer.Config.build(unquote(opts))
      # -------------------------------------------------------------------------------
      # KafkaEx.GenConsumer callbacks
      @impl KafkaEx.GenConsumer
      def init(topic, partition, extra_args) do
        state = State.init(topic, partition, @config, extra_args)
        emit_worker_connection(state.metadata)

        {:ok, state}
      end

      @impl KafkaEx.GenConsumer
      def handle_message_set(message_set, %State{} = state) do
        monotonic_time = current_monotonic_time()

        try do
          emit_consumer_batch_start(monotonic_time, message_set, state)
          result = handle_batch(message_set, state)
          emit_consumer_batch_stop(monotonic_time, message_set, state)
          result
        rescue
          error ->
            emit_consumer_batch_exception(monotonic_time, message_set, state, error, __STACKTRACE__)
            reraise error, __STACKTRACE__
        end

        {commit_strategy_atom(state.commit_strategy), state}
      end

      # -------------------------------------------------------------------------------
      # Kafkaesque.Consumer callbacks
      @impl Kafkaesque.Consumer
      def handle_batch(message_set, %State{} = state) do
        Enum.each(message_set, fn message ->
          delete_message_context()
          init_message_context()
          updated_state = update_metadata(state, message)
          result = handle_message_with_telemetry(message, %State{updated_state | start_time: current_monotonic_time()})

          unless sanitize_result(result) == :ok do
            raise Kafkaesque.MessageProcessingError, description: result
          end
        end)
      end

      defp handle_message_with_telemetry(message, state) do
        message
        |> tap(&emit_consume_start(&1, state))
        |> handle_message_with_plugins(state)
        |> tap(&emit_consume_stop(&1, state))
      catch
        kind, reason ->
          stacktrace = __STACKTRACE__
          normalized_kind = normalize_error_kind(kind)

          result = handle_error({normalized_kind, reason, stacktrace}, message, state)
          emit_consume_exception(state, %{kind: normalized_kind, reason: reason, stacktrace: stacktrace})

          if sanitize_result(result) == :ok do
            result
          else
            :erlang.raise(kind, reason, stacktrace)
          end
      end

      defp handle_message_with_plugins(message, state) do
        plugins = state.handle_message_plugins
        PluginHandler.apply_plugins(plugins, message, state, &handle_message/2)
      end

      @impl Kafkaesque.Consumer
      def handle_message(message, state) do
        message
        |> decode_message(state)
        |> handle_message_with_retries(state)
        |> maybe_handle_error(message, state)
      end

      @impl Kafkaesque.Consumer
      def handle_error({:error, reason}, message, state) do
        handle_error({:error, reason, nil}, message, state)
      end

      @impl Kafkaesque.Consumer
      def handle_error({kind, reason, stacktrace}, message, state) do
        metadata = Map.to_list(state.metadata)
        Logger.error("Message processing failed", metadata ++ [crash_reason: {kind, stacktrace}])

        case state.dead_letter_producer do
          {module, opts} ->
            opts_with_error = Keyword.put(opts, :error, {kind, reason, stacktrace})
            :ok = module.send_to_dead_letter_queue(message, state, opts_with_error)
            {:ok, :dead_letter_queue, reason}

          _ ->
            {:error, reason}
        end
      end

      # ---------------------------------------------------------------------------
      defp commit_strategy_atom(:sync), do: :sync_commit
      defp commit_strategy_atom(:async), do: :async_commit

      # ---------------------------------------------------------------------------
      defp decode_message(message, state) do
        decoder_module = Map.fetch!(state.decoder_config, :decoder)
        decoder_opts = Map.get(state.decoder_config, :opts, [])
        decoder_opts = Keyword.put(decoder_opts, :message_key, message.key)

        if decoder_module do
          decoder_module.decode!(message.value, decoder_opts)
        else
          {:ok, message.value}
        end
      end

      # ---------------------------------------------------------------------------
      defp handle_message_with_retries({:error, :tombstone}, _), do: :ok

      defp handle_message_with_retries({:ok, decoded_message}, state),
        do: handle_message_with_retries(decoded_message, state.max_retries, state.initial_backoff, state)

      defp handle_message_with_retries(decoded_message, 0, _backoff, state) do
        case handle_decoded_message(decoded_message) do
          :ok -> :ok
          {:ok, _any} -> :ok
          result -> result
        end
      end

      defp handle_message_with_retries(decoded_message, retries, backoff, state) do
        case handle_decoded_message(decoded_message) do
          :ok ->
            :ok

          {:ok, _any} ->
            :ok

          {:error, error} ->
            Logger.warning("Message handling failed with error: #{inspect(error)}. Retrying... ")
            emit_consume_retry(state, retries, state.max_retries)

            :timer.sleep(backoff)
            handle_message_with_retries(decoded_message, retries - 1, 2 * backoff, state)
        end
      rescue
        exception ->
          Logger.warning("Message handling failed with exception: #{inspect(exception)}. Retrying... ")
          emit_consume_retry(state, retries, state.max_retries)

          :timer.sleep(backoff)
          handle_message_with_retries(decoded_message, retries - 1, 2 * backoff, state)
      end

      # -------------------------------------------------------------
      defp maybe_handle_error(:ok, _message, _state), do: :ok
      defp maybe_handle_error({:error, error}, message, state), do: handle_error({:error, error, nil}, message, state)
      defp maybe_handle_error(result, message, state), do: handle_error(result, message, state)

      # ---------------------------------------------------------------------------
      defp update_metadata(%State{metadata: metadata} = state, %Message{key: message_key, offset: offset}) do
        %State{state | metadata: Map.merge(metadata, %{key: message_key, offset: offset})}
      end

      # ---------------------------------------------------------------------------
      defp sanitize_result({:ok, :dead_letter_queue, error}), do: :ok
      defp sanitize_result(result), do: result

      # ---------------------------------------------------------------------------
      defp normalize_error_kind({:EXIT, _pid}), do: :exit
      defp normalize_error_kind(kind), do: kind

      # ---------------------------------------------------------------------------
      defp init_message_context, do: Process.put(:message_context, %{})
      defp get_message_context, do: Process.get(:message_context)
      defp put_message_context(message_context), do: Process.put(:message_context, message_context)
      defp delete_message_context, do: Process.delete(:message_context)

      defoverridable Kafkaesque.Consumer
    end
  end
end
