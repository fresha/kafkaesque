# Kafkaesque

[![Coverage](https://static-pages.external-infrastructure.fresha.io/surgeventures/kafkaesque/badge/coverage.svg)](https://static-pages.external-infrastructure.fresha.io/surgeventures/kafkaesque/report/history.html)

This project plans to abstract the complexity of interacting with Kafka at Fresha and allow engineers to focus on the
business logic instead. It will deal with starting the necessary supervision trees and will provide APIs for producing,
consuming and processing messages.

### Why not Broadway?

We use Kafkaesque as a wrapper on top of `kafka_ex`, which is a Kafka client, the same as [Broadway](https://elixir-broadway.org/).
We extend its capabilities with some additional functions, such as topic prefixes, monitoring, tracing, decoding, health checks, error handling, etc.
We've chose `kafka_ex` as its purely elixir, and provides the full implementation of the Kafka API, which `brodway` has not.

We can add `Broadway` support to `Kafkaesque`, but they are different things. `Broadway` is a client for Kafka with steroids for concurrency control,
or rather, a better API. `Kafkaesque` is a tool on top of this client to add stuff that typical clients do not support.

## Installation

The package can be installed by adding `kafkaesque` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:kafkaesque, "~> 3.2"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/kafkaesque](https://hexdocs.pm/kafkaesque).

The following config is expected for `:kafkaesque` and `:kafka_ex` deps:

```elixir
### kafkaesque
config :kafkaesque,
  kafka_prefix: "<string>",
  kafka_uris: "<string>",
  healthchecks_enabled: true | false
  healthchecks_warmup_time_in_seconds: 10,
  monitor_trace_context: Monitor.Tracer.SpandexTraceContext

### kafka_ex
config :kafka_ex,
  kafka_version: "kayrock",
  api_versions: %{fetch: 5, offset_fetch: 3, offset_commit: 3},
  disable_default_worker: true,
  use_ssl: true | false # depends on the env, false for local dev, true otherwise
```

### Migrating from 0.x.x

Kafkaesque 1.x.x brings a few improvements to consumer groups, which unfortunately are not compatible with the 0.x.x api. You can find a migration guide on [Notion](https://www.notion.so/fresha-app/How-To-Migrate-to-Kafkaesque-v1-x-x-5b602ae42c18443cab04191ea80b9193).

## Consumers

They are responsible for wrapping consumer groups implementation and consuming messages incoming from Kafka.

To subscribe to some topics first create a new ConsumerSupervisor module:

```elixir
defmodule Myapp.ConsumerSupervisor do
  @moduledoc false

  use Kafkaesque.ConsumerSupervisor,
    consumer_group_identifier: Application.compile_env!(:myapp, :consumer_group_identifier),
    topics: Application.compile_env!(:myapp, :subscribed_topics),
    message_handler: MyApp.MessagesHandler,
    dead_letter_queue: Application.compile_env!(:myapp, :dead_letter_queue)
end
```

where:

- `consumer_group_identifier` - **required**, a unique identifier of the consumer group, excluding the Kafkaprefix
- `topics` - **required**, the list of topics to which this consumer group should be subscribed to
- `message_handler` - **required**, the message handler module

Then add this new supervisor to your app's supervision tree

```elixir
defp kafka_consumer(children, true) do
  [Myapp.ConsumerSupervisor | children]
end
```

Starting from Kafkaesque 2.0.0, one may specify `consumer_opts` - a list of key - value configuration options
which will be used when starting the consumer group and worker, respectively. This enables us to have different
supervisors into a single runtime, each with their own configuration.

```elixir
  use Kafkaesque.ConsumerSupervisor,
    consumer_group_identifier: Application.compile_env!(:myapp, :consumer_group_identifier),
    consumer_opts: [
      {:commit_interval, 5_000},
      {:max_bytes, 1_000_000},
      {:session_timeout, 30_000},
      {:wait_time, 500},
      {:extra_consumer_args, %{extra_arg: "hello, world!"}}
    ],
    topics: Application.compile_env!(:myapp, :subscribed_topics),
    message_handler: MyApp.MessagesHandler
```

### Messages Consumer (formerly Messages Handler)

Messages Consumer is a module which will be receiving messages form any topics to which its consumer group is subscribed to
and will decode them before returning to the client. Messages will be incoming in batches containing messages from one partition.

```elixir
    defmodule Myapp.Consumer do
      use Kafkaesque.Consumer,
        commit_strategy: :async,
        topics_config: %{
          "appointment_events" => %{
            decoder_config: {DebeziumProtoDecoder, [schema: AppointmentEventEnvelope]},
            handle_message_plugins: [
              {MyApp.LoggingPlugin, []},
              {MyApp.MetricsPlugin, []}
            ],
            dead_letter_producer: {KafkaTopicProducer, [topic: "appointment_events.dlq", worker_name: :dlq_worker]}
          },
          "debezium_row" => %{
            decoder_config: {DebeziumTableDecoder, []},
            handle_message_plugins: [],
            dead_letter_producer: nil
          },
          "dummy_events" => %{
            decoder_config: nil,
            handle_message_plugins: [],
            dead_letter_producer: nil
          }
        },
        consumer_group_identifier: Application.compile_env!(:myapp, :consumer_group),
        retries: 0,
        # optional, if not set the following values will be used:
        initial_backoff: 100

      @type raw_message :: %{topic: binary, partition: integer, key: binary, value: binary, timestamp: integer}
      @type message_value :: binary | proto_payload

      # Overridable functions
      @callback handle_batch([Message.t()], state :: term) :: :ok | {:error, any} | no_return

      @callback handle_message(Message.t(), state :: term) :: :ok | {:error, any} | no_return

      @callback handle_decoded_message(message_value :: message_value) :: :ok | {:error, any} | no_return

      @callback handle_error({kind :: :error | :throw | :exit, reason :: any, stacktrace :: Exception.stacktrace() | [] | nil}, message :: Message.t(), state :: term) :: any

      @impl true
      def handle_decoded_message(message_value) do
        # Your business logic here
        :ok
      end
    end
```

### Configuration Options

- `commit_strategy` - by default it will be `:sync` but if higher throughput is needed, it can be changed to `async`
  at the risk of potentially receiving chunks of messages more than once
- `consumer_group_identifier` - the name of the consumer group this consumer is associated with
- `topics_config` - **recommended** configuration format that allows per-topic customization:
  - `decoder_config` - either `nil` (no decoding) or `{DecoderModule, opts}` tuple
  - `handle_message_plugins` - list of `{PluginModule, opts}` tuples for message processing pipeline
  - `dead_letter_producer` - optional `{ProducerModule, opts}` for failed message handling
- `decoders` - **deprecated** (use `topics_config` instead) - map of `topic_name => %{decoder: module, opts: list}`
- `retries`: non-negative integer, the maximum number of times to retry processing a decoded message.
  Warning: Exceptions are not retried. If an exception is raised, then the message will be sent to the dead letter queue
  provided that it is configured, otherwise the consumer will be restarted from the last committed event and try to process messages again.
  If the problem persists the consumer will be retried indefinitely blocking the processing of other events in the partition. This behavior will be fixed in the future.
- `initial_backoff`: milliseconds; we use an exponential backoff in between retries, starting from this value;
  by default 100ms

### Dead letter queues support

Kafkaesque 3.1 introduces support for dead letter queues for messages that fail to be processed.
To enable the feature, the `dead_letter_queue` option must be set when configuring topics in `Kafkaesque.Consumer`.
If set to `nil`, then the DLQ support is disabled, and failed messages will raise errors; otherwise, the messages
will be sent to the specified DLQ topic.

```elixir
defmodule Myapp.Consumer do
  use Kafkaesque.Consumer,
    commit_strategy: :async,
    topics_config: %{
      "appointment_events" => %{
        decoder_config: {DebeziumProtoDecoder, [schema: AppointmentEventEnvelope]},
        dead_letter_producer: {KafkaTopicProducer, [topic: "appointment_events.dlq", worker_name: :dlq_worker]}
      },
    },
    consumer_group_identifier: Application.compile_env!(:myapp, :consumer_group)
end
```

### Plugin System (v3.2.0+)

Kafkaesque now supports a powerful plugin system for fine-grained control over message processing:

```elixir
defmodule MyApp.LoggingPlugin do
  use Kafkaesque.Behaviours.MessageHandlerPlugin

  def handle_message(message, state, opts, next_function) do
    Logger.info("Processing message",
      topic: state.topic,
      partition: state.partition,
      key: message.key
    )

    # Continue processing with original message
    next_function.(message)
  end
end

defmodule MyApp.TransformPlugin do
  use Kafkaesque.Behaviours.MessageHandlerPlugin

  def handle_message(message, _state, opts, next_function) do
    # Transform the message
    transformed_message = %{message |
      value: Jason.decode!(message.value)
    }

    # Continue processing with transformed message
    next_function.(transformed_message)
  end
end
```

Plugins are executed in the order they are specified and can:

- **Intercept** messages for logging, metrics, or side effects
- **Transform** messages by modifying content before processing
- **Short-circuit** processing by not calling `next_function`

### Migration from Legacy Format

If you're using the deprecated `decoders` format, migrate to `topics_config`:

```elixir
# Before (deprecated)
decoders: %{
  "events" => %{decoder: MyDecoder, opts: [schema: Schema]}
}

# After (recommended)
topics_config: %{
  "events" => %{
    decoder_config: {MyDecoder, [schema: Schema]},
    handle_message_plugins: [],
    dead_letter_producer: nil
  }
}
```

### Decoders

Kafkaesque provides several decoders for different message formats. Here are some examples:

- `Kafkaesque.Decoders.ProtoDecoder`: For decoding plain proto events.
- `Kafkaesque.Decoders.CommandDecoder`: Commands decoder.
- `Kafkaesque.Decoders.DebeziumProtoDecoder`: Debezium events decoder.
- `Kafkaesque.Decoders.DebeziumTableDecoder`: Decoder for Debezium CDC events.

You can specify the appropriate decoder for each topic in your consumer configuration.

### Healthcheck

```elixir
    defmodule Myapp.Healthchecks do
      @consumer_group_identifier Application.compile_env!(:myapp, :consumer_group)

      def kafka_consumer_group_available do
        Heartbeats.Helpers.kafka_consumer_check(@consumer_group_identifier)
      end
    end
```

And register this healthcheck on application start

```elixir
    Heartbeats.register_check([
      &Myapp.Healthchecks.kafka_consumer_group_available/0
    ])
```

## One-Off Consumer

A behaviour module for implementing a Kafka consumer and processing the messages.

It inherits Kafkaesque.Consumer capabilities and can be used in tasks as a one-off consumer
that will reprocess all messages in the topic(s) from the earliest offset and stop after defined idle time.

For more info see [the docs](https://fresha.hexdocs.pm/kafkaesque/Kafkaesque.OneOffConsumer.html)

## Producers

Producing messages is normally handled by a process (worker), identified by its name. For example, KafkaEx uses a default
`:kafka_ex` worker, unless otherwise specified. To cater for cases where we plan multiple workers in the same application
(for example different types of producers which are unrelated), we allow the spinning up of multiple such processes under a supervision tree.

The following APIs for producing a message are exposed:

```elixir
Kafkaesque.Producer

# Primary API (recommended)
@spec produce_messages(worker_name :: atom(), topic :: String.t(), [message()]) :: :ok | {:error, error()}
@spec produce_messages(worker_name :: atom(), topic :: String.t(), [message()], options()) :: :ok | {:error, error()}

# Deprecated APIs (use produce_messages/3 instead)
@spec produce(worker_name :: atom(), topic :: String.t(), any(), any()) :: :ok | {:error, error()}
@spec produce(worker_name :: atom(), topic :: String.t(), any(), any(), options()) :: :ok | {:error, error()}

@spec produce_batch(worker_name :: atom(), topic :: String.t(), any(), [any()]) :: :ok | {:error, error()}
@spec produce_batch(worker_name :: atom(), topic :: String.t(), any(), [any()], options()) :: :ok | {:error, error()}

# Where message() is:
@type message :: %{
  required(:key) => any(),
  required(:value) => any(),
  optional(:headers) => list({String.t(), String.t()})
}

# And options() supports:
@type options :: [
  {:timeout, non_neg_integer()}           # Max wait time for acks in ms
  | {:partition, non_neg_integer() | nil} # Specific partition (nil = key-based)
  | {:required_acks, :none | :one | :all} # Acknowledgement level
]
```

Where:

- `worker_name` - the name of the producer worker process
- `topic` - the destination topic (without Kafka prefix)
- `messages` - list of message maps, each containing `:key`, `:value`, and optional `:headers`
- `options` - optional keyword list for producer configuration:
  - `timeout` - milliseconds to wait for acknowledgements (default: 100ms)
  - `partition` - specific partition to send to, or `nil` for key-based routing (default: nil)
  - `required_acks` - acknowledgement level: `:none`, `:one` (leader only), or `:all` (all replicas) (default: `:one`)

Adding producers to an application can be done using:

```elixir
    defmodule MyApplication do
    ...

    def start(_type, _args) do
      children = [
        %{
          id: Kafkaesque.ProducerSupervisor,
          start: {Kafkaesque.ProducerSupervisor, :start_link, [:my_app, [:location_events_producer]]}
        } | other_children
      ]
    end

    ...
  end
```

## Monitoring & Tracing

Kafkaesque has support for monitoring & distributed tracing, please see the
[notion guide](https://www.notion.so/fresha-app/How-To-Setting-up-Distributed-Tracing-4793d000af334ec8bd74531681eb5c72)
on how to set it up.

### Telemetry events

Starting from version 3.0.0, Kafkaesque provides support for telemetry events. These events are emitted when decoding, consuming, or producing messages.
This allows us to decouple Kafkaesque from the `monitor` library, and instead have telemetry handlers that can be attached to start / stop / continue traces
in `monitor` itself.

The following events are emitted:

| **Event**                                          | **Measurements**                        | **Metadata**                                                                                                  |
| -------------------------------------------------- | --------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| `[:kafkaesque, :decode]`                           |                                         |                                                                                                               |
| `[:kafkaesque, :consumer_supervisor, :connection]` | `:count`                                | `:name, :consumer_group_identifier`                                                                           |
| `[:kafkaesque, :consumer_worker, :connection]`     | `:count`                                | `:topic, :partition, :key, :offset, :consumer_group, :consumer_group_identifier`                              |
| `[:kafkaesque, :consume_batch, :start]`            | `:count, :system_time, :monotonic_time` | `:topic, :partition, :consumer_group, :consumer_group_identifier`                                             |
| `[:kafkaesque, :consume_batch, :stop]`             | `:count, :duration :monotonic_time`     | `:topic, :partition, :consumer_group, :consumer_group_identifier`                                             |
| `[:kafkaesque, :consume_batch, :exception]`        | `:count, :duration :monotonic_time`     | `:kind, :reason, :stacktrace, :topic, :partition, :consumer_group, :consumer_group_identifier`                |
| `[:kafkaesque, :consume, :start]`                  | `:count, :monotonic_time`               | `:topic, :partition, :key, :offset, :consumer_group, :consumer_group_identifier`                              |
| `[:kafkaesque, :consume, :stop]`                   | `:count, :monotonic_time, :duration`    | `:topic, :partition, :key, :offset, :consumer_group, :consumer_group_identifier, :error`                      |
| `[:kafkaesque, :consume, :exception]`              | `:count, :monotonic_time, :duration`    | `:topic, :partition, :key, :offset, :consumer_group, :consumer_group_identifier, :kind, :reason, :stacktrace` |
| `[:kafkaesque, :produce, :start]`                  | `:count, :system_type, :monotonic_time` | `:telemetry_span_context, :worker_name, :topic`                                                               |
| `[:kafkaesque, :produce, :stop]`                   | `:count, :monotonic_time, :duration`    | `:error, :telemetry_span_context, :worker_name, :topic`                                                       |
| `[:kafkaesque, :produce, :exception]`              | `:count, :monotonic_time, :duration`    | `:kind, :reason, :stacktrace, :telemetry_span_context, :worker_name, :topic`                                  |
| `[:kafkaesque, :dlq_produce]`                      | `:count, :system_type`                  | `:worker_name, :dlq_topic, :topic, :partition, :key, :offset, :consumer_group`                                |

