defmodule ParseRdbTest do
  use ExUnit.Case, async: true

  test "read rdb file" do
    _entries = ParseRdb.read("test/files/dump.rdb")
  end
end
