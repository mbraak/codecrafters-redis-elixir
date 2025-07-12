defmodule RedisClient do
  def ping(host, port) do
    send(host, port, EncodeResp.array([EncodeResp.bulk_string("PING")]))
  end

  defp send(host, port, resp) do
    opts = [:binary, active: false]

    case :gen_tcp.connect(to_charlist(host), port, opts) do
      {:ok, socket} ->
        :ok = :gen_tcp.send(socket, resp)
        :gen_tcp.recv(socket, 0)
        :gen_tcp.close(socket)

      {:error, reason} ->
        IO.puts(reason)
    end
  end
end
