defmodule NookWeb.UserLive.Login do
  use NookWeb, :live_view

  alias Nook.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <Layouts.auth_frame title="Welcome back" subtitle={if @current_scope, do: "Confirm your login to change account settings.", else: "Log in to open your saved boards."}>
        <.google_sign_in />

        <div :if={Nook.GoogleAuth.email_enabled?() && local_mail_adapter?()} class="alert alert-info">
          <.icon name="hero-information-circle" class="size-6 shrink-0" />
          <div>
            <p>This local version keeps account emails in a preview inbox.</p>
            <p>
              <.link href="/dev/mailbox" class="underline">Open preview inbox</.link> to confirm your account or use a login link.
            </p>
          </div>
        </div>

        <.form
          :let={f}
          for={@form}
          :if={Nook.GoogleAuth.email_enabled?()}
          id="login_form_magic"
          action={~p"/users/log-in"}
          phx-submit="submit_magic"
        >
          <.input
            readonly={!!@current_scope}
            field={f[:email]}
            type="email"
            label="Email"
            autocomplete="username"
            spellcheck="false"
            required
            phx-mounted={JS.focus()}
          />
          <.button class="btn btn-primary w-full">
            Log in with email <span aria-hidden="true">→</span>
          </.button>
        </.form>

        <div :if={Nook.GoogleAuth.email_enabled?()} class="divider">or</div>

        <.form
          :let={f}
          for={@form}
          :if={Nook.GoogleAuth.email_enabled?()}
          id="login_form_password"
          action={~p"/users/log-in"}
          phx-submit="submit_password"
          phx-trigger-action={@trigger_submit}
        >
          <.input
            readonly={!!@current_scope}
            field={f[:email]}
            type="email"
            label="Email"
            autocomplete="username"
            spellcheck="false"
            required
          />
          <.input
            field={@form[:password]}
            type="password"
            label="Password"
            autocomplete="current-password"
            spellcheck="false"
          />
          <.button class="btn btn-primary w-full" name={@form[:remember_me].name} value="true">
            Log in and stay logged in <span aria-hidden="true">→</span>
          </.button>
          <.button class="btn btn-primary btn-soft w-full mt-2">
            Log in only this time
          </.button>
        </.form>
        <p class="studio-auth-link">New to Nook? <.link navigate={~p"/users/register"}>Sign up</.link></p>
        <p class="studio-auth-link"><a href="/">Continue without an account</a></p>
      </Layouts.auth_frame>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    email =
      Phoenix.Flash.get(socket.assigns.flash, :email) ||
        get_in(socket.assigns, [:current_scope, Access.key(:user), Access.key(:email)])

    form = to_form(%{"email" => email}, as: "user")

    {:ok, assign(socket, form: form, trigger_submit: false)}
  end

  @impl true
  def handle_event("submit_password", _params, socket) do
    {:noreply, assign(socket, :trigger_submit, true)}
  end

  def handle_event("submit_magic", %{"user" => %{"email" => email}}, socket) do
    user = if Nook.GoogleAuth.email_enabled?(), do: Accounts.get_user_by_email(email)

    if user do
      Accounts.deliver_login_instructions(
        user,
        &url(~p"/users/log-in/#{&1}")
      )
    end

    info =
      "If your email is in our system, you will receive instructions for logging in shortly."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> push_navigate(to: ~p"/users/log-in")}
  end

  defp local_mail_adapter? do
    Application.get_env(:nook, Nook.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
