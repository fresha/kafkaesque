defmodule Kafkaesque.Decoders.Structs.DebeziumCDCMessage do
  @moduledoc """
  Structs representing Debezium CDC messages
  """
  defstruct [:table, :schema, :database, :operation, :primary_key, :data, :timestamp]

  @type t :: %__MODULE__{
          table: String.t(),
          schema: String.t(),
          database: String.t(),
          operation: :insert | :update | :delete | :soft_delete | :unknown,
          primary_key: String.t() | integer,
          data: map() | nil,
          timestamp: DateTime.t()
        }
end
