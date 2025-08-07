defmodule ParseRespTest do
  use ExUnit.Case, async: true

  test "parse basic string" do
    assert ParseResp.parse("+test\r\n") == {"test", 7, ""}
  end

  test "parse basic string and return the rest" do
    assert ParseResp.parse("+test\r\n+rest\r\n") == {"test", 7, "+rest\r\n"}
  end

  test "parse bulk string" do
    assert ParseResp.parse("$3\r\nabc\r\n") == {"abc", 9, ""}
  end

  test "parse bulk string and return the rest" do
    assert ParseResp.parse("$3\r\nabc\r\n+rest\r\n") == {"abc", 9, "+rest\r\n"}
  end

  test "parse array with one bulk string" do
    assert ParseResp.parse("*1\r\n$4\r\nPING\r\n") == {["PING"], 14, ""}
  end

  test "parse array with two bulk strings" do
    assert ParseResp.parse("*2\r\n$4\r\nECHO\r\n$3\r\nhey\r\n") == {["ECHO", "hey"], 23, ""}
  end

  test "parse array and return the rest of the input" do
    {result, request_size, rest} =
      ParseResp.parse(
        "*3\r\n$3\r\nSET\r\n$3\r\nfoo\r\n$3\r\n123\r\n*3\r\n$3\r\nSET\r\n$3\r\nbar\r\n$3\r\n456\r\n*3\r\n$3\r\nSET\r\n$3\r\nbaz\r\n$3\r\n789\r\n"
      )

    assert result == ["SET", "foo", "123"]
    assert request_size == 31

    assert rest ==
             "*3\r\n$3\r\nSET\r\n$3\r\nbar\r\n$3\r\n456\r\n*3\r\n$3\r\nSET\r\n$3\r\nbaz\r\n$3\r\n789\r\n"
  end
end
