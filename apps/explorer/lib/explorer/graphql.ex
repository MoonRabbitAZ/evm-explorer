defmodule Explorer.GraphQL do
  @moduledoc """
  The GraphQL context.
  """

  import Ecto.Query,
    only: [
      from: 2,
      order_by: 3,
      or_where: 3,
      where: 3
    ]

  alias Explorer.Chain.{
    Block,
    Hash,
    InternalTransaction,
    TokenTransfer,
    Transaction,
    Token
  }

  alias Explorer.{Chain, Repo}

  @doc """
  Returns a query to fetch transactions with a matching `to_address_hash`,
  `from_address_hash`, or `created_contract_address_hash` field for a given address hash.

  Orders transactions by descending block number and index.
  """
  def address_to_transactions_query(address_hash) do
    from(
      t in Transaction,
      order_by: [desc: t.block_number, desc: t.index],
      where: t.to_address_hash == ^address_hash,
      or_where: t.from_address_hash == ^address_hash,
      or_where: t.created_contract_address_hash == ^address_hash,
      select: t
    )
  end

  @doc """
  Returns token data by address
  """
  def address_to_token(address_hash) do
    from(
      tokens in Token,
      where: tokens.contract_address_hash == ^address_hash,
      select: tokens
    )
  end

  @doc """
  Returns an internal transaction for a given transaction hash and index.
  """
  def get_internal_transaction(%{transaction_hash: _, index: _} = clauses) do
    if internal_transaction = Repo.replica().get_by(InternalTransaction.where_nonpending_block(), clauses) do
      {:ok, internal_transaction}
    else
      {:error, "Internal transaction not found."}
    end
  end

  @doc """
  Returns a query to fetch internal transactions for a given transaction.

  Orders internal transactions by ascending index.
  """
  def transaction_to_internal_transactions_query(%Transaction{
    hash: %Hash{byte_count: unquote(Hash.Full.byte_count())} = hash
  }) do
    query =
      from(
        it in InternalTransaction,
        inner_join: t in assoc(it, :transaction),
        order_by: [asc: it.index],
        where: it.transaction_hash == ^hash,
        select: it
      )

    query
    |> InternalTransaction.where_nonpending_block()
    |> Chain.where_transaction_has_multiple_internal_transactions()
  end

  @doc """
  Returns block list
  """
  def list_blocks() do
    from(
      blocks in Block,
      order_by: [desc: blocks.number],
      select: blocks
    )
  end

  @doc """
  Returns a token transfer for a given transaction hash and log index.
  """
  def get_token_transfer(%{transaction_hash: _, log_index: _} = clauses) do
    if token_transfer = Repo.replica().get_by(TokenTransfer, clauses) do
      {:ok, token_transfer}
    else
      {:error, "Token transfer not found."}
    end
  end

  @doc """
  Returns token transfers list for a given transaction hash
  """
  def get_token_transfers_list(%Hash{byte_count: unquote(Hash.Full.byte_count())} = hash) do
    from(
      tt in TokenTransfer,
      where: tt.transaction_hash == ^hash,
      order_by: [desc: tt.block_number],
      left_join: tokens in Token,
      on: tokens.contract_address_hash == tt.token_contract_address_hash,
      select_merge: %{
        token: tokens
      }
    )
  end

  @doc """
  Returns token transfers list for a given from or to
  """
  def list_token_transfers_actor(%Hash{byte_count: unquote(Hash.Address.byte_count())} = actor_address_hash) do
    from(
      tt in TokenTransfer,
      where: tt.from_address_hash == ^actor_address_hash,
      or_where: tt.to_address_hash == ^actor_address_hash,
      order_by: [desc: tt.block_number],
      left_join: tokens in Token,
      on: tokens.contract_address_hash == tt.token_contract_address_hash,
      select_merge: %{
        token: tokens
      }
    )
  end

  @doc """
  Returns a query to fetch token transfers for a token contract address hash.

  Orders token transfers by descending block number.
  """
  def list_token_transfers_query(%Hash{byte_count: unquote(Hash.Address.byte_count())} = token_contract_address_hash) do
    from(
      tt in TokenTransfer,
      inner_join: t in assoc(tt, :transaction),
      where: tt.token_contract_address_hash == ^token_contract_address_hash,
      order_by: [desc: tt.block_number],
      left_join: tokens in Token,
      on: tokens.contract_address_hash == tt.token_contract_address_hash,
      select_merge: %{
        token: tokens
      }
    )
  end

  @doc """
  Returns transactions in block by block number
  """
  def list_transactions_in_block(number) do
    from(
      transactions in Transaction,
      where: transactions.block_number == ^number,
      select: transactions
    )
  end

  @doc """
  Returns transaction list
  """
  def list_transactions() do
    from(
      transactions in Transaction,
      order_by: [desc: transactions.block_number],
      select: transactions
    )
  end
end
