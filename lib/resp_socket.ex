defmodule RespSocket do
  defmodule Socket do
    defstruct [:buffer, :socket]
  end

  def new(socket) do
    %Socket{buffer: "", socket: socket}
  end

  def read(%Socket{} = socket) do
    case read_buffer(socket) do
      {:ok, buffer} ->
        {parsed_data, request_size, buffer} = ParseResp.parse(buffer)

        socket = %Socket{socket | buffer: buffer}

        {:ok, socket, parsed_data, request_size}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def read_rdb(%Socket{} = socket) do
    {:ok, data} = read_buffer(socket)

    [first_line, data] = String.split(data, "\r\n", parts: 2)

    rdb_size = String.slice(first_line, 1..String.length(first_line)) |> String.to_integer()
    data_size = :erlang.byte_size(data)

    buffer = :erlang.binary_part(data, rdb_size, data_size - rdb_size)

    %Socket{socket | buffer: buffer}
  end

  def close(%Socket{} = socket) do
    :gen_tcp.close(socket.socket)

    %Socket{socket | buffer: ""}
  end

  defp read_buffer(%Socket{} = socket) do
    if byte_size(socket.buffer) == 0 do
      :gen_tcp.recv(socket.socket, 0)
    else
      {:ok, socket.buffer}
    end
  end
end
