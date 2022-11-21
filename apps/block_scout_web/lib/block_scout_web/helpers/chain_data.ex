defmodule BlockScoutWeb.Helpers.ChainData do
  @moduledoc false

  alias Explorer.{Counters, Chain}
  alias Timex.Duration

  def get_chain_data() do
    chain_data = %{
      average_block_time: Duration.to_milliseconds(Counters.AverageBlockTime.average_block_time()),
      total_transactions: Chain.Cache.Transaction.estimated_count(),
      total_blocks: Chain.Cache.Block.estimated_count(),
      address_count: Chain.address_estimated_count(),
      total_gas_usage: Chain.Cache.GasUsage.total(),
    }

    {:ok, chain_data}
  end
end
