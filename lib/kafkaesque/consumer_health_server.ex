defmodule Kafkaesque.ConsumerHealthServer do
  @moduledoc """
  This module provides ways to check if Kafka consumers are healthy, i.e.:
    - we can communicate with the Kafka brokers
    - the topic(s) we try to subscribe to exist
  """
  use GenServer

  require Logger

  defmodule State do
    @moduledoc false

    @type t :: %State{}

    defstruct [
      :start_time,
      :consumer_group_name,
      :expected_topics,
      :worker_pid
    ]
  end

  @dialyzer [
    # Required to avoid no local return
    {:nowarn_function, handle_continue: 2},
    {:nowarn_function, start_health_worker: 1}
  ]

  # -------------------------------------------------------------------------------
  @type consumer_group_identifier :: String.t()
  @type topic_name :: String.t()

  @doc """
  Start the server that checks the health of Kafka consumer groups.
  """
  @spec start_link(consumer_group_identifier, expected_topics :: [topic_name]) ::
          GenServer.on_start()
  def start_link(consumer_group_identifier, expected_topics) do
    server_name = health_server_name(consumer_group_identifier)

    GenServer.start_link(
      __MODULE__,
      [consumer_group_identifier, expected_topics],
      name: server_name
    )
  end

  # -------------------------------------------------------------------------------
  @type unhealthy_reason :: :metadata_retrieve_failed | :server_not_alive | String.t()

  @doc """
  Ask for the health of the consumer group that this server manages.
  """
  @spec check(consumer_group_identifier) :: :healthy | {:unhealthy, unhealthy_reason}
  def check(consumer_group_identifier) do
    server_name = health_server_name(consumer_group_identifier)

    if server_alive?(server_name) do
      GenServer.call(server_name, :check)
    else
      {:unhealthy, :server_not_alive}
    end
  end

  # -------------------------------------------------------------------------------
  # Callbacks
  @impl true
  def init([consumer_group_identifier, expected_topics]) do
    state = %State{
      consumer_group_name: Kafkaesque.Config.kafka_prefix_prepend(consumer_group_identifier),
      expected_topics: expected_topics,
      start_time: DateTime.utc_now(),
      worker_pid: nil
    }

    {:ok, state, {:continue, :start_health_worker}}
  end

  @impl true
  def handle_continue(
        :start_health_worker,
        %State{consumer_group_name: consumer_group_name} = state
      ) do
    {:ok, worker_pid} = start_health_worker(consumer_group_name)
    {:noreply, %State{state | worker_pid: worker_pid}}
  end

  # -------------------------------------------------------------------------------
  @impl true
  def handle_call(:check, _from, state) do
    case check_topics_subscriptions(state) do
      :ok ->
        {:reply, :healthy, state}

      {:error, {:missing_topics, missing_topics}} ->
        if still_warmup?(state) do
          Logger.info("Kafkaesque warmup phase. missing topics: #{missing_topics}. Waiting for cluster readiness")

          {:reply, :healthy, state}
        else
          {:reply, {:unhealthy, "Missing topics: #{missing_topics}"}, state}
        end

      {:error, reason} ->
        {:reply, {:unhealthy, reason}, state}
    end
  end

  @impl true
  def handle_call(_msg, _from, state) do
    {:reply, :ok, state}
  end

  # -------------------------------------------------------------------------------
  @impl true
  def handle_cast(_msg, state) do
    {:noreply, state}
  end

  # -------------------------------------------------------------------------------
  @impl true
  def terminate(reason, %State{worker_pid: worker_pid} = _state) do
    Logger.info("Terminating consumer health server with reason #{inspect(reason)}")
    KafkaEx.stop_worker(worker_pid)
  end

  # -------------------------------------------------------------------------------
  # Private functions
  @spec start_health_worker(consumer_group_name :: binary) :: {:ok, pid} | {:error, term}
  defp start_health_worker(consumer_group_name) do
    kafka_endpoints = Kafkaesque.Config.kafka_endpoints()
    use_ssl = Kafkaesque.Config.get(:use_ssl, KafkaEx.Config.use_ssl())
    ssl_options = Kafkaesque.Config.get(:ssl_options, KafkaEx.Config.ssl_options())

    worker_opts = [
      uris: kafka_endpoints,
      use_ssl: use_ssl,
      ssl_options: ssl_options
    ]

    worker_name = String.to_atom("#{consumer_group_name}_health_worker")

    case KafkaEx.create_worker(worker_name, worker_opts) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      other -> other
    end
  end

  # -------------------------------------------------------------------------------
  defp parse_consumer_group_metadata({:error, reason}), do: {:error, reason}
  defp parse_consumer_group_metadata({:ok, nil}), do: {:error, :metadata_retrieve_failed}
  defp parse_consumer_group_metadata({:ok, %{groups: groups}}), do: parse_groups_structs(groups)

  defp parse_consumer_group_metadata({:ok, group}) when not is_list(group) do
    parse_groups_structs([group])
  end

  # -------------------------------------------------------------------------------
  defp parse_groups_structs(groups_structs) do
    parse_groups_structs(groups_structs, [])
  end

  # -------------------------------------------------------------------------------
  defp parse_groups_structs([], acc), do: Enum.uniq(acc)

  defp parse_groups_structs([head | rest], acc) do
    topics = parse_group_struct(head)
    new_acc = Enum.concat(acc, topics)

    parse_groups_structs(rest, new_acc)
  end

  # -------------------------------------------------------------------------------
  defp parse_group_struct(group_struct) do
    Enum.flat_map(group_struct.members, fn member_struct ->
      Enum.map(member_struct.member_assignment.partition_assignments, & &1.topic)
    end)
  end

  # -------------------------------------------------------------------------------
  defp check_topics_subscriptions(%State{
         worker_pid: worker_name_or_pid,
         consumer_group_name: consumer_group_name,
         expected_topics: expected_topics
       }) do
    consumer_group_name
    |> KafkaEx.describe_group(worker_name: worker_name_or_pid)
    |> parse_consumer_group_metadata()
    |> check_topics_match(expected_topics)
  end

  defp check_topics_match({:error, reason}, _), do: {:error, reason}

  defp check_topics_match(assigned_topics, expected_topics) do
    diff = expected_topics -- assigned_topics

    case diff do
      [] -> :ok
      _ -> {:error, {:missing_topics, Enum.join(diff, ", ")}}
    end
  end

  defp health_server_name(consumer_group_name) do
    String.to_atom("#{consumer_group_name}_health_server")
  end

  defp server_alive?(server_name) do
    case GenServer.whereis(server_name) do
      nil -> false
      pid -> Process.alive?(pid)
    end
  end

  defp still_warmup?(%State{start_time: start_time}) do
    current_time = DateTime.utc_now()
    warmup_time = Kafkaesque.Config.get(:healthchecks_warmup_time_in_seconds)

    DateTime.diff(current_time, start_time, :second) < warmup_time
  end
end
