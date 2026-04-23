import Config

############
# Kafka Ex #
############

config :logger, :console, metadata: :all

config :monitor, Monitor.Tracer,
  service: :kafkaesque,
  adapter: SpandexDatadog.Adapter,
  # If tracing is enabled, this will be overridden by Application.
  disabled?: true

config :kafkaesque,
  kafka_prefix: {:system, "KAFKA_PREFIX"},
  kafka_uris: {:system, "KAFKA_BOOTSTRAP_BROKERS_TLS"},
  healthchecks_enabled: false,
  monitor_trace_context: Monitor.Tracer.SpandexTraceContext

############
# Kafka Ex #
############

config :kafka_ex,
  kafka_version: "kayrock",
  api_versions: %{fetch: 3, offset_fetch: 3, offset_commit: 3},
  disable_default_worker: true,
  use_ssl: false

import_config "#{config_env()}.exs"
