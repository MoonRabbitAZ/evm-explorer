defmodule BlockScoutWeb.Resolvers.BlockList do
  @moduledoc false

  alias Explorer.GraphQL
  alias BlockScoutWeb.Helpers.{Database}
  alias BlockScoutWeb.Helpers.Block, as: BlockHelper


  def get_by(_, %{} = args, _) do
    connection_args = prepare_args(args)

    GraphQL.list_blocks
    |> Database.select_records(connection_args)
    |> Enum.map(fn item -> BlockHelper.fetch_block_transaction_count(item) end)
    |> Database.from_slice_updated(connection_args)
  end

  defp prepare_args(args), do: Database.prepare_connection_args(args, options(args))

  defp options(%{before: _}), do: []

  defp options(%{count: count}), do: [count: count]

  defp options(_), do: []
end
