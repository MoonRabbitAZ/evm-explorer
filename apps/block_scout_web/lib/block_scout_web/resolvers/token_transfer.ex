defmodule BlockScoutWeb.Resolvers.TokenTransfer do
  @moduledoc false

  alias BlockScoutWeb.Helpers.Database
  alias BlockScoutWeb.Helpers.Transaction, as: TransactionHelper
  alias Explorer.{GraphQL, Repo}

  @burn_address_hash_str "0x0000000000000000000000000000000000000000"

  def get_by(%{transaction_hash: _, log_index: _} = args) do
    case GraphQL.get_token_transfer(args) do
      {:ok, token_transfer} -> {:ok, fetch_transfer_details(token_transfer)}
      {:error, error} -> {:error, error}
    end
  end

  def get_by(_, %{transaction_hash: transaction_hash} = args, _) do
    connection_args = prepare_args(args)

    transaction_hash
    |> GraphQL.get_token_transfers_list
    |> prepare_token_transfers(connection_args)
  end

  def get_by(_, %{token_contract_address_hash: token_contract_address_hash} = args, _) do
    connection_args = prepare_args(args)

    token_contract_address_hash
    |> GraphQL.list_token_transfers_query
    |> prepare_token_transfers(connection_args)
  end

  def get_by(_, %{actor_address_hash: actor_address_hash} = args, _) do
    connection_args = prepare_args(args)

    actor_address_hash
    |> GraphQL.list_token_transfers_actor
    |> prepare_token_transfers(connection_args)
  end

  def get_by(_, _, _) do
    {:error, "No transactionHash, actorAddressHash or tokenContractAddressHash provided"}
  end

  defp prepare_token_transfers(query, connection_args) do
    query
    |> Database.select_records(connection_args)
    |> Enum.map(fn item -> fetch_transfer_details(item) end)
    |> Database.from_slice_updated(connection_args)
  end

  defp fetch_transfer_details(transfer) do
    transfer
    |> Map.put(:token_status, get_token_status(transfer))
    |> Map.put(:transaction, add_transaction(transfer))
  end

  defp add_transaction(transfer) do
    case Chain.hash_to_transaction(transfer.transaction_hash) do
      {:ok, transaction} -> TransactionHelper.fetch_transaction_details(transaction)
      {:error, :not_found} -> nil
    end
  end

  defp get_token_status(transfer) do
    {:ok, burn_address_hash} = Chain.string_to_address_hash(@burn_address_hash_str)

    cond do
      transfer.to_address_hash == burn_address_hash && transfer.from_address_hash !== burn_address_hash ->
        "burning"

      transfer.to_address_hash !== burn_address_hash && transfer.from_address_hash == burn_address_hash ->
        "minting"

      transfer.to_address_hash == burn_address_hash && transfer.from_address_hash == burn_address_hash ->
        "spawning"

      true ->
        "transfer"
    end
  end

  defp prepare_args(args), do: Database.prepare_connection_args(args, options(args))

  defp options(%{before: _}), do: []

  defp options(%{count: count}), do: [count: count]

  defp options(_), do: []
end
