defmodule Nook.GoogleAccountsTest do
  use Nook.DataCase, async: true
  alias Nook.Accounts
  import Nook.AccountsFixtures
  defp claims(sub, email), do: %{"sub" => sub, "email" => email, "email_verified" => true}

  test "verified Google login creates a confirmed account without a password or email" do
    assert {:ok, user} =
             Accounts.sign_in_with_google(claims("google-sub", "new@example.com"), nil)

    assert user.google_sub == "google-sub"
    assert user.confirmed_at
    assert is_nil(user.hashed_password)

    assert {:ok, same} =
             Accounts.sign_in_with_google(claims("google-sub", "changed@example.com"), nil)

    assert same.id == user.id
    assert same.email == "new@example.com"
    refute_received {:email, _}
  end

  test "email coincidence never takes over an existing account" do
    existing = user_fixture()

    assert {:error, :link_required} =
             Accounts.sign_in_with_google(claims("attacker", existing.email), nil)

    assert is_nil(Accounts.get_user!(existing.id).google_sub)

    assert {:error, :invalid_identity} =
             Accounts.sign_in_with_google(
               %{"sub" => "bad", "email" => existing.email, "email_verified" => false},
               nil
             )
  end

  test "linking requires recent sign-in to that same confirmed Nook account" do
    user = user_fixture()

    assert {:error, :link_required} =
             Accounts.sign_in_with_google(claims("linked", user.email), %{
               user
               | authenticated_at: nil
             })

    recent = %{user | authenticated_at: NaiveDateTime.utc_now(:second)}
    assert {:ok, linked} = Accounts.sign_in_with_google(claims("linked", user.email), recent)
    assert linked.id == user.id

    assert {:error, :link_required} =
             Accounts.sign_in_with_google(claims("other", user.email), recent)

    other = user_fixture()

    assert {:error, :link_required} =
             Accounts.sign_in_with_google(claims("linked", user.email), other)
  end
end
