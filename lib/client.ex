defmodule Client do
  def run(client_socket) do
    run_loop(client_socket)
  end

  defp run_loop(client_socket) do
    case :gen_tcp.recv(client_socket, 0) do
      {:ok, data} ->
        try do
          handle_request(
            ParseResp.parse(data),
            client_socket
          )
        rescue
          _ -> :gen_tcp.close(client_socket)
        end

      {:error, :closed} ->
        nil

      {:error, :enotconn} ->
        nil
    end

    run_loop(client_socket)
  end

  defp handle_request([command | tail], client_socket) do
    handle_request(
      String.downcase(command),
      tail,
      client_socket
    )
  end

  defp handle_request("config", [config_command, key], client_socket) do
    hand_config_command(
      String.downcase(config_command),
      key,
      client_socket
    )
  end

  defp handle_request("echo", [value], client_socket) do
    :gen_tcp.send(
      client_socket,
      EncodeResp.bulk_string(value)
    )
  end

  defp handle_request("get", [key], client_socket) do
    value = Server.Store.get(key)

    response_data =
      case value do
        value when is_nil(value) -> EncodeResp.null_bulk_string()
        value when is_integer(value) -> EncodeResp.integer(value)
        value when is_binary(value) -> EncodeResp.bulk_string(value)
      end

    :gen_tcp.send(client_socket, response_data)
  end

  defp handle_request("info", ["replication"], client_socket) do
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

  defp handle_request("keys", _, client_socket) do
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

  defp handle_request("ping", [], client_socket) do
    :gen_tcp.send(client_socket, EncodeResp.basic_string("PONG"))
  end

  defp handle_request("psync", ["?", "-1"], client_socket) do
    replication_id = "8371b4fb1155b71f4a04d3e1bc3e18c4a990aeeb"

    :gen_tcp.send(
      client_socket,
      EncodeResp.basic_string("FULLRESYNC #{replication_id} 0")
    )
  end

  defp handle_request("set", [key, value], client_socket) do
    Server.Store.put(key, value)

    :gen_tcp.send(
      client_socket,
      EncodeResp.basic_string("OK")
    )
  end

  defp handle_request("replconf", _values, client_socket) do
    :gen_tcp.send(
      client_socket,
      EncodeResp.basic_string("OK")
    )
  end

  defp handle_request("set", [key, value, "px", expiry_ms_string], client_socket) do
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
