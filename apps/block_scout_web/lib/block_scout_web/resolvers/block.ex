defmodule BlockScoutWeb.Resolvers.Block do
  @moduledoc false

  alias BlockScoutWeb.Helpers.Block, as: BlockHelper
  alias Explorer.Chain

  def get_by(_, %{number: number}, _) do
    case Chain.number_to_block(number) do
      {:ok, result} -> {:ok, BlockHelper.fetch_block_transaction_count(result)}
      {:error, :not_found} -> {:error, "Block number #{number} was not found."}
    end
  end

  def get_by(_, %{hash: hash}, _) do
    case Chain.hash_to_block(hash) do
      {:ok, result} -> {:ok, BlockHelper.fetch_block_transaction_count(result)}
      {:error, :not_found} -> {:error, "Block not found."}
    end
  end

  def get_by(_, _, _) do
    {:error, "Block not found."}
  end
end
