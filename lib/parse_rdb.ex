defmodule ParseRdb do
  def read(path) do
    {:ok, content} = File.read(path)
    parse(content)
  end

  def parse(content), do: parse(content, [])

  # String key
  defp parse(<<0, rest::binary>>, entries) do
    {key, rest} = parse_value(rest)
    {value, rest} = parse_value(rest)

    entry = {:entry, {key, value}}
    parse(rest, [entry | entries])
  end

  # Header
  defp parse(<<"REDIS", version::binary-size(4), rest::binary>>, entries) do
    entry = {:version, String.to_integer(version)}
    parse(rest, [entry | entries])
  end

  # Metadata
  defp parse(<<0xFA, rest::binary>>, entries) do
    {key, rest} = parse_value(rest)
    {value, rest} = parse_value(rest)

    entry = {:metadata, {key, value}}
    parse(rest, [entry | entries])
  end

  # Key count
  defp parse(<<0xFB, rest::binary>>, entries) do
    {key_count, rest} = parse_length(rest)
    {expiration_count, rest} = parse_length(rest)

    entry = {:key_count, {key_count, expiration_count}}
    parse(rest, [entry | entries])
  end

  # Database index
  defp parse(<<0xFE, database_id::size(8), rest::binary>>, entries) do
    parse(rest, [{:database_id, database_id} | entries])
  end

  # Checksum
  defp parse(<<0xFF, checksum::binary-size(8)>>, entries) do
    entry = {:checksum, checksum}
    [entry | entries]
  end

  # Short string
  defp parse_value(<<0::size(2), len::size(6), value::binary-size(len), rest::binary>>) do
    {value, rest}
  end

  # 1 byte integer
  defp parse_value(<<0xC0, value::integer-signed-8, rest::binary>>) do
    {value, rest}
  end

  # 4 byte integer
  defp parse_value(<<0xC2, value::integer-signed-32, rest::binary>>) do
    {value, rest}
  end

  # 1 byte length
  def parse_length(<<0::size(2), len::size(6), rest::binary>>), do: {len, rest}
end
