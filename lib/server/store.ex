defmodule Server.Store do
  use GenServer

  @impl GenServer
  def init(config) do
    state = read_rdb_file(config)

    {:ok, state}
  end

  @impl GenServer
  def handle_cast({:put, key, value}, state) do
    {
      :noreply,
      Map.put(
        state,
        key,
        %{value: value, expiry_timestamp: nil}
      )
    }
  end

  @impl GenServer
  def handle_cast({:put_with_expiry, key, value, expiry_ms}, state) do
    expiry_timestamp = System.os_time(:millisecond) + expiry_ms

    {
      :noreply,
      Map.put(
        state,
        key,
        %{
          value: value,
          expiry_timestamp: expiry_timestamp
        }
      )
    }
  end

  @impl GenServer
  def handle_call({:get, key}, _, state) do
    value =
      case Map.get(state, key) do
        nil ->
          nil

        %{value: value, expiry_timestamp: nil} ->
          value

        %{value: value, expiry_timestamp: expiry_timestamp} ->
          if expiry_timestamp > System.os_time(:millisecond) do
            value
          end
      end

    {:reply, value, state}
  end

  @impl GenServer
  def handle_call(:keys, _, state) do
    value = Map.keys(state)

    {:reply, value, state}
  end

  def start_link(state \\ %{}) do
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

  def keys() do
    GenServer.call(__MODULE__, :keys)
  end

  defp read_rdb_file(config) do
    dir = config[:dir]
    dbfilename = config[:dbfilename] || "dump.rdb"

    rdb_path =
      if dir do
        Path.join(dir, dbfilename)
      else
        dbfilename
      end

    if File.exists?(rdb_path) do
      rdb_path
      |> ParseRdb.read()
      |> Enum.filter(&(elem(&1, 0) == :entry))
      |> Enum.map(fn {:entry, %{key: key, value: value, expiry_timestamp: expiry_timestamp}} ->
        {
          key,
          %{
            value: value,
            expiry_timestamp: expiry_timestamp
          }
        }
      end)
      |> Map.new()
    else
      %{}
    end
  end
end
