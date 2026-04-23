defmodule DummyEventEnvelope.V1.Payload do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  oneof(:payload, 0)

  field(:dummy_event, 11, type: DummyEvent.V1.Payload, json_name: "dummyEvent", oneof: 0)
end
