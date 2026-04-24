defmodule SaasStarter.Accounts.User do
  @moduledoc """
  User schema. v0.1 supports magic-link and Google OAuth sign-in only —
  no password. The `hashed_password` column is kept nullable so a future
  project can reinstate password login without a migration; the related
  schema functions and the `bcrypt_elixir` dep are not shipped.

  Changesets:

    * `email_changeset/3` — updates the email; requires the value to
      change. Used by `phx.gen.auth`-derived email-update flow.
    * `oauth_changeset/2` — creates/updates a user from an OAuth
      provider callback. Auto-confirms (providers do email verification).
    * `confirm_changeset/1` — marks a magic-link-confirmed user.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :email, :string
    field :hashed_password, :string, redact: true
    field :confirmed_at, :utc_datetime
    field :authenticated_at, :utc_datetime, virtual: true
    # Google OAuth subject identifier (the stable `sub` claim). Nullable —
    # only set for users who signed in via Google. A single user may have
    # both a google_sub and a magic-link tokens history.
    field :google_sub, :string

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for registering or changing the email. Requires the email
  to change (vs the current value) when called for an update.

  ## Options

    * `:validate_unique` — set to false to skip DB uniqueness checks
      (useful for live form validation). Defaults to true.
  """
  def email_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email])
    |> validate_email(opts)
  end

  defp validate_email(changeset, opts) do
    changeset =
      changeset
      |> validate_required([:email])
      |> validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
        message: "must have the @ sign and no spaces"
      )
      |> validate_length(:email, max: 160)

    if Keyword.get(opts, :validate_unique, true) do
      changeset
      |> unsafe_validate_unique(:email, SaasStarter.Repo)
      |> unique_constraint(:email)
      |> validate_email_changed()
    else
      changeset
    end
  end

  defp validate_email_changed(changeset) do
    if get_field(changeset, :email) && get_change(changeset, :email) == nil do
      add_error(changeset, :email, "did not change")
    else
      changeset
    end
  end

  @doc "Confirms the account by setting `confirmed_at`."
  def confirm_changeset(user) do
    now = DateTime.utc_now(:second)
    change(user, confirmed_at: now)
  end

  @doc """
  Changeset for creating/updating a user from an OAuth provider callback.

  Google is the only provider wired in v0.1. The `sub` claim is stored
  in `google_sub`; email is trusted because Google's callback only
  returns verified emails. The user is auto-confirmed — OAuth providers
  do the email-verification step for us.
  """
  def oauth_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :google_sub])
    |> validate_required([:email, :google_sub])
    |> validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+$/)
    |> validate_length(:email, max: 160)
    |> unique_constraint(:email)
    |> unique_constraint(:google_sub)
    |> put_confirmed_now()
  end

  defp put_confirmed_now(changeset) do
    if get_field(changeset, :confirmed_at) do
      changeset
    else
      put_change(changeset, :confirmed_at, DateTime.utc_now(:second))
    end
  end
end
