defmodule Server.ReplicaServer do
  use GenServer

  @impl GenServer
  def init(state) do
    {:ok, state}
  end

  @impl GenServer
  def handle_cast({:add_replica, socket}, state) do
    {
      :noreply,
      [socket | state]
    }
  end

  @impl GenServer
  def handle_cast({:replicate, data}, state) do
    Enum.each(
      state,
      fn socket ->
        :gen_tcp.send(socket, data)
      end
    )

    {
      :noreply,
      state
    }
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def add_replica(socket) do
    GenServer.cast(__MODULE__, {:add_replica, socket})
  end

  def replicate(data) do
    GenServer.cast(__MODULE__, {:replicate, data})
  end
end
