defmodule TestRdb do
  use ExUnit.Case, async: true

  test "read rdb file" do
    map = Rdb.read("test/files/dump.rdb")
    IO.inspect(map)
  end
end
