defmodule EncodeResp do
  def integer(value) do
    ":#{value}\r\n"
  end

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

  def array(encoded_values) do
    count = Enum.count(encoded_values)
    count_string = "*#{count}\r\n"

    values_string = Enum.join(encoded_values)

    "#{count_string}#{values_string}"
  end

  def encode_value(value) do
    case value do
      value when is_nil(value) -> EncodeResp.null_bulk_string()
      value when is_integer(value) -> EncodeResp.integer(value)
      value when is_binary(value) -> EncodeResp.bulk_string(value)
    end
  end
end
