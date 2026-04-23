import Config

config :kafkaesque,
  kafka_prefix: "dummy",
  kafka_uris: "broker1:9200,broker2:9200,broker3:9200"

config :sentry,
  enable_source_code_context: true,
  root_source_code_paths: [File.cwd!()],
  dsn: "",
  environment_name: "dev"
