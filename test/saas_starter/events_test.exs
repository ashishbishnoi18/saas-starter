defmodule SaasStarter.EventsTest do
  use SaasStarter.DataCase, async: true

  alias SaasStarter.Events
  alias SaasStarter.Events.Event

  import SaasStarter.AccountsFixtures

  describe "track/3" do
    test "inserts a row with nil user_id when user is nil" do
      assert {:ok, %Event{} = event} = Events.track(nil, "page.view", %{path: "/"})

      assert event.event_name == "page.view"
      assert event.user_id == nil
      assert event.metadata == %{"path" => "/"}
    end

    test "records user_id when a user is provided" do
      user = user_fixture()

      assert {:ok, %Event{user_id: user_id}} = Events.track(user, "auth.login", %{})
      assert user_id == user.id
    end

    test "rejects empty event_name" do
      assert {:error, changeset} = Events.track(nil, "", %{})
      assert %{event_name: [_ | _]} = errors_on(changeset)
    end

    test "defaults metadata to empty map" do
      assert {:ok, %Event{metadata: %{}}} = Events.track(nil, "ping")
    end
  end

  describe "count/1 and list_recent/1" do
    test "count returns the number of events matching event_name" do
      for _ <- 1..3, do: Events.track(nil, "foo", %{})
      Events.track(nil, "bar", %{})

      assert Events.count("foo") == 3
      assert Events.count("bar") == 1
      assert Events.count("never") == 0
    end

    test "list_recent returns newest first up to limit" do
      {:ok, _} = Events.track(nil, "a", %{})
      Process.sleep(5)
      {:ok, _} = Events.track(nil, "b", %{})
      Process.sleep(5)
      {:ok, _} = Events.track(nil, "c", %{})

      assert [%{event_name: "c"}, %{event_name: "b"}] = Events.list_recent(2)
    end
  end
end
