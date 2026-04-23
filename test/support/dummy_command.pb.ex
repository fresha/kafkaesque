defmodule DummyCommand.V1.Payload do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  oneof(:command_payload, 0)

  field(:command_uuid, 1, type: :string, json_name: "commandUuid")
  field(:command_timestamp, 2, type: :uint64, json_name: "commandTimestamp")
  field(:dummy_command, 10, type: :string, json_name: "dummyCommand", oneof: 0)
end
