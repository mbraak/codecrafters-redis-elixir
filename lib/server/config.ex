defmodule Server.Config do
  use GenServer

  @impl GenServer
  def init(state) do
    {:ok, state}
  end

  def start_link(state \\ []) do
    map = state |> Map.new(fn {k, v} -> {Atom.to_string(k), v} end)
    GenServer.start_link(__MODULE__, map, name: __MODULE__)
  end

  @impl GenServer
  def handle_call({:get, key}, _, state) do
    value = Map.get(state, key)
    {:reply, value, state}
  end

  def get(key) do
    GenServer.call(__MODULE__, {:get, key})
  end
end
