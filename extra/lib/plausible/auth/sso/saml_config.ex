defmodule Plausible.Auth.SSO.SAMLConfig do
  @moduledoc """
  SAML SSO can be configured in two ways - by either providing IdP
  metadata XML or inputting required data one by one.

  If metadata is provided, the parameters are extracted but the
  original metadata is preserved as well. This might be helpful
  when updating configuration in the future to enable some other
  feature like Single Logout without having to re-fetch metadata
  from IdP again.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t() :: %__MODULE__{}

  @fields [:idp_signin_url, :idp_entity_id, :idp_cert_pem, :idp_metadata]
  @required_fields @fields -- [:idp_metadata]

  embedded_schema do
    field :idp_signin_url, :string
    field :idp_entity_id, :string
    field :idp_cert_pem, :string
    field :idp_metadata, :string
  end

  def changeset(struct, params) do
    struct
    |> cast(params, @fields)
  end

  def update_changeset(struct, params) do
    struct
    |> cast(params, @fields)
    |> validate_required(@required_fields)
    |> validate_url(:idp_signin_url)
    |> validate_pem(:idp_cert_pem)
  end

  defp validate_url(changeset, field) do
    if url = get_change(changeset, field) do
      case URI.new(url) do
        {:ok, uri} when uri.scheme in ["http", "https"] -> changeset
        _ -> add_error(changeset, field, "invalid URL", validation: :url)
      end
    else
      changeset
    end
  end

  defp validate_pem(changeset, field) do
    if pem = get_change(changeset, field) do
      case X509.Certificate.from_pem(pem) do
        {:ok, _cert} -> changeset
        {:error, _} -> add_error(changeset, field, "invalid certificate", validation: :cert_pem)
      end
    else
      changeset
    end
  end
end
