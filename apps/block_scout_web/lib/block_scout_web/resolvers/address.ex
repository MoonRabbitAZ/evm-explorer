defmodule BlockScoutWeb.Resolvers.Address do
  @moduledoc false

  alias BlockScoutWeb.CurrencyHelpers
  alias Explorer.Chain
  alias Explorer.Counters.{AddressTokenTransfersCounter, AddressTransactionsCounter, AddressTransactionsGasUsageCounter}
  alias Explorer.CustomContractsHelpers

  {:ok, nil_address_hash} = Chain.string_to_address_hash("0x0000000000000000000000000000000000000000")
  @nil_address_hash nil_address_hash


  def get_by(_, %{hashes: hashes}, _) do
    case Chain.hashes_to_addresses(hashes) do
      [] -> {:error, "Addresses not found."}
      result -> {:ok, result}
    end
  end

  def get_by(_, %{hash: hash}, _) do
    case hash == @nil_address_hash do
      true ->
        {:ok, fetch_nil_address_details(%{hash: hash})}

      false ->
        case Chain.hash_to_address(hash) do
          {:error, :not_found} -> {:error, "Address not found."}
          {:ok, result} -> {:ok, fetch_address_details(result)}
        end
    end
  end

  def fetch_nil_address_details(address) do
    address
    |> Map.put(:transfer_count, token_transfers_count(address))
    |> Map.put(:transaction_count, transaction_count(address))
    |> Map.put(:validation_count, 1)
  end

  def fetch_address_details(address) do
    address
    |> Map.put(:transfer_count, token_transfers_count(address))
    |> Map.put(:transaction_count, transaction_count(address))
    |> Map.put(:gas_usage_count, gas_usage_count(address))
    |> Map.put(:validation_count, validation_count(address))
    |> Map.put(:crc_total_worth, crc_total_worth(address))
  end

  defp transaction_count(address) do
    AddressTransactionsCounter.fetch(address)
  end

  defp token_transfers_count(address) do
    AddressTokenTransfersCounter.fetch(address)
  end

  defp gas_usage_count(address) do
    AddressTransactionsGasUsageCounter.fetch(address)
  end

  defp validation_count(address) do
    Chain.address_to_validation_count(address.hash)
  end

  defp crc_total_worth(address) do
    circles_total_balance(address.hash)
  end

  defp circles_total_balance(address_hash) do
    circles_addresses_list = CustomContractsHelpers.get_custom_addresses_list(:circles_addresses)

    token_balances =
      address_hash
      |> Chain.fetch_last_token_balances()

    token_balances_except_bridged =
      token_balances
      |> Enum.filter(fn {_, _, token} -> !token.bridged end)

    circles_total_balance_raw =
      if Enum.count(circles_addresses_list) > 0 do
        token_balances_except_bridged
        |> Enum.reduce(Decimal.new(0), fn {token_balance, _, token}, acc_balance ->
          {:ok, token_address} = Chain.hash_to_address(token.contract_address_hash)

          from_address = from_address_hash(token_address)

          created_from_address_hash =
            if from_address,
               do: "0x" <> Base.encode16(from_address.bytes, case: :lower),
               else: nil

          if Enum.member?(circles_addresses_list, created_from_address_hash) && token.name == "Circles" &&
               token.symbol == "CRC" do
            Decimal.add(acc_balance, token_balance.value)
          else
            acc_balance
          end
        end)
      else
        Decimal.new(0)
      end

    CurrencyHelpers.format_according_to_decimals(circles_total_balance_raw, Decimal.new(18))
  end

  defp from_address_hash(
         %Chain.Address{contracts_creation_internal_transaction: %Chain.InternalTransaction{}} = address
       ) do
    address.contracts_creation_internal_transaction.from_address_hash
  end
end
