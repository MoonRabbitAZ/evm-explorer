defmodule BlockScoutWeb.Schema do
  @moduledoc false

  use Absinthe.Schema
  use Absinthe.Relay.Schema, :modern

  alias Absinthe.Middleware.Dataloader, as: AbsintheMiddlewareDataloader
  alias Absinthe.Plugin, as: AbsinthePlugin

  alias BlockScoutWeb.Resolvers.{
    Address,
    Block,
    BlockList,
    ChainData,
    InternalTransaction,
    TokenTransfer,
    Transaction,
    Transactions,
    Search
  }

  alias Explorer.Chain
  alias Explorer.Chain.InternalTransaction, as: ExplorerChainInternalTransaction
  alias Explorer.Chain.TokenTransfer, as: ExplorerChainTokenTransfer
  alias Explorer.Chain.Transaction, as: ExplorerChainTransaction

  import_types(BlockScoutWeb.Schema.Types)

  node interface do
    resolve_type(fn
      %ExplorerChainInternalTransaction{}, _ ->
        :internal_transaction

      %ExplorerChainTokenTransfer{}, _ ->
        :token_transfer

      %ExplorerChainTransaction{}, _ ->
        :transaction

      _, _ ->
        nil
    end)
  end

  query do
    node field do
      resolve(fn
        %{type: :internal_transaction, id: id}, _ ->
          %{"transaction_hash" => transaction_hash_string, "index" => index} = Jason.decode!(id)
          {:ok, transaction_hash} = Chain.string_to_transaction_hash(transaction_hash_string)
          InternalTransaction.get_by(%{transaction_hash: transaction_hash, index: index})

        %{type: :token_transfer, id: id}, _ ->
          %{"transaction_hash" => transaction_hash_string, "log_index" => log_index} = Jason.decode!(id)
          {:ok, transaction_hash} = Chain.string_to_transaction_hash(transaction_hash_string)
          TokenTransfer.get_by(%{transaction_hash: transaction_hash, log_index: log_index})

        %{type: :transaction, id: transaction_hash_string}, _ ->
          {:ok, hash} = Chain.string_to_transaction_hash(transaction_hash_string)
          Transaction.get_by(%{}, %{hash: hash}, %{})

        _, _ ->
          {:error, "Unknown node"}
      end)
    end

    @desc "Gets chain data"
    field :chain_data, :chain_data do
      resolve(&ChainData.get_by/3)
    end

    @desc "Gets an address by hash."
    field :address, :address do
      arg(:hash, non_null(:address_hash))
      resolve(&Address.get_by/3)
    end

    @desc "Gets addresses by address hash."
    field :addresses, list_of(:address) do
      arg(:hashes, non_null(list_of(non_null(:address_hash))))
      resolve(&Address.get_by/3)
      complexity(fn %{hashes: hashes}, child_complexity -> length(hashes) * child_complexity end)
    end

    @desc "Search"
    field :search_result, :search_result do
      arg(:parameter, non_null(:string))
      resolve(&Search.get_by/3)
    end

    @desc "Gets a block by number or hash."
    field :block, :block do
      arg(:number, :integer)
      arg(:hash, :full_hash)
      resolve(&Block.get_by/3)
    end

    @desc "Gets last blocks list"
    connection field(:block_list, node_type: :block) do
      resolve(&BlockList.get_by/3)

      complexity(fn
        %{first: first}, child_complexity ->
          first * child_complexity

        %{last: last}, child_complexity ->
          last * child_complexity
      end)
    end

    @desc "Gets transactions by address hash, block number or block hash"
    connection field(:transactions, node_type: :transaction) do
      arg(:address_hash, :address_hash)
      arg(:block_number, :integer)
      arg(:block_hash, :full_hash)
      arg(:count, :integer)

      resolve(&Transactions.get_by/3)

      complexity(fn
        %{first: first}, child_complexity ->
          first * child_complexity

        %{last: last}, child_complexity ->
          last * child_complexity
      end)
    end

    @desc "Gets token transfers by token contract address hash."
    connection field(:token_transfers, node_type: :token_transfer) do
      arg(:token_contract_address_hash, :address_hash)
      arg(:actor_address_hash, :address_hash)
      arg(:transaction_hash, :full_hash)
      arg(:count, :integer)

      resolve(&TokenTransfer.get_by/3)

      complexity(fn
        %{first: first}, child_complexity ->
          first * child_complexity

        %{last: last}, child_complexity ->
          last * child_complexity
      end)
    end

    @desc "Gets a transaction by hash."
    field :transaction, :transaction do
      arg(:hash, non_null(:full_hash))
      resolve(&Transaction.get_by/3)
    end
  end

  subscription do
    field :token_transfers, list_of(:token_transfer) do
      arg(:token_contract_address_hash, non_null(:address_hash))

      config(fn args, _info ->
        {:ok, topic: to_string(args.token_contract_address_hash)}
      end)
    end

    field :blocks, list_of(:block) do
      config(fn _, _info ->
        {:ok, topic: "*"}
      end)
    end

    field :chain_data, :chain_data do
      config(fn _, _info ->
        {:ok, topic: "*"}
      end)
    end
  end

  def context(context) do
    loader = Dataloader.add_source(Dataloader.new(), :db, Chain.data())

    Map.put(context, :loader, loader)
  end

  def plugins do
    [AbsintheMiddlewareDataloader] ++ AbsinthePlugin.defaults()
  end
end
