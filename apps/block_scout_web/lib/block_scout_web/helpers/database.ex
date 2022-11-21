defmodule BlockScoutWeb.Helpers.Database do
  @moduledoc false

  import Ecto.Query,
         only: [
           limit: 2,
           offset: 2
         ]

  alias Absinthe.Relay.Connection
  alias Explorer.Repo

  def select_records(query, args) do
    query
    |> limit(^(args.limit + 1))
    |> offset(^args.offset)
    |> Repo.all
  end

  def from_slice_updated(records, args) do
    opts =
      Keyword.put([], :has_previous_page, args.offset > 0)
      |> Keyword.put(:has_next_page, length(records) > args.limit)

    Connection.from_slice(Enum.take(records, args.limit), args.offset, opts)
  end

  def prepare_connection_args(args, opts) do
    Map.take(args, [:after, :before, :first, :last])
    |> populate_pagination_args(opts)
  end

  def populate_pagination_args(args, opts) do
    with {:ok, offset, limit} = Connection.offset_and_limit_for_query(args, opts) do
      %{offset: offset, limit: limit}
    end
  end
end
