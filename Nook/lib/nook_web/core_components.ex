defmodule NookWeb.CoreComponents do
  use Phoenix.Component
  attr(:id, :string, default: "google-sign-in")

  def google_sign_in(assigns) do
    assigns = assign(assigns, :enabled, Nook.GoogleAuth.configured?())

    ~H"""
    <.form :if={@enabled} for={%{}} action="/auth/google" method="post" id={@id}>
      <button class="google-sign-in" type="submit"><img src="/assets/google-g.png" width="20" height="20" alt="" aria-hidden="true" /> Continue with Google</button>
      <p class="google-sign-in-note">Use your Google account. No Nook password or email link needed.</p>
    </.form>
    """
  end

  attr(:field, Phoenix.HTML.FormField, default: nil)
  attr(:id, :string, default: nil)
  attr(:name, :string, default: nil)
  attr(:value, :any, default: nil)
  attr(:type, :string, default: "text")
  attr(:label, :string, default: nil)
  attr(:errors, :list, default: [])

  attr(:rest, :global,
    include:
      ~w(autocomplete disabled form max maxlength min minlength multiple pattern placeholder readonly required spellcheck step)
  )

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(
      field: nil,
      id: assigns.id || field.id,
      name: assigns.name || field.name,
      value: field.value,
      errors: Enum.map(errors, &translate_error/1)
    )
    |> input()
  end

  def input(assigns) do
    ~H"""
    <div class="form-field">
      <label :if={@label} for={@id}>{@label}</label>
      <input type={@type} name={@name} id={@id} value={Phoenix.HTML.Form.normalize_value(@type, @value)} aria-invalid={@errors != [] && "true"} {@rest} />
      <p :for={error <- @errors} class="field-error">{error}</p>
    </div>
    """
  end

  attr(:variant, :string, default: "primary")
  attr(:class, :any, default: nil)
  attr(:rest, :global, include: ~w(disabled form name type value))
  slot(:inner_block, required: true)

  def button(assigns) do
    ~H"""
    <button class={["primary", @class]} {@rest}>{render_slot(@inner_block)}</button>
    """
  end

  slot(:inner_block, required: true)
  slot(:subtitle)

  def header(assigns) do
    ~H"""
    <header class="auth-heading"><h1>{render_slot(@inner_block)}</h1><p :if={@subtitle != []}>{render_slot(@subtitle)}</p></header>
    """
  end

  attr(:name, :string, required: true)
  attr(:class, :any, default: nil)

  def icon(assigns) do
    ~H"""
    <span class={@class} aria-hidden="true">ⓘ</span>
    """
  end

  def translate_error({message, opts}) do
    Enum.reduce(opts, message, fn {key, value}, text ->
      if String.contains?(text, "%{#{key}}"),
        do: String.replace(text, "%{#{key}}", to_string(value)),
        else: text
    end)
  end
end
