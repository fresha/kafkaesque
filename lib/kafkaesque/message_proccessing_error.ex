defmodule Kafkaesque.MessageProcessingError do
  @moduledoc false

  defexception [:description]

  def message(%__MODULE__{description: description}) do
    "Message processing failed due to: #{inspect(description)}"
  end
end
