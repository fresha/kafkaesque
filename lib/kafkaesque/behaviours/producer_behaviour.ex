defmodule Kafkaesque.Behaviours.ProducerBehaviour do
  @moduledoc """
  Producer behaviour for Kafkaesque.
  """
  @type worker_name :: atom
  @type topic :: String.t()
  @type message_key :: any
  @type message_value :: any
  @type message_values :: [any]
  @type options :: [
          {:timeout, non_neg_integer()}
          | {:partition, non_neg_integer() | nil}
          | {:required_acks, :none | :one | :all}
        ]

  @type header :: {key :: String.t(), value :: String.t()}

  @type message :: %{
          required(:key) => message_key(),
          required(:value) => message_value(),
          optional(:headers) => list(header())
        }

  @doc """
  Produces a batch of messages to a Kafka topic.

  ## Parameters

  * `worker_name` - Process name that will produce the messages
  * `topic` - Kafka topic name (without KAFKA_PREFIX)
  * `messages` - List of messages to write. All messages must share the same key

  ## Examples

  ```ex
  produce_messages(MyProducer, "user_events", [%{
    key: "user:123",
    value: %{action: "login"},
    headers: [{"user_id", "123"}]
  }])
  produce_messages(:analytics_worker, "clicks", click_messages)
  ```
  """
  @callback produce_messages(worker_name, topic, list(message)) :: :ok | {:error, any}

  @doc """
  Same as `produce_messages/3` but accepts additional options.

  ## Options

  * `:timeout` - Maximum time to wait for production (default: 5000ms)
  * `:partition` - Specific partition to produce to (default: determined by key)
  * `:required_acks` - Acknowledgement requirement (default: `:one`)

  ## Examples

  ```ex
  produce_messages(worker, "events", messages, timeout: 10_000)
  produce_messages(worker, "logs", messages, partition: 2, required_acks: :all)
  ```
  """
  @callback produce_messages(worker_name, topic, list(message), options) :: :ok | {:error, any}

  @doc """
  Produce a message with the key `message_key` and value `message_value` to the specified Kafka topic
  - worker_name: the name of the process that will produce the message
  - topic: the Kafka topic to produce the message to, without the KAFKA_PREFIX
  - message_key: the key of the message, it will be used to determine the partition and cant be nil
  - message_value: the value of the message
  """
  @callback produce(worker_name, topic, message_key, message_value) :: :ok | {:error, any}

  @doc """
  Same as above, but with options
    - timeout: max time in milliseconds the server can await the receipt of the number of acknowledgements in required_acks
    - partition: the partition to produce the message to, if nil, the partition will be determined by the key
    - required_acks: how many acknowledgements the servers should receive before responding to the request
  """
  @callback produce(worker_name, topic, message_key, message_value, options) :: :ok | {:error, any}

  @doc """
  Produce a batch of messages with the key `message_key` and values `message_values` to the specified Kafka topic
  - worker_name: the name of the process that will produce the message
  - topic: the Kafka topic to produce the message to, without the KAFKA_PREFIX
  - message_key: the key of the message, it will be used to determine the partition and cant be nil
  - message_values: the values of the messages
  """
  @callback produce_batch(worker_name, topic, message_key, message_values) :: :ok | {:error, any}

  @doc """
  Same as above, but with options
    - timeout: max time in milliseconds the server can await the receipt of the number of acknowledgements in required_acks
    - partition: the partition to produce the message to, if nil, the partition will be determined by the key
    - required_acks: how many acknowledgements the servers should receive before responding to the request
  """
  @callback produce_batch(worker_name, topic, message_key, message_values, options) ::
              :ok | {:error, any}
end
