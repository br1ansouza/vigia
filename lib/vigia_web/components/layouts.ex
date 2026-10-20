defmodule VigiaWeb.Layouts do
  @moduledoc false
  use VigiaWeb, :html

  embed_templates "layouts/*"

  attr :flash, :map, required: true
  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <main class="mx-auto w-full max-w-5xl px-4 py-6 sm:px-6 sm:py-10">
      {render_slot(@inner_block)}
    </main>
    <.flash_group flash={@flash} />
    """
  end

  attr :flash, :map, required: true
  attr :id, :string, default: "flash-group"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />
      <.flash
        id="sem-conexao"
        kind={:error}
        title="Sem conexão"
        phx-disconnected={
          show(".phx-client-error #sem-conexao, .phx-server-error #sem-conexao")
          |> JS.remove_attribute("hidden", to: "#sem-conexao")
        }
        phx-connected={hide("#sem-conexao") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        Reconectando
      </.flash>
    </div>
    """
  end
end
