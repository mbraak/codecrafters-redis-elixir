defmodule Server.ReplicaClient do
  use Task

  defmodule State do
    defstruct [:processed_count, :resp_socket]
  end

  def start_link(config \\ %{}) do
    Task.start_link(__MODULE__, :run, [config])
  end

  def run(config) do
    resp_socket = connect(config)

    state = %State{
      processed_count: 0,
      resp_socket: resp_socket
    }

    run_loop(state)
  end

  defp connect(config) do
    [host, port] = parse_replicaof_config(config[:replicaof])
    listening_port = String.to_integer(config[:port])

    resp_socket = RedisClient.connect(host, port)

    {:ok, resp_socket, _result} = RedisClient.ping(resp_socket)

    {:ok, resp_socket, _result} =
      RedisClient.repl_conf(resp_socket, ["listening-port", Integer.to_string(listening_port)])

    {:ok, resp_socket, _result} = RedisClient.repl_conf(resp_socket, ["capa", "psync2"])

    {:ok, resp_socket, _result} = RedisClient.psync(resp_socket, "?", -1)

    RespSocket.read_rdb(resp_socket)
  end

  defp parse_replicaof_config(replicaof_config) do
    [host, port] = String.split(replicaof_config, " ")
    [host, String.to_integer(port)]
  end

  defp run_loop(%State{} = state) do
    state =
      case RespSocket.read(state.resp_socket) do
        {:ok, resp_socket, parsed_data, request_size} ->
          handle_parsed_data(parsed_data, state)

          %{
            state
            | processed_count: state.processed_count + request_size,
              resp_socket: resp_socket
          }

        {:error, _} ->
          %State{state | resp_socket: nil}
      end

    if state.resp_socket do
      run_loop(state)
    end
  end

  defp handle_parsed_data(parsed_data, state) do
    [command | tail] = parsed_data
    command_downcase = String.downcase(command)

    handle_command(command_downcase, tail, state)
  end

  defp handle_command("set", [key, value], _state) do
    Server.Store.put(key, value)
  end

  defp handle_command("ping", [], _state) do
  end

  defp handle_command("replconf", ["GETACK", "*"], state) do
    :gen_tcp.send(
      state.resp_socket.socket,
      EncodeResp.array([
        EncodeResp.bulk_string("REPLCONF"),
        EncodeResp.bulk_string("ACK"),
        EncodeResp.bulk_string(Integer.to_string(state.processed_count))
      ])
    )
  end
end
