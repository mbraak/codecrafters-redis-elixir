defmodule RedisClient do
  def connect(host, port) do
    opts = [:binary, active: false]

    :gen_tcp.connect(to_charlist(host), port, opts)
  end

  def close(socket) do
    :gen_tcp.close(socket)
  end

  def ping(socket) do
    send_message(socket, EncodeResp.array([EncodeResp.bulk_string("PING")]))
  end

  def psync(socket, replication_id, offset) do
    send_message(
      socket,
      EncodeResp.array([
        EncodeResp.bulk_string("PSYNC"),
        EncodeResp.bulk_string(replication_id),
        EncodeResp.bulk_string(Integer.to_string(offset))
      ])
    )
  end

  def repl_conf(socket, values) do
    request =
      EncodeResp.array([
        EncodeResp.bulk_string("REPLCONF")
        | Enum.map(values, &EncodeResp.bulk_string(&1))
      ])

    send_message(
      socket,
      request
    )
  end

  defp send_message(socket, resp) do
    :ok = :gen_tcp.send(socket, resp)
    :gen_tcp.recv(socket, 0)
  end
end
