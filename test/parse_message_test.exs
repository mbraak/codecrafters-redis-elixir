defmodule ParseMessageTest do
  use ExUnit.Case, async: true

  test "parse basic string" do
    assert ParseMessage.parse("+test\r\n") == "test"
  end

  test "parse bulk string" do
    assert ParseMessage.parse("$3\r\nabc\r\n") == "abc"
  end

  test "parse array with one bulk string" do
    assert ParseMessage.parse("*1\r\n$4\r\nPING\r\n") == ["PING"]
  end

  test "parse array with two bulk strings" do
    assert ParseMessage.parse("*2\r\n$4\r\nECHO\r\n$3\r\nhey\r\n") == ["ECHO", "hey"]
  end
end
