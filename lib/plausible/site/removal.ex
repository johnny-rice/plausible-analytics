defmodule Plausible.Site.Removal do
  @moduledoc """
  A site deletion service stub.
  """
  use Plausible

  alias Plausible.Repo
  alias Plausible.Teams

  import Ecto.Query

  @spec run(Plausible.Site.t()) :: {:ok, map()}
  def run(site) do
    Repo.transaction(fn ->
      site = Repo.preload(site, :team)

      result = Repo.delete_all(from(s in Plausible.Site, where: s.domain == ^site.domain))

      Teams.Memberships.prune_guests(site.team)
      Teams.Invitations.prune_guest_invitations(site.team)

      on_ee do
        Plausible.Billing.SiteLocker.update_for(site.team, send_email?: false)
      end

      %{delete_all: result}
    end)
  end
end
