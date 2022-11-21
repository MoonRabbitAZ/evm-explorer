defmodule BlockScoutWeb.Resolvers.Transactions do
  @moduledoc false

  alias BlockScoutWeb.Helpers.Database
  alias BlockScoutWeb.Helpers.Transaction, as: TransactionHelper
  alias Explorer.GraphQL

  def get_by(_, %{address_hash: address_hash} = args, _) do
    connection_args = prepare_args(args)

    address_hash
    |> GraphQL.address_to_transactions_query
    |> execute(connection_args)
  end

  def get_by(_, %{block_hash: hash} = args, _) do
    connection_args = prepare_args(args)

    case Explorer.Chain.hash_to_block(hash) do
      {:error, :not_found} -> {:error, "Block not found."}
      {:ok, result} ->
        result.number
        |> GraphQL.list_transactions_in_block
        |> execute(connection_args)
    end
  end

  def get_by(_, %{block_number: block_number} = args, _) do
    connection_args = prepare_args(args)

    block_number
    |> GraphQL.list_transactions_in_block
    |> execute(connection_args)
  end

  def get_by(_, %{} = args, _) do
    connection_args = prepare_args(args)

    GraphQL.list_transactions
    |> execute(connection_args)

  end

  defp execute(query, connection_args) do
    query
    |> Database.select_records(connection_args)
    |> Enum.map(fn item -> TransactionHelper.fetch_transaction_details(item) end)
    |> Database.from_slice_updated(connection_args)
  end

  defp prepare_args(args), do: Database.prepare_connection_args(args, options(args))

  defp options(%{before: _}), do: []

  defp options(%{count: count}), do: [count: count]

  defp options(_), do: []
end
