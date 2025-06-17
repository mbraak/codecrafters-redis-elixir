defmodule ParseRdbTest do
  use ExUnit.Case, async: true

  test "read rdb file" do
    entries = ParseRdb.read("test/files/dump.rdb")
    IO.inspect(entries)
  end
end
