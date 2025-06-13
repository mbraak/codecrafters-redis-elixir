defmodule Rdb do
  def read(path) do
    {:ok, io_device} = File.open(path)

    _header = IO.binread(io_device, 9)
    section_type = read_metadatas(io_device)

    if section_type != <<0xFE>> do
      raise "Expected database subsection"
    end

    read_database_subsection(io_device)
    map = read_tables(io_device)
    read_checksum(io_device)

    File.close(io_device)
    map
  end

  defp read_metadatas(io_device) do
    section_type = IO.binread(io_device, 1)

    if section_type == <<0xFA>> do
      read_metadata(io_device)
      read_metadatas(io_device)
    else
      section_type
    end
  end

  defp read_metadata(io_device) do
    _name = read_string(io_device)
    _value = read_string(io_device)
  end

  defp read_string(io_device) do
    <<length>> = IO.binread(io_device, 1)

    case length do
      0xC0 -> read_byte(io_device)
      0xC1 -> IO.binread(io_device, 2)
      0xC2 -> IO.binread(io_device, 4)
      _ -> IO.binread(io_device, length)
    end
  end

  defp read_database_subsection(io_device) do
    _database_index = IO.binread(io_device, 1)
  end

  defp read_tables(io_device) do
    section_type = IO.binread(io_device, 1)

    if section_type != <<0xFB>> do
      raise "Expected tables"
    end

    <<hash_table_size>> = IO.binread(io_device, 1)
    <<_expirations_size>> = IO.binread(io_device, 1)
    <<_value_type>> = IO.binread(io_device, 1)

    1..hash_table_size
    |> Enum.map(fn _ ->
      key = read_string(io_device)
      value = read_string(io_device)
      {key, value}
    end)
    |> Map.new()
  end

  defp read_checksum(io_device) do
    section_type = IO.binread(io_device, 1)

    if section_type != <<0xFF>> do
      raise "Expected checksum"
    end

    _checksum = IO.binread(io_device, 8)
  end

  defp read_byte(io_device) do
    <<value>> = IO.binread(io_device, 1)
    value
  end
end
