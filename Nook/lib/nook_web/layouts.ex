defmodule NookWeb.Layouts do
  use Phoenix.Component
  embed_templates("layouts/*")
  attr(:current_scope, :any, default: nil)

  def account_nav(assigns) do
    ~H"""
    <nav class="account-nav" aria-label="Account">
      <%= if @current_scope do %>
        <span class="account-email" title={@current_scope.user.email}>{@current_scope.user.email}</span>
        <a href="/dashboard">My boards</a><a href="/users/settings">Settings</a>
        <form action="/users/log-out" method="post"><input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} /><input type="hidden" name="_method" value="delete" /><button type="submit">Log out</button></form>
      <% else %>
        <a href="/users/log-in">Log in</a><a href="/users/register">Create account</a>
      <% end %>
    </nav>
    """
  end

  attr(:title, :string, required: true)
  attr(:subtitle, :string, default: "")
  slot(:inner_block, required: true)

  def auth_frame(assigns) do
    ~H"""
    <section class="studio-auth">
      <aside class="studio-auth-art" aria-hidden="true"><img src="/assets/nook-logo.png" alt="" /><svg viewBox="0 0 320 260" fill="none"><rect x="25" y="58" width="126" height="94" rx="3" transform="rotate(-5 25 58)" /><path d="M48 83h65M48 103h45M48 124h56M135 171c34-48 69-47 113-52m-19-9 20 9-17 12"/><circle cx="257" cy="68" r="31"/><path d="m268 17 6-16m17 26 13-12"/></svg></aside>
      <div class="studio-auth-form"><h1>{@title}</h1><p class="studio-subtitle">{@subtitle}</p>{render_slot(@inner_block)}</div>
    </section>
    """
  end

  attr(:flash, :map, default: %{})
  attr(:current_scope, :any, default: nil)
  slot(:inner_block, required: true)

  def app(assigns) do
    ~H"""
    <header class="account-header"><a href="/" aria-label="Nook home"><img class="brand" src="/assets/nook-logo.png" alt="Nook" /></a><.account_nav current_scope={@current_scope} /></header>
    <div class="flash-messages" aria-live="polite"><p :for={{kind, message} <- @flash} class={"flash #{kind}"}>{message}</p></div>
    <main class="account-main">{render_slot(@inner_block)}</main>
    """
  end
end
