defmodule BlockScoutWeb.Resolvers.Transaction do
  @moduledoc false

  alias BlockScoutWeb.Helpers.Database
  alias BlockScoutWeb.Helpers.Transaction, as: TransactionHelper
  alias Explorer.{Chain, GraphQL, Repo}
  alias Explorer.Chain.Address

  def get_by(_, %{hash: hash}, _) do
    case Chain.hash_to_transaction(hash) do
      {:ok, transaction} -> {:ok, TransactionHelper.fetch_transaction_details(transaction)}
      {:error, :not_found} -> {:error, "Transaction not found."}
    end
  end

  def get_by(%Address{hash: address_hash}, args, _) do
    connection_args = prepare_args(args)

    address_hash
    |> GraphQL.address_to_transactions_query
    |> Database.select_records(connection_args)
    |> Enum.map(fn item -> TransactionHelper.fetch_transaction_details(item) end)
    |> Database.from_slice_updated(connection_args)
  end

  defp prepare_args(args), do: Database.prepare_connection_args(args, options(args))

  defp options(%{before: _}), do: []

  defp options(%{count: count}), do: [count: count]

  defp options(_), do: []
end
