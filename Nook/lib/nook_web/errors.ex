defmodule NookWeb.ErrorHTML do
  use Phoenix.Component

  def render(template, _assigns) do
    assigns = %{message: Phoenix.Controller.status_message_from_template(template)}

    ~H"""
    <!doctype html>
    <html lang="en"><head><meta charset="utf-8" /><meta name="viewport" content="width=device-width, initial-scale=1" /><title>{@message} — Nook</title><link rel="stylesheet" href="/assets/app.css" /><link rel="stylesheet" href="/assets/polish.css" /></head><body><main class="error-page"><img class="brand" src="/assets/nook-logo.png" alt="Nook" /><h1>{@message}</h1><p>We couldn’t open this page. Your saved boards are still there.</p><a href="/">Back to home</a> · <a href="/dashboard">My boards</a></main></body></html>
    """
  end
end

defmodule NookWeb.ErrorJSON do
  def render(template, _assigns),
    do: %{error: Phoenix.Controller.status_message_from_template(template)}
end
