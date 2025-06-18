defmodule Helpers.Hash do

  def generate(value) do
    input_hash = :crypto.hash(:sha256, value) |> Base.encode16() |> String.downcase()

    hash_numbers = input_hash
      |> String.slice(0, 4)
      |> String.to_charlist()
      |> Enum.map(&(&1))

    sqids = Sqids.new!()
    short_id = Sqids.encode!(sqids, hash_numbers)
  end
end
