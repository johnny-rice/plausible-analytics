defmodule PlausibleWeb.Api.Internal.SegmentsController do
  @moduledoc """
  Internal API controller for segments.
  """
  use Plausible
  use PlausibleWeb, :controller
  use PlausibleWeb.Plugs.ErrorHandler
  alias PlausibleWeb.Api.Helpers, as: H
  alias Plausible.Segments

  def create(
        %Plug.Conn{
          assigns: %{
            site: site,
            current_user: %{id: user_id},
            site_role: site_role
          }
        } = conn,
        %{} = params
      ) do
    case Segments.insert_one(user_id, site, site_role, params) do
      {:error, :not_enough_permissions} ->
        H.not_enough_permissions(conn, "Not enough permissions to create segment")

      {:error, :segment_limit_reached} ->
        H.not_enough_permissions(conn, "Segment limit reached")

      {:error, {:invalid_segment, errors}} when is_list(errors) ->
        conn
        |> put_status(400)
        |> json(%{
          error: Segments.serialize_first_error(errors)
        })

      {:ok, segment} ->
        json(conn, segment)
    end
  end

  def create(%Plug.Conn{} = conn, _params), do: invalid_request(conn)

  def update(
        %Plug.Conn{
          assigns: %{
            site: site,
            current_user: %{id: user_id},
            site_role: site_role
          }
        } =
          conn,
        %{} = params
      ) do
    segment_id = normalize_segment_id_param(params["segment_id"])

    case Segments.update_one(user_id, site, site_role, segment_id, params) do
      {:error, :not_enough_permissions} ->
        H.not_enough_permissions(conn, "Not enough permissions to edit segment")

      {:error, :segment_not_found} ->
        segment_not_found(conn, params["segment_id"])

      {:error, {:invalid_segment, errors}} when is_list(errors) ->
        conn
        |> put_status(400)
        |> json(%{
          error: Segments.serialize_first_error(errors)
        })

      {:ok, segment} ->
        json(conn, segment)
    end
  end

  def update(%Plug.Conn{} = conn, _params), do: invalid_request(conn)

  def delete(
        %Plug.Conn{
          assigns: %{
            site: site,
            current_user: %{id: user_id},
            site_role: site_role
          }
        } =
          conn,
        %{} = params
      ) do
    segment_id = normalize_segment_id_param(params["segment_id"])

    case Segments.delete_one(user_id, site, site_role, segment_id) do
      {:error, :not_enough_permissions} ->
        H.not_enough_permissions(conn, "Not enough permissions to delete segment")

      {:error, :segment_not_found} ->
        segment_not_found(conn, params["segment_id"])

      {:ok, segment} ->
        json(conn, segment)
    end
  end

  def delete(%Plug.Conn{} = conn, _params), do: invalid_request(conn)

  @spec normalize_segment_id_param(any()) :: nil | pos_integer()
  defp normalize_segment_id_param(input) do
    case Integer.parse(input) do
      {int_value, ""} when int_value > 0 -> int_value
      _ -> nil
    end
  end

  defp segment_not_found(%Plug.Conn{} = conn, segment_id_param) do
    H.not_found(conn, "Segment not found with ID #{inspect(segment_id_param)}")
  end

  defp invalid_request(%Plug.Conn{} = conn) do
    H.bad_request(conn, "Invalid request")
  end
end
