defmodule Server.ReplicaClient do
  use Task

  def start_link(config \\ %{}) do
    Task.start_link(__MODULE__, :run, [config])
  end

  def run(config) do
    socket = connect(config)
    request = receive_rdb(socket)

    if String.length(request ) > 0 do
      handle_request(request , socket)
    end

    run_loop(socket)
  end

  defp connect(config) do
     [host, port] = parse_replicaof_config(config[:replicaof])
    listening_port = String.to_integer(config[:port])

    {:ok, socket} = RedisClient.connect(host, port)

    RedisClient.ping(socket)
    RedisClient.repl_conf(socket, ["listening-port", Integer.to_string(listening_port)])
    RedisClient.repl_conf(socket, ["capa", "psync2"])
    RedisClient.psync(socket, "?", -1)

    socket
  end

  defp parse_replicaof_config(replicaof_config) do
    [host, port] = String.split(replicaof_config, " ")
    [host, String.to_integer(port)]
  end

  defp receive_rdb(socket) do
    {:ok, data} = :gen_tcp.recv(socket, 0)
    parse_rdb(data) |> String.trim_leading()
  end

  defp parse_rdb(data) do
    [first_line, data] = String.split(data, "\r\n", parts: 2)

    rdb_size = String.slice(first_line, 1..String.length(first_line)) |> String.to_integer()
    rest_size = :erlang.byte_size(data)

    :erlang.binary_part(data, rdb_size, rest_size - rdb_size)
  end

  defp run_loop(client_socket) do
    must_continue =
      case :gen_tcp.recv(client_socket, 0) do
        {:ok, data} ->
          try do
            handle_request(data, client_socket)
            true
          rescue
            _ ->
              :gen_tcp.close(client_socket)
              false
          end

        {:error, _} ->
          false
      end

    if must_continue do
      run_loop(client_socket)
    end
  end

  defp handle_request(data, client_socket) do
    {parsed_data, rest} = ParseResp.parse(data)

    result = handle_parsed_data(parsed_data, client_socket)

    if rest == "" do
      result
    else
      handle_request(rest, client_socket)
    end
  end

  defp handle_parsed_data(parsed_data, client_socket) do
    [command | tail] = parsed_data
    command_downcase = String.downcase(command)

    handle_command(command_downcase, tail, client_socket)
  end

  defp handle_command("set", [key, value], _client_socket) do
    Server.Store.put(key, value)
  end

  defp handle_command("ping", [], _client_socket) do
  end

  defp handle_command("replconf", ["GETACK", "*"], client_socket) do
    :gen_tcp.send(
      client_socket,
      EncodeResp.array([
        EncodeResp.bulk_string("REPLCONF"),
        EncodeResp.bulk_string("ACK"),
        EncodeResp.bulk_string("0")
      ])
    )
  end
end
