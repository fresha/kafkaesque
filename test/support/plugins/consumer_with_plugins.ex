defmodule Kafkaesque.Support.Plugins do
  @moduledoc false

  defmodule Supervisor do
    @moduledoc false
    use Kafkaesque.ConsumerSupervisor,
      consumer_group_identifier: "consumer_with_plugins",
      topics: ["with_before_plugin", "with_after_plugin", "with_wrapper_plugin", "many_plugins"],
      message_handler: Kafkaesque.Support.Plugins.ConsumerWithPlugins,
      dead_letter_queue: nil
  end

  defmodule ConsumerWithPlugins do
    @moduledoc false
    use Kafkaesque.Consumer,
      commit_strategy: :sync,
      consumer_group_identifier: "consumer_with_plugins",
      topics_config: %{
        "with_before_plugin" => %{
          decoder_config: {nil, []},
          handle_message_plugins: [{Kafkaesque.Plugins.BeforePlugin, []}]
        },
        "with_after_plugin" => %{
          decoder_config: {nil, []},
          handle_message_plugins: [{Kafkaesque.Plugins.AfterPlugin, []}]
        },
        "with_wrapper_plugin" => %{
          decoder_config: {nil, []},
          handle_message_plugins: [{Kafkaesque.Plugins.WrapperPlugin, []}]
        },
        "many_plugins" => %{
          decoder_config: {nil, []},
          handle_message_plugins: [
            {Kafkaesque.Plugins.BeforePlugin, []},
            {Kafkaesque.Plugins.WrapperPlugin, []}
          ]
        }
      },
      retries: 0

    def handle_decoded_message(_message) do
      store = Process.get(:store)
      Process.put(:store, [:handled | store])

      :ok
    end
  end
end
