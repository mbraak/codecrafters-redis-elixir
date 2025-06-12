defmodule EncodeResp do
  def basic_string(value) do
    "+#{value}\r\n"
  end

  def bulk_string(value) do
    length = String.length(value)
    "$#{length}\r\n#{value}\r\n"
  end

  def null_bulk_string do
    "$-1\r\n"
  end

  def array(values) do
    count = Enum.count(values)
    count_string = "*#{count}\r\n"
    values_string = Enum.join(values)

    "#{count_string}#{values_string}"
  end
end
