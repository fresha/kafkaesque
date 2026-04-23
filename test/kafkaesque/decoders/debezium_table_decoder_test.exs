defmodule Kafkaesque.Decoders.DebeziumTableDecoderTest do
  use ExUnit.Case, async: true

  alias Kafkaesque.Decoders.DebeziumTableDecoder
  alias Kafkaesque.Decoders.Structs.DebeziumCDCMessage

  describe "decode!/2" do
    test "returns insert event" do
      message_value =
        Jason.encode!(%{
          "source" => %{"table" => "users", "schema" => "public", "db" => "test"},
          "after" => %{"id" => 1, "name" => "John Doe"},
          "before" => nil,
          "op" => "c",
          "ts_ms" => 1_559_729_471_739
        })

      message_key = Jason.encode!(%{"id" => 1})

      ref = :telemetry_test.attach_event_handlers(self(), [[:kafkaesque, :decode]])

      {:ok, result} = DebeziumTableDecoder.decode!(message_value, message_key: message_key)

      assert result == %DebeziumCDCMessage{
               data: %{id: 1, name: "John Doe"},
               database: "test",
               operation: :insert,
               primary_key: 1,
               schema: "public",
               table: "users",
               timestamp: ~U[2019-06-05 10:11:11.739Z]
             }

      assert_received {[:kafkaesque, :decode], ^ref, %{},
                       %{
                         decoder: Kafkaesque.Decoders.DebeziumTableDecoder,
                         resource: "public.users:insert",
                         schema: "public",
                         table: "users",
                         operation: :insert
                       }}
    end

    test "returns update event" do
      message_value =
        Jason.encode!(%{
          "source" => %{"table" => "users", "schema" => "public", "db" => "test"},
          "after" => %{"id" => 1, "name" => "John Doe"},
          "before" => %{"id" => 1, "name" => "Jane Doe"},
          "op" => "u",
          "ts_ms" => 1_559_729_471_739
        })

      message_key = Jason.encode!(%{"id" => 1})

      {:ok, result} = DebeziumTableDecoder.decode!(message_value, message_key: message_key)

      assert result == %DebeziumCDCMessage{
               data: %{id: 1, name: "John Doe"},
               database: "test",
               operation: :update,
               primary_key: 1,
               schema: "public",
               table: "users",
               timestamp: ~U[2019-06-05 10:11:11.739Z]
             }
    end

    test "returns delete event" do
      message_value =
        Jason.encode!(%{
          "source" => %{"table" => "users", "schema" => "public", "db" => "test"},
          "after" => nil,
          "before" => %{"id" => 1, "name" => "Jane Doe"},
          "op" => "d",
          "ts_ms" => 1_559_729_471_739
        })

      message_key = Jason.encode!(%{"id" => 1})

      {:ok, result} = DebeziumTableDecoder.decode!(message_value, message_key: message_key)

      assert result == %DebeziumCDCMessage{
               data: nil,
               database: "test",
               operation: :delete,
               primary_key: 1,
               schema: "public",
               table: "users",
               timestamp: ~U[2019-06-05 10:11:11.739Z]
             }
    end

    test "returns soft delete event" do
      message_value =
        Jason.encode!(%{
          "source" => %{"table" => "users", "schema" => "public", "db" => "test"},
          "after" => %{"id" => 1, "name" => "John Doe", "deleted_at" => "2021-01-01T00:00:00Z"},
          "before" => %{"id" => 1, "name" => "John Doe", "deleted_at" => nil},
          "op" => "u",
          "ts_ms" => 1_559_729_471_739
        })

      message_key = Jason.encode!(%{"id" => 1})

      {:ok, result} = DebeziumTableDecoder.decode!(message_value, message_key: message_key)

      assert result == %DebeziumCDCMessage{
               data: %{id: 1, name: "John Doe", deleted_at: "2021-01-01T00:00:00Z"},
               database: "test",
               operation: :soft_delete,
               primary_key: 1,
               schema: "public",
               table: "users",
               timestamp: ~U[2019-06-05 10:11:11.739Z]
             }
    end

    test "returns insert event when op: r" do
      message_value =
        Jason.encode!(%{
          "source" => %{"table" => "users", "schema" => "public", "db" => "test"},
          "after" => %{"id" => 1, "name" => "John Doe"},
          "before" => nil,
          "op" => "r",
          "ts_ms" => 1_559_729_471_739
        })

      message_key = Jason.encode!(%{"id" => 1})

      {:ok, result} = DebeziumTableDecoder.decode!(message_value, message_key: message_key)

      assert result == %DebeziumCDCMessage{
               data: %{id: 1, name: "John Doe"},
               database: "test",
               operation: :read,
               primary_key: 1,
               schema: "public",
               table: "users",
               timestamp: ~U[2019-06-05 10:11:11.739Z]
             }
    end

    test "returns unknown if nth has changed" do
      message_value =
        Jason.encode!(%{
          "source" => %{"table" => "users", "schema" => "public", "db" => "test"},
          "after" => %{"id" => 1, "name" => "Jane Doe"},
          "before" => %{"id" => 1, "name" => "Jane Doe"},
          "ts_ms" => 1_559_729_471_739
        })

      message_key = Jason.encode!(%{"id" => 1})

      {:ok, result} = DebeziumTableDecoder.decode!(message_value, message_key: message_key)

      assert result == %DebeziumCDCMessage{
               data: %{id: 1, name: "Jane Doe"},
               database: "test",
               operation: :unknown,
               primary_key: 1,
               schema: "public",
               table: "users",
               timestamp: ~U[2019-06-05 10:11:11.739Z]
             }
    end

    test "returns error when message value is nil" do
      message_key = Jason.encode!(%{"id" => 1})

      assert {:error, :tombstone} = DebeziumTableDecoder.decode!(nil, message_key: message_key)
    end

    test "returns error when message value is empty" do
      message_key = Jason.encode!(%{"id" => 1})

      assert {:error, :tombstone} = DebeziumTableDecoder.decode!("", message_key: message_key)
    end
  end
end
