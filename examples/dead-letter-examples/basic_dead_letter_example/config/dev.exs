import Config

config :kafkaesque,
  kafka_prefix: "dev",
  kafka_uris: "localhost:9092"

config :kafka_ex,
  use_ssl: false
