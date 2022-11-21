defmodule BlockScoutWeb.Helpers.Block do
  @moduledoc false

  alias Explorer.Chain

  def fetch_block_transaction_count(block) do
    block
    |> Map.put(:total_transaction_count, block_transaction_count(block))
    |> Map.put(:parent_hash, update_parent_hash(block))
  end

  defp update_parent_hash(block) when block.number == 0, do: nil

  defp update_parent_hash(block), do: block.parent_hash

  defp block_transaction_count(block) do
    Chain.block_to_transaction_count(block.hash)
  end
end
