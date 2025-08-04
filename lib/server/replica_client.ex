defmodule Server.ReplicaClient do
  use Task

  defmodule State do
    defstruct [:must_continue, :processed_count, :socket]
  end

  def start_link(config \\ %{}) do
    Task.start_link(__MODULE__, :run, [config])
  end

  def run(config) do
    socket = connect(config)
    request = receive_rdb(socket)
    IO.inspect("request after rdb file #{request}")

    state = %State{
      must_continue: true,
      processed_count: 0,
      socket: socket
    }

    state = if String.length(request ) > 0 do
      handle_request(request , state)
    else
      state
    end

    run_loop(state)
  end

  defp connect(config) do
     [host, port] = parse_replicaof_config(config[:replicaof])
    listening_port = String.to_integer(config[:port])

    {:ok, socket} = RedisClient.connect(host, port)

    RedisClient.ping(socket)

    {:ok, _result } = RedisClient.repl_conf(socket, ["listening-port", Integer.to_string(listening_port)])
    #IO.inspect("result #{result}")

    {:ok, _result } = RedisClient.repl_conf(socket, ["capa", "psync2"])
    #IO.inspect("result #{result}")

    {:ok, _result } = RedisClient.psync(socket, "?", -1)
    #IO.inspect("result #{result}")

    socket
  end

  defp parse_replicaof_config(replicaof_config) do
    [host, port] = String.split(replicaof_config, " ")
    [host, String.to_integer(port)]
  end

  defp receive_rdb(socket) do
    IO.inspect("receive_rdb")
    {:ok, data} = :gen_tcp.recv(socket, 0)

    IO.inspect(data, limit: :infinity)
    parse_rdb(data) |> String.trim_leading()
  end

  defp parse_rdb(data) do
    [first_line, data] = String.split(data, "\r\n", parts: 2)

    rdb_size = String.slice(first_line, 1..String.length(first_line)) |> String.to_integer()
    data_size = :erlang.byte_size(data)

    :erlang.binary_part(data, rdb_size, data_size - rdb_size)
  end

  defp run_loop(state) do
    state =
      case :gen_tcp.recv(state.socket, 0) do
        {:ok, data} ->
          try do
            handle_request(data, state)
          rescue
            _ ->
              :gen_tcp.close(state.socket)
              %{state | must_continue: false}
          end

        {:error, _} ->
          %{state | must_continue: false}
      end

    if state.must_continue do
      run_loop(state)
    end
  end

  defp handle_request(data, state) do
    IO.inspect("handle request #{data}")
    {parsed_data, rest} = ParseResp.parse(data)
    request_size = byte_size(data) - byte_size(rest)
    IO.inspect("request size #{request_size}")

    handle_parsed_data(parsed_data, state)

    state = %{ state | processed_count: state.processed_count + request_size}

    if rest == "" do
      state
    else
      handle_request(rest, state)
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
    IO.inspect("replconf getack #{state.processed_count}")
    :gen_tcp.send(
      state.socket,
      EncodeResp.array([
        EncodeResp.bulk_string("REPLCONF"),
        EncodeResp.bulk_string("ACK"),
        EncodeResp.bulk_string(Integer.to_string(state.processed_count))
      ])
    )
  end
end
