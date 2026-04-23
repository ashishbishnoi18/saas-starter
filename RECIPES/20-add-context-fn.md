# Add a context function (with tests)

A minimal checklist. Treat every public context function as a contract that
tests pin down.

## Pattern

1. Function lives in the right context module (`lib/saas_starter/<context>.ex`).
2. Public functions start with a `@doc` and `@spec`.
3. The function does **one** thing. If it's orchestrating several steps,
   break the steps into private helpers.
4. A test file at `test/saas_starter/<context>_test.exs` covers:
   - Happy path
   - Each validation / error branch
   - Side effects (DB rows, telemetry events, email sent)

## Example: add `Accounts.deactivate_user/1`

```elixir
# lib/saas_starter/accounts.ex
@doc """
Soft-deletes a user by setting `deactivated_at`. Idempotent.
"""
@spec deactivate_user(User.t()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
def deactivate_user(%User{} = user) do
  user
  |> Ecto.Changeset.change(deactivated_at: DateTime.utc_now(:second))
  |> Repo.update()
end
```

```elixir
# test/saas_starter/accounts_test.exs — add to existing describe blocks
describe "deactivate_user/1" do
  test "sets deactivated_at" do
    user = user_fixture()
    assert {:ok, %User{deactivated_at: ts}} = Accounts.deactivate_user(user)
    assert ts
  end

  test "is idempotent" do
    user = user_fixture()
    assert {:ok, %User{deactivated_at: ts1}} = Accounts.deactivate_user(user)
    Process.sleep(1)
    assert {:ok, %User{deactivated_at: ts2}} = Accounts.deactivate_user(user)
    assert DateTime.after?(ts2, ts1)
  end
end
```

## Telemetry

If the function represents a user-facing event, emit telemetry and let
`SaasStarter.Events.TelemetryHandler` persist it. Don't call
`SaasStarter.Events.track/3` directly from contexts except for events
that don't fit a telemetry handler:

```elixir
:telemetry.execute(
  [:saas_starter, :accounts, :user_deactivated],
  %{},
  %{user_id: user.id}
)
```

Add a handler in `SaasStarter.Events.TelemetryHandler`:

```elixir
@events [
  ...,
  [:saas_starter, :accounts, :user_deactivated]
]

def handle_event([:saas_starter, :accounts, :user_deactivated], _m, meta, _c) do
  track_async(nil, "accounts.user_deactivated", meta)
end
```

Then add a test asserting the `product_events` row exists.

## Forbidden

- **Never** call `Repo.insert/1` / `Repo.update/1` from a LiveView or
  controller. Go through a context function.
- **Never** mass-assign FK fields like `user_id` via `cast/3`. Set them
  explicitly on the struct.
- **Never** skip tests because "it's a simple function." Simple functions
  are where subtle bugs hide.
