defmodule Client do
  def run(client_socket) do
    run_loop(client_socket)
  end

  defp run_loop(client_socket) do
    must_continue =
      case :gen_tcp.recv(client_socket, 0) do
        {:ok, data} ->
          try do
            handle_request(data, client_socket)
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

  def handle_request(data, client_socket) do
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

    command_downcase != "psync"
  end

  defp handle_command("config", [config_command, key], client_socket) do
    hand_config_command(
      String.downcase(config_command),
      key,
      client_socket
    )
  end

  defp handle_command("echo", [value], client_socket) do
    :gen_tcp.send(
      client_socket,
      EncodeResp.bulk_string(value)
    )
  end

  defp handle_command("get", [key], client_socket) do
    value = Server.Store.get(key)
    response_data = EncodeResp.encode_value(value)

    :gen_tcp.send(client_socket, response_data)
  end

  defp handle_command("info", ["replication"], client_socket) do
    replicaof = Server.Config.get("replicaof")

    role =
      if replicaof do
        "slave"
      else
        "master"
      end

    lines = [
      "# Replication",
      "role:#{role}",
      "connected_slaves:0",
      "master_replid:8371b4fb1155b71f4a04d3e1bc3e18c4a990aeeb",
      "master_repl_offset:0",
      "second_repl_offset:-1",
      "repl_backlog_active:0",
      "repl_backlog_size:1048576",
      "repl_backlog_first_byte_offset:0",
      "repl_backlog_histlen:"
    ]

    info = Enum.join(lines, "\n")

    :gen_tcp.send(
      client_socket,
      EncodeResp.bulk_string(info)
    )
  end

  defp handle_command("keys", _, client_socket) do
    keys = Server.Store.keys()

    :gen_tcp.send(
      client_socket,
      EncodeResp.array(
        for key <- keys do
          EncodeResp.bulk_string(key)
        end
      )
    )
  end

  defp handle_command("ping", [], client_socket) do
    :gen_tcp.send(client_socket, EncodeResp.basic_string("PONG"))
  end

  defp handle_command("psync", ["?", "-1"], client_socket) do
    replication_id = "8371b4fb1155b71f4a04d3e1bc3e18c4a990aeeb"

    empty_rdb_file =
      Base.decode64!(
        "UkVESVMwMDEx+glyZWRpcy12ZXIFNy4yLjD6CnJlZGlzLWJpdHPAQPoFY3RpbWXCbQi8ZfoIdXNlZC1tZW3CsMQQAPoIYW9mLWJhc2XAAP/wbjv+wP9aog=="
      )

    :gen_tcp.send(
      client_socket,
      EncodeResp.basic_string("FULLRESYNC #{replication_id} 0")
    )

    size = :erlang.byte_size(empty_rdb_file)

    :gen_tcp.send(
      client_socket,
      "$#{size}\r\n#{empty_rdb_file}"
    )

    Server.ReplicaServer.add_replica(client_socket)
  end

  defp handle_command("set", [key, value], client_socket) do
    Server.Store.put(key, value)

    :gen_tcp.send(
      client_socket,
      EncodeResp.basic_string("OK")
    )

    Server.ReplicaServer.replicate(
      EncodeResp.array([
        EncodeResp.bulk_string("set"),
        EncodeResp.bulk_string(key),
        EncodeResp.encode_value(value)
      ])
    )
  end

  defp handle_command("replconf", _values, client_socket) do
    :gen_tcp.send(
      client_socket,
      EncodeResp.basic_string("OK")
    )
  end

  defp handle_command("set", [key, value, "px", expiry_ms_string], client_socket) do
    expiry_ms = String.to_integer(expiry_ms_string)
    Server.Store.put_with_expiry(key, value, expiry_ms)

    :gen_tcp.send(
      client_socket,
      EncodeResp.basic_string("OK")
    )
  end

  defp hand_config_command("get", key, client_socket) do
    value = Server.Config.get(key)

    message =
      if is_nil(value) do
        EncodeResp.null_bulk_string()
      else
        EncodeResp.array([
          EncodeResp.bulk_string(key),
          EncodeResp.bulk_string(value)
        ])
      end

    :gen_tcp.send(client_socket, message)
  end
end
