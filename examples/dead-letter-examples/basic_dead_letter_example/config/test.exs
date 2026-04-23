import Config

config :sentry, environment_name: "test"

config :kafkaesque,
  kafka_prefix: "test",
  kafka_uris: "localhost:9092"
