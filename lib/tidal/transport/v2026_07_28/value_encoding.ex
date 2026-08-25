defmodule Tidal.Transport.V20260728.ValueEncoding do
  @moduledoc false

  @prefix "=?base64?"
  @suffix "?="

  @spec decode(String.t()) :: {:ok, String.t()} | {:error, :invalid_header_encoding}
  def decode(@prefix <> encoded) do
    with true <- String.ends_with?(encoded, @suffix),
         payload <- String.replace_suffix(encoded, @suffix, ""),
         {:ok, decoded} <- Base.decode64(payload) do
      {:ok, decoded}
    else
      _ -> {:error, :invalid_header_encoding}
    end
  end

  def decode(value) when is_binary(value) do
    if valid_plain_header_value?(value) do
      {:ok, value}
    else
      {:error, :invalid_header_encoding}
    end
  end

  defp valid_plain_header_value?(value) do
    value == String.trim(value) and
      value != "" and
      Enum.all?(:binary.bin_to_list(value), &valid_header_byte?/1)
  end

  defp valid_header_byte?(byte), do: byte == 9 or byte in 32..126
end
