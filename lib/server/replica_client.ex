defmodule Server.ReplicaClient do
  use Task

  def start_link(config \\ %{}) do
    Task.start_link(__MODULE__, :run, [config])
  end

  def run(config) do
    [host, port] = parse_replicaof(config[:replicaof])
    listening_port = String.to_integer(config[:port])

    {:ok, socket} = RedisClient.connect(host, port)
    RedisClient.ping(socket)
    RedisClient.repl_conf(socket, ["listening-port", Integer.to_string(listening_port)])
    RedisClient.repl_conf(socket, ["capa", "psync2"])
    RedisClient.psync(socket, "?", -1)

    {:ok, data} = :gen_tcp.recv(socket, 0)
    rest = parse_rdb(data) |> String.trim_leading()

    if String.length(rest) > 0 do
      IO.inspect("ReplicaClient rest")
      IO.inspect(rest)
      Client.handle_request(rest, socket)
    end

    Client.run(socket)
  end

  defp parse_replicaof(replicaof_config) do
    [host, port] = String.split(replicaof_config, " ")
    [host, String.to_integer(port)]
  end

  defp parse_rdb(data) do
    [first_line, rest] = String.split(data, "\r\n", parts: 2)

    rdb_size = String.slice(first_line, 1..String.length(first_line)) |> String.to_integer()
    rest_size = :erlang.byte_size(rest)

    :erlang.binary_part(rest, rdb_size, rest_size - rdb_size)
  end
end
