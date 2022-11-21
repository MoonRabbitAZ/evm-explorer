defmodule BlockScoutWeb.Resolvers.ChainData do
  @moduledoc false

  alias BlockScoutWeb.Helpers.ChainData

  def get_by(_, _, _) do
    ChainData.get_chain_data()
  end
end
