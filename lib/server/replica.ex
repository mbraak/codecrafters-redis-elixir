defmodule Server.Replica do
  use GenServer

  @impl GenServer
  def init(config) do
    replicaof = config[:replicaof]

    if replicaof do
      ping(replicaof)
    end

    {:ok, config}
  end

  def start_link(config \\ %{}) do
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  defp ping(replicaof) do
    [host, port] = String.split(replicaof, " ")
    port_int = String.to_integer(port)
    opts = [:binary, active: false]

    case :gen_tcp.connect(to_charlist(host), port_int, opts) do
      {:ok, socket} ->
        :ok = :gen_tcp.send(socket, EncodeResp.array([EncodeResp.bulk_string("PING")]))
        :gen_tcp.recv(socket, 0)
        :gen_tcp.close(socket)

      {:error, reason} ->
        IO.puts(reason)
    end

    # :gen_tcp.close(socket)
  end
end
