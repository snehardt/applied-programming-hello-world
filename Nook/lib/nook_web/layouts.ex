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
