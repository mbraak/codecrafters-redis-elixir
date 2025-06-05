defmodule ParseMessage do
  def parse(""), do: nil
  def parse(nil), do: nil

  def parse(value) when is_binary(value) do
    {result, _} = value |> String.trim_trailing() |> String.split("\r\n") |> parse_lines
    result
  end

  # defp parse_lines([]), do: {nil, []}

  defp parse_lines([line | rest_lines]) do
    {first_char, rest_first_line} = String.split_at(line, 1)

    parse_lines(first_char, rest_first_line, rest_lines)
  end

  # Simple string
  defp parse_lines("+", rest_first_line, rest_lines) do
    {rest_first_line, rest_lines}
  end

  # Bulk string
  defp parse_lines("$", _rest_first_line, rest_lines) do
    [result | result_rest_lines] = rest_lines
    {result, result_rest_lines}
  end

  # Array
  defp parse_lines("*", rest_first_line, initial_rest_lines) do
    count = String.to_integer(rest_first_line)

    {result, result_rest_lines} =
      Enum.reduce(
        1..count,
        {[], initial_rest_lines},
        fn _, {result, rest_lines} ->
          {value, rest_lines} = parse_lines(rest_lines)
          {[value | result], rest_lines}
        end
      )

    {Enum.reverse(result), result_rest_lines}
  end
end
