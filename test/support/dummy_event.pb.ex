defmodule DummyEvent.V1.Payload do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field(:id, 1, type: :uint32, json_name: "id")
  field(:name, 2, type: :string, json_name: "name")
  field(:flag, 3, type: :string, json_name: "flag")
  field(:created_at, 4, type: :string, json_name: "createdAt")
end
