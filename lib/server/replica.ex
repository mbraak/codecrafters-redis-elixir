defmodule Server.Replica do
  use GenServer

  @impl GenServer
  def init(config) do
    replicaof = config[:replicaof]

    if replicaof do
      [host, port] = parse_replicaof(replicaof)
      listening_port = String.to_integer(config[:port])

      {:ok, socket} = RedisClient.connect(host, port)
      RedisClient.ping(socket)
      RedisClient.repl_conf(socket, ["listening-port", Integer.to_string(listening_port)])
      RedisClient.repl_conf(socket, ["capa", "psync2"])
      RedisClient.close(socket)
    end

    {:ok, config}
  end

  def start_link(config \\ %{}) do
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  def parse_replicaof(replicaof_config) do
    [host, port] = String.split(replicaof_config, " ")
    [host, String.to_integer(port)]
  end
end
