defmodule BlockScoutWeb.Resolvers.Search do
  @moduledoc false

  alias Explorer.Chain
  alias Explorer.Chain.Wei
  alias Explorer.PagingOptions

  @page_size 1
  @default_paging_options %PagingOptions{page_size: @page_size + 1}

  def get_by(_, %{parameter: parameter} = _, _) do
    result = parameter
             |> search
             |> List.last(nil)

    {:ok, result}
  end

  def search(term) when is_binary(term) do
    paging_options = @default_paging_options
    offset = (max(paging_options.page_number, 1) - 1) * paging_options.page_size

    results =
      paging_options
      |> search_by(offset, term)

    results
    |> Enum.map(fn item ->
      tx_hash_bytes = Map.get(item, :tx_hash)
      block_hash_bytes = Map.get(item, :block_hash)

      item =
        if tx_hash_bytes do
          item
          |> Map.replace(:tx_hash, "0x" <> Base.encode16(tx_hash_bytes, case: :lower))
        else
          item
        end

      item =
        if block_hash_bytes do
          item
          |> Map.replace(:block_hash, "0x" <> Base.encode16(block_hash_bytes, case: :lower))
        else
          item
        end

      process_null_block(item)
    end)
  end

  def process_null_block(search_result) when search_result.type != "block" do
    Map.replace(search_result, :block_number, nil)
  end
  def process_null_block(search_result), do: search_result

  def paging_options(%{"hash" => hash, "fetched_coin_balance" => fetched_coin_balance}) do
    with {coin_balance, ""} <- Integer.parse(fetched_coin_balance),
         {:ok, address_hash} <- Chain.string_to_address_hash(hash) do
      [paging_options: %{@default_paging_options | key: {%Wei{value: Decimal.new(coin_balance)}, address_hash}}]
    else
      _ ->
        [paging_options: @default_paging_options]
    end
  end

  def search_by(paging_options, offset, term) do
    Chain.joint_search(paging_options, offset, term)
  end
end
