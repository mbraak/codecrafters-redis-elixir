defmodule Client do
  def run(client_socket) do
    run_loop(client_socket)
  end

  defp run_loop(client_socket) do
    case :gen_tcp.recv(client_socket, 0) do
      {:ok, _data} ->
        handle_request(client_socket)

      {:error, :closed} ->
        nil
    end
  end

  defp handle_request(client_socket) do
    :gen_tcp.send(client_socket, "+PONG\r\n")
    run_loop(client_socket)
  end
end
