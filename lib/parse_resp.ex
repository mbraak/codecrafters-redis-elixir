defmodule ParseResp do
  def parse(""), do: {"", 0, ""}
  def parse(nil), do: {"", 0, ""}

  # Basic string
  def parse(<<"+", buffer::binary>>) do
    [value, rest] = String.split(buffer, "\r\n", parts: 2)

    request_size = String.length(value) + 3

    {value, request_size, rest}
  end

  # Bulk string
  def parse(<<"$", buffer::binary>>) do
    [length_string, value, buffer] = String.split(buffer, "\r\n", parts: 3)

    request_size = String.length(length_string) + String.length(value) + 5

    {value, request_size, buffer}
  end

  # Array
  def parse(<<"*", buffer::binary>>) do
    [count_string, buffer] = String.split(buffer, "\r\n", parts: 2)

    request_size = String.length(count_string) + 3
    count = String.to_integer(count_string)

    parse_array(count, [], buffer, request_size)
  end

  defp parse_array(0, result, buffer, total_request_size) do
    {Enum.reverse(result), total_request_size, buffer}
  end

  defp parse_array(count, result, buffer, total_request_size) do
    {value, request_size, buffer} = parse(buffer)

    parse_array(
      count - 1,
      [value | result],
      buffer,
      total_request_size + request_size
    )
  end
end
