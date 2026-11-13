defmodule Nook.Application do
  use Application

  def start(_type, _args) do
    Supervisor.start_link(
      [
        Nook.Repo,
        {Phoenix.PubSub, name: Nook.PubSub},
        Nook.RateLimit,
        Nook.Boards,
        NookWeb.Presence,
        NookWeb.Endpoint
      ] ++ if(Application.get_env(:nook, :expiry_worker, true), do: [Nook.GuestExpiry], else: []),
      strategy: :one_for_one,
      name: Nook.Supervisor
    )
  end
end
