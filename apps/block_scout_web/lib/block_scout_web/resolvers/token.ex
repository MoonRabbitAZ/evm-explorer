defmodule BlockScoutWeb.Resolvers.Token do
  @moduledoc false

  alias Explorer.{GraphQL, Repo}
  alias Explorer.Chain.Address

  def get_by(%Address{hash: address_hash}, _, _) do
    address_hash
    |> GraphQL.address_to_token()
    |> Repo.one()
    |> case do
         nil -> {:error, :not_found}
         result -> {:ok, result}
       end
  end
end
