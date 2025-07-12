defmodule CLI do
  def main(_args) do
    {:ok, _pid} = Application.ensure_all_started(:codecrafters_redis)

    Process.sleep(:infinity)
  end
end
