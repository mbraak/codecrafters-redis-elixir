defmodule Server.Store do
  use GenServer

  @impl GenServer
  def init(_) do
    {:ok, %{}}
  end

  @impl GenServer
  def handle_cast({:put, key, value}, state) do
    {:noreply, Map.put(state, key, {value, nil})}
  end

  @impl GenServer
  def handle_cast({:put_with_expiry, key, value, expiry_ms}, state) do
    expiry_timestamp = System.os_time(:millisecond) + expiry_ms
    IO.inspect(expiry_ms)

    {:noreply, Map.put(state, key, {value, expiry_timestamp})}
  end

  @impl GenServer
  def handle_call({:get, key}, _, state) do
    value =
      case Map.get(state, key) do
        nil ->
          nil

        {value, nil} ->
          value

        {value, expiry_timestamp} ->
          if expiry_timestamp > System.os_time(:millisecond) do
            value
          end
      end

    {:reply, value, state}
  end

  def start_link(state \\ []) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  def put(key, value) do
    GenServer.cast(__MODULE__, {:put, key, value})
  end

  def put_with_expiry(key, value, expiry_ms) do
    GenServer.cast(__MODULE__, {:put_with_expiry, key, value, expiry_ms})
  end

  def get(key) do
    GenServer.call(__MODULE__, {:get, key})
  end
end
