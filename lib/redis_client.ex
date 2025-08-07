defmodule RedisClient do
  def connect(host, port) do
    opts = [:binary, active: false]
    {:ok, socket} = :gen_tcp.connect(to_charlist(host), port, opts)
    RespSocket.new(socket)
  end

  def ping(resp_socket) do
    send_message(resp_socket, EncodeResp.array([EncodeResp.bulk_string("PING")]))
  end

  def psync(resp_socket, replication_id, offset) do
    send_message(
      resp_socket,
      EncodeResp.array([
        EncodeResp.bulk_string("PSYNC"),
        EncodeResp.bulk_string(replication_id),
        EncodeResp.bulk_string(Integer.to_string(offset))
      ])
    )
  end

  def repl_conf(resp_socket, values) do
    request =
      EncodeResp.array([
        EncodeResp.bulk_string("REPLCONF")
        | Enum.map(values, &EncodeResp.bulk_string(&1))
      ])

    send_message(resp_socket, request)
  end

  defp send_message(resp_socket, resp_data) do
    :ok = :gen_tcp.send(resp_socket.socket, resp_data)
    {:ok, resp_socket, parsed_data, _request_size} = RespSocket.read(resp_socket)
    {:ok, resp_socket, parsed_data}
  end
end
