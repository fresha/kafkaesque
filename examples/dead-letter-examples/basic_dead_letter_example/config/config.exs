# This file is responsible for configuring your umbrella
# and **all applications** and their dependencies with the
# help of the Config module.
#
# Note that all applications in your umbrella share the
# same configuration and dependencies, which is why they
# all use the same configuration file. If you want different
# configurations or dependencies per app, it is best to
# move said applications out of the umbrella.
import Config

# Application Condif
config :basic_dead_letter_example_consumer, :events_consumer, consume_events: false

# Fresha Monitoring Config
config :monitor, Monitor.Tracer,
  service: :checkout,
  adapter: SpandexDatadog.Adapter,
  disabled?: true

config :sentry,
  enable_source_code_context: true,
  root_source_code_paths: [File.cwd!()],
  filter: Monitor.Sentry.EventFilter,
  before_send_event: {Monitor.Sentry.EventProcessor, :before_send}

# Fresha Kafka Config
config :kafkaesque,
  healthchecks_enabled: true,
  healthchecks_warmup_time_in_seconds: 60,
  monitor_trace_context: Monitor.Tracer.SpandexTraceContext

config :kafka_ex,
  client_id: "basic_dead_letter_example",
  kafka_version: "kayrock",
  api_versions: %{fetch: 5, offset_fetch: 3, offset_commit: 3},
  disable_default_worker: true,
  commit_interval: 10_000,
  commit_threshold: 100

import_config "#{config_env()}.exs"
