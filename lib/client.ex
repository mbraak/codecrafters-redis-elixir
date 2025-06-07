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

  defp handle_request(command, params, client_socket) do
    case command do
      "ping" ->
        ping(params, client_socket)

      "echo" ->
        echo(params, client_socket)
    end
  end

  defp ping([], client_socket) do
    :gen_tcp.send(client_socket, EncodeResp.basic_string("PONG"))
  end

  defp echo([value], client_socket) do
    :gen_tcp.send(
      client_socket,
      EncodeResp.bulk_string(value)
    )
  end
end
