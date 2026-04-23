# Change Log

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/)
and this project adheres to [Semantic Versioning](https://semver.org/).

## [4.3.0] - 2026-04-17

### Changed

- Message `id` header now uses UUIDv7 (`Uniq.UUID.uuid7/0`) instead of UUIDv4. Behavioral change: IDs are time-ordered, improving PostgreSQL B-tree index locality downstream. String format and header key are unchanged.

## [4.2.0] - 2026-03-08

### Changed
- Replace `elixir_uuid` dependency with `uniq` — actively maintained and warning-free
- Upgrade `kafka_ex` from 0.14.0 to 0.15.0 — fixes ~10 dependency warnings
- Remove direct `kayrock` dependency — already a transitive dep of `kafka_ex`
- Replace deprecated `Mix.env()` with `config_env()` in config
- Remove stale `rename_deprecated_at` option from `.formatter.exs`
- Add `@impl true` annotations to GenServer callbacks in `ConsumerHealthServer`

## [4.1.1] - 2026-02-05

### Added
- Pass error information (kind, reason, stacktrace) to dead letter producer via `:error` option

## [4.0.0] - 2025-11-11
- Replaced internal fork of `grpc` (included via `monitor`) with upstream (v0.11)
- Minimum supported version of Elixir increased to v1.18

## [3.2.3] - 2025-09-23

### Changed
- `Kafkaesque.OneOffConsumer`
  - Propagates options to `Kafkaesque.Consumer.Config`: `retries`, `initial_backoff`
  - Propagates `auto_offset_reset` to `Kafkaesque.ConsumerConfig` (KafkaEx) via `consumer_opts`

### Added
- Tests for `Kafkaesque.OneOffConsumer` covering option propagation and idle termination

## [3.2.2] - 2025-08-26

### Added
- **Kafkaesque.MessageEncoder**
    - `build_request` - when `id` is not provided, it will be generated as UUID v4.

## [3.2.1] - 2025-07-28

### Fixed
- `Kafkaesque.Consumer` 
    - Fix tracing for plugins that are skipping message processing

## [3.2.0] - 2025-07-21

### Added
- **Kafkaesque.Consumer**
  - Plugin system for fine-grained message processing control
  - Per-message process context storage for tracing
  - `topics_config` option for per-topic behavior configuration

### Deprecated
- **Kafkaesque.Consumer**
  - `decoders` option deprecated in favor of `topics_config`

### Migration Guide
#### Updating from decoders to topics_config
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

## [3.1.5] - 2025-05-20
- `Kafkaesque.Consumer` 
    - Fix dialyzer error

## [3.1.4] - 2025-05-13
- `Kafkaesque.Consumer` 
    - Fix bug where the consumer haven't marked message as error if produced to DLQ

## [3.1.3] - 2025-05-07
- Add `Kafkaesque.TestCase` 
  - Simple module to make writing tests easier. 
    - `build_kafka_message/1` - build a Kafka message from a map of fields
    - `build_consumer_state/1` - build a consumer state from a supervisor, consumer, topic and partition

## [3.1.2] - 2025-04-22
- `Kafkaesque.Consumer`
  - Unify monotonic time to always be in milisecond unit
  - Refactor code to always return monotonic time according to telemetry docs
  - Add telemetry event after retry 
  - Handle exceptions in retry 

## [3.1.1] - 2025-04-01
- `Kafkaesque.Consumer`
  - Add connection telemetry event. 
  - Add consume batch telemetry events for batch processing
- `Kafkaesque.ConsumerSupervisor` 
  - Add connection telemetry event
- `Kafkaesque.Producer`
  - Fix emitting `:telemetry` events to contain proper metadata
- Add `examples` section with dead letter consumer. 

## [3.1.0] - 2025-02-24

### Changed

- `Kafkaesque.Consumer`
  - Add initial support for Dead Letter Queues (DLQ): `Kafkaesque.ConsumerSupervisor` now requires a `dead_letter_queue` option to be specified; if nil, then the DLQ support is disabled and the behavious of
  the consumer group will be the same as before, otherwise the failed messages will be sent to the specified topic
  and processing will continue, without blocking consumption.
  - Remove `handle_exception/6` callback, rely a single callback for handling message processing failures
  - Remove `decode/3` callback, as it was never overridden
  - Make `retries` option mandatory

## [3.0.2] - 2025-02-11

- `Kafkaesque.Consumer` - Ensure that the `monitor_trace_context` is set in kafkaesque config and fail to compile the app otherwise

## [3.0.1] - 2025-01-20

- `Kafkaesque.Consumer` - Fix case where the consumer would fail if a message contained no headers (`headers` field was nil)

## [3.0.0] - 2025-01-15

- Breaking - Emit :telemetry metrics instead of relying directly on `monitor` library for tracing.
Instead, we attach telemetry handlers in the `monitor` library, where we start / continue a trace depending on the received event.

### Changed

- All decoders emit by default `:telemetry` events
- Producers and consumers also emit `:telemetry` events
- Removed `handle_metrics` callback from `Kafkaesque.Consumer`

### Removed

- `Monitored` decoders have been removed, since we now always emit `:telemetry` events
- `Kafkaesque.MonitoredProducer` and `Kafkaesque.MonitoredConsumer` are also deprecated, we now emit `:telemetry` metrics by default, no need to keep these modules any longer.
- JDBC decoder has been deprecated as part of this revamp, since JDBC is deprecated across the board.

## [2.1.0] - 2025-01-14
- Switch back to `kafka_ex` and `kayrock` upstreams

## [2.0.0] - 2024-07-18
- Allow setting configuration options per consumer group

## [1.7.0] - 2024-03-20
- Breaking - DebeziumTableDecoder: `r` operation is now `:read` instead of `:insert`

## [1.6.0] - 2024-03-06
- Breaking - DebeziumTableDecoder: keys in the map under data key are now atoms instead of strings.

### Changed
- Removed Telemetry Metrics StatsD dependency & metrics reporting, as it was moved to `monitor` library

## [1.5.0] - 2023-10-30

### Changed
- Removed Telemetry Metrics StatsD dependency & metrics reporting, as it was moved to `monitor` library

## [1.4.0] - 2023-10-18

### Added

- `Kafkaesque.MonitoredProducer` - producer with monitoring support, see `Kafkaesque.MonitoredProducer` for details
- Update `Kafkaesque.MonitoredConsumer` to use traces incoming from events

## [1.3.5] - 2023-05-17

### Added

- `Kafkaesque.Decoders.MonitoredProtoDecoder` - decoder with monitoring support

## [1.3.4] - 2023-05-16

### Added

- `Kafkaesque.MonitoredDebeziumTableDecoder` - decoder with monitoring support
- `Kafkaesque.Decoders.Structs.DebeziumCDCMessage` - typed struct returned from decoder
- `Kafkaesque.DebeziumTableDecoder` now supports `:timestamp`, `:database` and `:schema` fields

## [1.3.3] - 2023-03-10

### Added

- `Kafkaesque.DebeziumTableDecoder`

## [1.3.2] - 2023-02-09

### Added

- `Kafkaesque.OneOffConsumer`


## [1.3.1] - 2023-02-01

### Fixed

- Fix `MonitoredConsumer.report_error` function clause


## [1.3.0] - 2022-10-31

### Added

- Observability trough `MonitoredConsumer` and `Monitored*Decoder`'s

## [1.2.3] - 2022-10-27

### Fixed

- Issue with duplicated metrics when using more that one Supervisor / Producer

## [1.2.0] - 2022-10-25

:alarm: this version breaks `JDBCProtoDecoder` for topics that produce
events without `uuid` or `timestamp`.

### Changed

- `JDBCProtoDecoder` decodes `uuid` and `timestamp`

## [1.1.0] - 2022-07-29

### Changed

- Report metrics using `distribution` rather than `summary`

## [1.0.1] - 2022-05-12

### Added

- Healthcheck warmup time

## [1.0.0] - 2022-04-20

### Added

- Healthchecks
- Ability to have multiple `Kafkaesque.ConsumerSupervisor`
- Ability to configure consumer trough `consumer_group_identifier`

### Changed

- Moved from `kafka_ex` to `kafka_ex_fresha`
- `handle_metrics` no longer overridable in the `Kafkaesque.Consumer`

### Fixed

- Different consumer group identifier in `Consumer` and `ConsumerSupervisor`
  will now throw an error


## [0.0.5] - 2022-02-17

### Fixed

- Timestamps precision in `Kafkauesque.Producer`

## [0.0.4] - 2021-11-25

### Added

- `PlainProto` decoder

## [0.0.3] - 2021-10-29

### Fixed

- Debezium decoder timestamp precision issue

## [0.0.2] - 2021-09-06

### Fixed

- Suppress dialyzer error

## [0.0.1] - 2021-08-24

### Added
- Initial version


<!-- links -->
[Unreleased]: https://github.com/surgeventures/kafkaesque/compare/v1.3.2...HEAD
[1.3.2]: https://github.com/surgeventures/kafkaesque/compare/v1.3.1...v1.3.2
[1.3.1]: https://github.com/surgeventures/kafkaesque/compare/v1.3.0...v1.3.1
[1.3.0]: https://github.com/surgeventures/kafkaesque/compare/v1.2.3...v1.3.0
[1.2.3]: https://github.com/surgeventures/kafkaesque/compare/v1.2.0...v1.2.3
[1.2.0]: https://github.com/surgeventures/kafkaesque/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/surgeventures/kafkaesque/compare/v1.0.1...v1.1.0
[1.0.1]: https://github.com/surgeventures/kafkaesque/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/surgeventures/kafkaesque/compare/v0.0.5...v1.0.0
[0.0.5]: https://github.com/surgeventures/kafkaesque/compare/v0.0.4...v0.0.5
[0.0.4]: https://github.com/surgeventures/kafkaesque/compare/v0.0.3...v0.0.4
[0.0.3]: https://github.com/surgeventures/kafkaesque/compare/v0.0.2...v0.0.3
[0.0.2]: https://github.com/surgeventures/kafkaesque/compare/v0.0.1...v0.0.2
[0.0.1]: https://github.com/surgeventures/kafkaesque/compare/v5c6b42aeb0d2ce0b5db650c3efd109d3756c139a...v0.0.1
