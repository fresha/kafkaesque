# Upgrading to Kafkaesque 4.x

This guide covers all breaking changes when upgrading from Kafkaesque 3.x to 4.x and the steps needed to migrate your application.

## Prerequisites

### Elixir 1.18+

Although Kafkaesque's `mix.exs` declares `elixir: "~> 1.16"`, the upstream `grpc` v0.11 (and its `googleapis` dependency) pulled in via `monitor` 2.x effectively requires Elixir 1.18 or later. If you are on an older version, `mix deps.get` will fail on transitive dependency resolution. Update your Elixir version before bumping Kafkaesque.

### Monitor 2.x

The `monitor` dependency was bumped from `~> 1.0.0` to `~> 2.0.0`. The internal fork of `grpc` that was previously bundled via `monitor` has been replaced with upstream `grpc` v0.11. If your app depends on `monitor`, update it to `~> 2.0.0` as well.

## Breaking changes

### 1. `decoders` option replaced by `topics_config`

The `decoders` option was deprecated in 3.2.0. While Kafkaesque 4.x still accepts `decoders` and converts it internally, the legacy format now **requires an `opts` key** on every entry. The recommended path is to switch to `topics_config` entirely.

```diff
  use Kafkaesque.Consumer,
    commit_strategy: :async,
    consumer_group_identifier: "my_consumer",
    retries: 3,
-   decoders: %{
-     "appointment_events" => %{
-       decoder: DomainEventDecoder
-     },
-     "cdc_rows" => %{
-       decoder: Kafkaesque.Decoders.DebeziumTableDecoder
-     }
-   }
+   topics_config: %{
+     "appointment_events" => %{
+       decoder_config: {DomainEventDecoder, []},
+       handle_message_plugins: [],
+       dead_letter_producer: nil
+     },
+     "cdc_rows" => %{
+       decoder_config: {Kafkaesque.Decoders.DebeziumTableDecoder, []},
+       handle_message_plugins: [],
+       dead_letter_producer: nil
+     }
+   }
```

Key differences:
- `decoder:` + `opts:` becomes `decoder_config: {module, opts}` (a tuple).
- `handle_message_plugins` defaults to `[]` and `dead_letter_producer` defaults to `nil` if omitted. A minimal entry only needs `decoder_config`.
- You cannot pass both `decoders` and `topics_config` — the consumer will raise at compile time.

### 2. Legacy `decoders` entries require `opts`

If you stick with the legacy `decoders` map, every entry **must** include an `opts` key. Entries that previously omitted it will crash at startup because the internal conversion pattern-matches on `%{decoder: decoder, opts: opts}`.

```diff
  decoders: %{
    "shedul.public.services" => %{
-     decoder: Kafkaesque.Decoders.DebeziumTableDecoder
+     decoder: Kafkaesque.Decoders.DebeziumTableDecoder,
+     opts: []
    }
  }
```

This applies to **all** decoder entries, not just `DebeziumTableDecoder`.

### 3. `produce/4` replaced with `produce_messages/3`

`Kafkaesque.Producer.produce/4` and `produce_batch/4` are deprecated. They still work in 4.x but emit compiler warnings. Replace them with `produce_messages/3`:

```diff
- Kafkaesque.Producer.produce(worker, topic, key, value)
+ Kafkaesque.Producer.produce_messages(worker, topic, [%{key: key, value: value}])
```

For batches:

```diff
- Kafkaesque.Producer.produce_batch(worker, topic, shared_key, [value1, value2])
+ Kafkaesque.Producer.produce_messages(worker, topic, [
+   %{key: shared_key, value: value1},
+   %{key: shared_key, value: value2}
+ ])
```

Each message in the list is a map with `:key`, `:value`, and an optional `:headers` field.

### 4. Dead letter queue: field rename and new tuple format

The consumer state field `dead_letter_queue` (a topic string) has been replaced by `dead_letter_producer` (a `{module, opts}` tuple). The `ConsumerSupervisor` still accepts the `dead_letter_queue` option and builds the tuple internally, so your supervisor definition does not need to change. However, any code that reads the consumer state directly must be updated:

```diff
- state.dead_letter_queue
+ {module, opts} = state.dead_letter_producer
+ dead_letter_topic = Keyword.fetch!(opts, :topic)
```

Per-topic dead letter producers can now be configured in `topics_config`, which takes precedence over the global `dead_letter_queue` from the supervisor:

```elixir
topics_config: %{
  "critical_events" => %{
    decoder_config: {MyDecoder, []},
    handle_message_plugins: [],
    dead_letter_producer: {Kafkaesque.DeadLetterQueue.KafkaTopicProducer,
                           [topic: "critical_events.dlq", worker_name: :dlq_worker]}
  }
}
```

### 5. Removed modules

The following modules were removed in the 3.x cycle and are not available in 4.x:

| Removed module | Replacement |
|---|---|
| `Kafkaesque.MonitoredProducer` | `Kafkaesque.Producer` (telemetry is built-in) |
| `Kafkaesque.MonitoredConsumer` | `Kafkaesque.Consumer` (telemetry is built-in) |
| `Kafkaesque.Decoders.MonitoredDebeziumTableDecoder` | `Kafkaesque.Decoders.DebeziumTableDecoder` |
| `Kafkaesque.Decoders.MonitoredDebeziumProtoDecoder` | `Kafkaesque.Decoders.DebeziumProtoDecoder` |
| `Kafkaesque.Decoders.MonitoredJDBCProtoDecoder` | Removed entirely |
| `Kafkaesque.Decoders.JDBCProtoDecoder` | Removed entirely |
| `Kafkaesque.Helpers.TracingHelpers` | Use `:telemetry` handlers |

If your app references any of these, remove the references. All producers and consumers now emit telemetry events by default — attach handlers via `:telemetry.attach/4` instead.

### 6. Removed consumer callbacks

| Removed callback | Replacement |
|---|---|
| `handle_metrics/6` | Attach `:telemetry` handlers |
| `handle_exception/6` | Override `handle_error/3` |
| `decode/3` | Configure decoder via `topics_config` / `decoders` |

The current overridable callbacks are:

- `handle_batch/2` — process a full message set
- `handle_message/2` — process a single message (decode + handle)
- `handle_decoded_message/1` — **required**, your business logic
- `handle_error/3` — handle failures, optionally send to DLQ

## Notable additions

### Dead letter producer receives error information (4.1.1)

This is not a breaking change, but worth noting. Since 4.1.1, when a message fails and is sent to the dead letter queue, the error tuple `{kind, reason, stacktrace}` is passed to the dead letter producer via the `:error` option. If you have a custom module implementing `Kafkaesque.Behaviours.DeadLetterProducer`, you can access this:

```elixir
def send_to_dead_letter_queue(message, state, opts) do
  {kind, reason, stacktrace} = Keyword.get(opts, :error, {:error, :unknown, nil})
  # use error info for logging, headers, etc.
end
```

## Updating tests

### Test message structs need `topic`

`KafkaEx.Protocol.Fetch.Message` structs created in tests now need the `topic` field. The dead letter producer uses `message.topic` to set a `source_topic` header.

```diff
  %KafkaEx.Protocol.Fetch.Message{
    key: "1",
    offset: 0,
-   value: encoded_value
+   value: encoded_value,
+   topic: "test.my_topic"
  }
```

If you use `Kafkaesque.TestCase.build_kafka_message/1`, pass the topic there.

### Dead letter mocks

Update mocks to use `produce_messages/3` and the new state shape:

```diff
  def expect_dead_letter_produce(message, state) do
-   expect(Kafkaesque.Producer, :produce, fn _, topic, message_key, message_value ->
-     assert topic == state.dead_letter_queue
-     assert message_key == message.key
-     assert message_value == message.value
+   {_, opts} = state.dead_letter_producer
+   dead_letter_topic = Keyword.fetch!(opts, :topic)
+
+   expect(Kafkaesque.Producer, :produce_messages, fn _, topic, messages ->
+     assert topic == dead_letter_topic
+     assert [%{key: key, value: value}] = messages
+     assert key == message.key
+     assert value == message.value
      :ok
    end)
  end
```

## Migration checklist

1. Ensure Elixir 1.18+ (required by transitive `googleapis` dependency)
2. Update `monitor` to `~> 2.0.0` (if used)
3. Update `kafkaesque` to `~> 4.0` in `mix.exs`
4. Convert `decoders` to `topics_config` in all consumers (or at minimum add `opts: []` to every decoder entry)
5. Replace `produce/4` and `produce_batch/4` calls with `produce_messages/3`
6. Remove references to deleted modules (`Monitored*`, `JDBC*`, `TracingHelpers`)
7. Replace `handle_exception/6` overrides with `handle_error/3`
8. Replace `handle_metrics/6` overrides with telemetry handlers
9. Update test message structs to include `topic` field
10. Update dead letter queue mocks to use `produce_messages/3` and `state.dead_letter_producer`
11. Run `mix compile --warnings-as-errors` to catch remaining deprecation warnings
12. Run your test suite
