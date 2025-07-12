defmodule Server do
  use Application

  def start(_type, _args) do
    args = System.argv()

    {parsed_options, _, _} =
      OptionParser.parse(args,
        strict: [dir: :string, dbfilename: :string, port: :string, replicaof: :string]
      )

    defaults = [port: "6379"]
    options = Keyword.merge(defaults, parsed_options)

    children = [
      {Server.Store, options},
      {Server.Config, options},
      {Task, &Server.listen/0}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end

  @doc """
  Listen for incoming connections
  """
  def listen() do
    # Since the tester restarts your program quite often, setting SO_REUSEADDR
    # ensures that we don't run into 'Address already in use' errors
    port = Server.Config.get("port") |> String.to_integer()

    {:ok, socket} = :gen_tcp.listen(port, [:binary, active: false, reuseaddr: true])

    accept(socket)
  end

  defp accept(socket) do
    {:ok, client_socket} = :gen_tcp.accept(socket)
    Task.start_link(fn -> Client.run(client_socket) end)

    accept(socket)
  end
end
