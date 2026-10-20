defmodule VigiaWeb.PainelLive do
  @moduledoc """
  O painel assina o tópico do espaço e, a cada leitura, reenvia só o cartão do
  alvo que mudou. Os cartões ficam num stream: o servidor não guarda a lista
  depois do primeiro render.
  """

  use VigiaWeb, :live_view

  import VigiaWeb.PainelComponents

  alias Vigia.{Leitura, Monitor, Resumo, Verificador}

  @impl true
  def mount(_params, _session, socket) do
    espaco = socket.assigns.espaco
    if connected?(socket), do: Phoenix.PubSub.subscribe(Vigia.PubSub, Verificador.topico(espaco))

    resumos = espaco |> Monitor.alvos() |> Enum.map(&Resumo.de/1)

    {:ok,
     socket
     |> assign(
       espaco: espaco,
       page_title: "Painel",
       vazio: resumos == []
     )
     |> com_resultados(Map.new(resumos, &{&1.id, &1.resultado}))
     |> stream(:alvos, resumos)}
  end

  @impl true
  def handle_info({:leitura, %Leitura{alvo_id: id}}, socket) do
    case Monitor.alvo(id) do
      nil ->
        {:noreply, socket}

      alvo ->
        resumo = Resumo.de(alvo)

        {:noreply,
         socket
         |> stream_insert(:alvos, resumo)
         |> com_resultados(Map.put(socket.assigns.resultados, id, resumo.resultado))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <header class="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 class="flex items-center gap-2 text-xl font-semibold tracking-tight">
            Vigia
            <span
              :if={@espaco == :demo}
              class="rounded-md border border-borda px-1.5 py-0.5 text-xs font-normal text-suave"
            >
              demonstração
            </span>
          </h1>
          <p class="mt-1 text-sm text-suave">
            <span class="font-mono text-texto">{@contagem.no_ar}</span>
            de <span class="font-mono text-texto">{@contagem.total}</span>
            no ar<span :if={@contagem.fora > 0}>
              · <span class="font-mono text-fora">{@contagem.fora}</span> fora
            </span>
          </p>
        </div>
        <.link
          :if={@espaco == :demo and @login_habilitado}
          href={~p"/entrar"}
          class="text-sm text-suave underline underline-offset-2 hover:text-texto"
        >
          Entrar
        </.link>
        <.link
          :if={@espaco == :real}
          href={~p"/sair"}
          method="delete"
          class="text-sm text-suave underline underline-offset-2 hover:text-texto"
        >
          Sair
        </.link>
      </header>

      <p :if={@vazio} class="mt-10 text-sm text-suave">
        Nenhum alvo configurado. Defina <code class="font-mono">VIGIA_ALVOS</code>.
      </p>

      <section
        id="alvos"
        phx-update="stream"
        class="mt-6 grid gap-3 sm:grid-cols-2 lg:grid-cols-3"
      >
        <.cartao :for={{dom_id, resumo} <- @streams.alvos} id={dom_id} resumo={resumo} />
      </section>

      <footer class="mt-10 text-xs text-suave">
        Elixir, OTP e Phoenix LiveView ·
        <a href="https://github.com/br1ansouza/vigia" class="underline underline-offset-2">
          código
        </a>
      </footer>
    </Layouts.app>
    """
  end

  defp com_resultados(socket, resultados) do
    assign(socket, resultados: resultados, contagem: Resumo.contagem(Map.values(resultados)))
  end
end
