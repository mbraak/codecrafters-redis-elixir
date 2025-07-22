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

    {:ok, _rdb} = :gen_tcp.recv(socket, 0)

    run_loop(socket)
  end

  defp parse_replicaof(replicaof_config) do
    [host, port] = String.split(replicaof_config, " ")
    [host, String.to_integer(port)]
  end

  defp run_loop(socket) do
    must_continue =
      case :gen_tcp.recv(socket, 0) do
        {:ok, _data} ->
          true

        {:error, _e} ->
          false
      end

    if must_continue do
      run_loop(socket)
    end
  end
end
