defmodule Rdb do
  def read(path) do
    {:ok, io_device} = File.open(path)
    _header = IO.binread(io_device, 9)
    read_sections(io_device)
    File.close(io_device)
  end

  defp read_sections(io_device) do
    section_type = IO.binread(io_device, 1)

    if section_type != :eof do
      case section_type do
        <<0xFA>> -> read_metadata(io_device)
        <<0xFB>> -> read_tables(io_device)
        <<0xFE>> -> read_database_subsection(io_device)
        <<0xFF>> -> read_checksum(io_device)
      end

      read_sections(io_device)
    end
  end

  defp read_metadata(io_device) do
    _name = read_string(io_device)
    _value = read_string(io_device)
  end

  defp read_string(io_device) do
    <<length>> = IO.binread(io_device, 1)

    case length do
      0xC0 -> IO.binread(io_device, 1)
      0xC1 -> IO.binread(io_device, 2)
      0xC2 -> IO.binread(io_device, 4)
      _ -> IO.binread(io_device, length)
    end
  end

  defp read_database_subsection(io_device) do
    _database_index = IO.binread(io_device, 1)
  end

  defp read_tables(io_device) do
    <<hash_table_size>> = IO.binread(io_device, 1)
    <<_expirations_size>> = IO.binread(io_device, 1)
    <<_value_type>> = IO.binread(io_device, 1)

    Enum.each(
      1..hash_table_size,
      fn _ ->
        _key = read_string(io_device)
        _value = read_string(io_device)
      end
    )
  end

  defp read_checksum(io_device) do
    _checksum = IO.binread(io_device, 8)
  end
end
