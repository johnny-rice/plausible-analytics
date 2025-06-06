defmodule PlausibleWeb.Live.TeamSetup do
  @moduledoc """
  LiveView for Team setup
  """

  use PlausibleWeb, :live_view

  alias Plausible.Repo
  alias Plausible.Teams
  alias Plausible.Teams.Management.Layout
  alias PlausibleWeb.Router.Helpers, as: Routes

  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user
    current_team = socket.assigns.current_team

    socket =
      case current_team do
        %Teams.Team{setup_complete: true} ->
          socket
          |> put_flash(:success, "Your team is now created")
          |> redirect(to: Routes.settings_path(socket, :team_general))

        %Teams.Team{} ->
          team_name_form =
            current_team
            |> Teams.Team.name_changeset(%{name: "#{current_user.name}'s Team"})
            |> Repo.update!()
            |> Teams.Team.name_changeset(%{})
            |> to_form()

          layout = Layout.init(current_team)

          assign(socket,
            team_name_form: team_name_form,
            team_layout: layout,
            current_team: current_team
          )

        _ ->
          socket
          |> put_flash(:error, "You cannot create any team just yet")
          |> redirect(to: Routes.site_path(socket, :index))
      end

    socket =
      if current_team do
        {:ok, my_role} = Teams.Memberships.team_role(current_team, current_user)
        assign(socket, my_role: my_role)
      else
        socket
      end

    {:ok, socket}
  end

  def render(assigns) do
    assigns = assign(assigns, :locked?, Plausible.Teams.Billing.solo?(assigns.current_team))

    ~H"""
    <.focus_box padding?={false}>
      <:title>
        <div class="pt-8 px-8 flex justify-between">
          <div>Create a new team</div>
          <div class="ml-auto">
            <.docs_info slug="users-roles" />
          </div>
        </div>
      </:title>
      <:subtitle>
        <p class="px-8">
          Name your team, add team members and assign roles. When ready, click "Create Team" to send invitations
        </p>
      </:subtitle>

      <div class="relative -mt-8 pt-4 pb-8 px-8">
        <PlausibleWeb.Components.Billing.feature_gate
          current_role={@current_team_role}
          current_team={@current_team}
          locked?={@locked?}
        >
          <.form
            :let={f}
            for={@team_name_form}
            method="post"
            phx-change="update-team"
            phx-blur="update-team"
            id="update-team-form"
            class="mt-4 mb-8"
          >
            <.input
              type="text"
              placeholder={"#{@current_user.name}'s Team"}
              autofocus={not @locked?}
              field={f[:name]}
              label="Name"
              width="w-full"
              phx-debounce="500"
            />
          </.form>

          <.label class="mb-2">
            Team Members
          </.label>
          {live_render(@socket, PlausibleWeb.Live.TeamManagement,
            id: "team-management-setup",
            container: {:div, id: "team-setup"},
            session: %{
              "mode" => "team-setup"
            }
          )}
        </PlausibleWeb.Components.Billing.feature_gate>
      </div>
    </.focus_box>
    """
  end

  def handle_event("update-team", %{"team" => %{"name" => name}}, socket) do
    changeset = Teams.Team.name_changeset(socket.assigns.current_team, %{name: name})

    socket =
      case Repo.update(changeset) do
        {:ok, team} ->
          assign(socket, team_name_form: to_form(changeset), current_team: team)

        {:error, changeset} ->
          assign(socket, team_name_form: to_form(changeset))
      end

    {:noreply, socket}
  end
end
