defmodule Kafkaesque.ConsumerHealthServerTest do
  use ExUnit.Case

  alias Kafkaesque.ConsumerHealthServer

  describe "check/1" do
    test "returns :unhealthy when server is down" do
      assert {:unhealthy, :server_not_alive} == ConsumerHealthServer.check("invalid-server")
    end
  end
end
