defmodule Kafkaesque.Decoders.TimestampHelper do
  @moduledoc """
  Helper module responsible for converting seconds/milliseconds/microseconds
  unix timestamp to DateTime with microseconds precision.
  """
  @spec parse_timestamp(unix_timestamp :: integer) :: DateTime.t()
  def parse_timestamp(unix_timestamp) do
    unix_timestamp
    |> guess_timestamp_unit()
    |> convert_to_microseconds(unix_timestamp)
    |> DateTime.from_unix!(:microsecond)
  end

  # This code handles all cases between 2001 & 33658 year
  # In this time interval
  # seconds has < 13 digits
  # millisecond has < 16 digits
  defp guess_timestamp_unit(unix_timestamp) do
    digits = Integer.digits(unix_timestamp)

    cond do
      length(digits) >= 16 -> :microsecond
      length(digits) >= 13 -> :millisecond
      true -> :second
    end
  end

  defp convert_to_microseconds(:microsecond, unix_timestamp), do: unix_timestamp

  defp convert_to_microseconds(unit, unix_timestamp) do
    unix_timestamp
    |> DateTime.from_unix!(unit)
    |> DateTime.to_unix(:microsecond)
  end
end
