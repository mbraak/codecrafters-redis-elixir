defmodule EncodeRespTest do
  use ExUnit.Case, async: true

  test "array" do
    encoded_string =
      EncodeResp.array([
        EncodeResp.bulk_string("dir"),
        EncodeResp.bulk_string("/tmp/redis-files")
      ])

    assert encoded_string == "*2\r\n$3\r\ndir\r\n$16\r\n/tmp/redis-files\r\n"
  end
end
