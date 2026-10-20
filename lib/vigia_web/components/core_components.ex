defmodule VigiaWeb.CoreComponents do
  @moduledoc false
  use Phoenix.Component

  alias Phoenix.LiveView.JS

  attr :id, :string
  attr :flash, :map, default: %{}
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error]
  attr :rest, :global

  slot :inner_block

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      class="fixed bottom-4 left-1/2 z-50 w-[min(92vw,24rem)] -translate-x-1/2 cursor-pointer"
      {@rest}
    >
      <div class={[
        "flex items-start gap-3 rounded-lg border bg-superficie px-4 py-3 text-sm shadow-lg",
        @kind == :info && "border-borda",
        @kind == :error && "border-fora/60"
      ]}>
        <.icon :if={@kind == :info} name="hero-information-circle" class="size-5 shrink-0" />
        <.icon :if={@kind == :error} name="hero-exclamation-circle" class="size-5 shrink-0 text-fora" />
        <div>
          <p :if={@title} class="font-medium">{@title}</p>
          <p>{msg}</p>
        </div>
      </div>
    </div>
    """
  end

  attr :name, :string, required: true
  attr :class, :any, default: "size-4"

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 200,
      transition: {"transition ease-out duration-200", "opacity-0", "opacity-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 150,
      transition: {"transition ease-in duration-150", "opacity-100", "opacity-0"}
    )
  end
end
