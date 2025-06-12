defmodule TestRdb do
  use ExUnit.Case, async: true

  test "read rdb file" do
    Rdb.read("test/files/dump.rdb")
  end
end
