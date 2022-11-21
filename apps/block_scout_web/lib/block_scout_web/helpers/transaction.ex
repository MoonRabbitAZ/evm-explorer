defmodule BlockScoutWeb.Helpers.Transaction do
  @moduledoc false

  # alias Explorer.Chain
  alias DateTime
  alias Explorer.{Chain, GraphQL, Repo}
  alias Explorer.Chain.{Address, Transaction}

  @token_burning_type :token_burning
  @token_minting_type :token_minting
  @token_creation_type :token_spawning
  @token_transfer_type :token_transfer

  def fetch_transaction_details(transaction) do
    transaction
    |> Map.put(:type, transaction |> add_token_transfers |> transaction_display_type)
    |> Map.put(:status, formatted_result(transaction))
    |> Map.put(:timestamp, add_timestamp(transaction))
  end

  def add_token_transfers(%Transaction{} = transaction) do
    transaction
    |> Map.put(:token_transfers, fetch_token_transfers(transaction))
  end

  def fetch_token_transfers(%Transaction{} = transaction) do
    transaction.hash
    |> GraphQL.get_token_transfers_list
    |> Repo.all
  end

  def transaction_display_type(%Transaction{} = transaction) do
    cond do
      involves_token_transfers?(transaction) ->
        token_transfer_type = get_transaction_type_from_token_transfers(transaction.token_transfers)

        case token_transfer_type do
          @token_minting_type -> "token_minting"
          @token_burning_type -> "token_burning"
          @token_creation_type -> "token_creation"
          @token_transfer_type -> "token_transfer"
        end

      contract_creation?(transaction) ->
        "contract_creation"

      involves_contract?(transaction) ->
        "contract_call"

      true ->
        "transaction"
    end
  end

  def involves_contract?(%Transaction{
    from_address_hash: from_address_hash,
    to_address_hash: to_address_hash
  })
      when to_address_hash == nil and from_address_hash == nil do
    false
  end

  def involves_contract?(%Transaction{
    from_address_hash: from_address_hash,
    to_address_hash: to_address_hash
  })
      when to_address_hash == nil do
    with {:ok, from} <- Chain.hash_to_address(from_address_hash) do
      contract?(from)
    else
      :error -> false
      _ -> false
    end
  end

  def involves_contract?(%Transaction{
    from_address_hash: from_address_hash,
    to_address_hash: to_address_hash
  })
      when from_address_hash == nil do
    with {:ok, to} <- Chain.hash_to_address(to_address_hash) do
      contract?(to)
    else
      :error -> false
      _ -> false
    end
  end

  def involves_contract?(%Transaction{
    from_address_hash: from_address_hash,
    to_address_hash: to_address_hash
  })
      when to_address_hash == nil and from_address_hash == nil do
    true
  end

  def involves_contract?(%Transaction{
    from_address_hash: from_address_hash,
    to_address_hash: to_address_hash
  }) do
    with {:ok, from} <- Chain.hash_to_address(from_address_hash),
         {:ok, to} <- Chain.hash_to_address(to_address_hash) do
      contract?(from) || contract?(to)
    else
      :error -> false
      _ -> false
    end
  end

  defp get_transaction_type_from_token_transfers(token_transfers) do
    token_transfers_types =
      token_transfers
      |> Enum.map(fn token_transfer ->
        Chain.get_token_transfer_type(token_transfer)
      end)

    burnings_count =
      Enum.count(token_transfers_types, fn token_transfers_type -> token_transfers_type == @token_burning_type end)

    mintings_count =
      Enum.count(token_transfers_types, fn token_transfers_type -> token_transfers_type == @token_minting_type end)

    creations_count =
      Enum.count(token_transfers_types, fn token_transfers_type -> token_transfers_type == @token_creation_type end)

    cond do
      Enum.count(token_transfers_types) == burnings_count -> @token_burning_type
      Enum.count(token_transfers_types) == mintings_count -> @token_minting_type
      Enum.count(token_transfers_types) == creations_count -> @token_creation_type
      true -> @token_transfer_type
    end
  end

  def involves_token_transfers?(%Transaction{token_transfers: []}), do: false
  def involves_token_transfers?(%Transaction{token_transfers: transfers}) when is_list(transfers), do: true
  def involves_token_transfers?(_), do: false

  def contract_creation?(%Transaction{to_address_hash: nil}), do: true
  def contract_creation?(_), do: false

  def formatted_result(transaction) do
    case Chain.transaction_to_status(transaction) do
      :pending -> "pending"
      :awaiting_internal_transactions -> "pending"
      :success -> "success"
      {:error, :awaiting_internal_transactions} -> "error"
      # The pool of possible error reasons is unknown or even if it is enumerable, so we can't translate them
      {:error, reason} when is_binary(reason) -> "error"
    end
  end

  def contract?(%Address{contract_code: nil}), do: false
  def contract?(%Address{contract_code: _}), do: true
  def contract?(nil), do: true

  def add_timestamp(%Transaction{block_hash: block_hash}) do
    block = Chain.fetch_block_by_hash(block_hash)

    block.timestamp
  end
end
