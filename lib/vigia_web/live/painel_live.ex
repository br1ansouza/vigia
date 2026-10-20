defmodule VigiaWeb.PainelLive do
  @moduledoc """
  O painel assina o tópico do espaço e, a cada leitura, reenvia só o cartão do
  alvo que mudou. Cada grupo tem seu stream: o servidor não guarda os cartões
  depois do primeiro render, só o resultado atual de cada alvo para as
  contagens.
  """

  use VigiaWeb, :live_view

  import VigiaWeb.PainelComponents

  alias Vigia.{Leitura, Monitor, Resumo, Verificador}

  @impl true
  def mount(_params, _session, socket) do
    espaco = socket.assigns.espaco
    if connected?(socket), do: Phoenix.PubSub.subscribe(Vigia.PubSub, Verificador.topico(espaco))

    grupos =
      espaco
      |> Monitor.grupos()
      |> Enum.with_index(fn {nome, alvos}, i ->
        %{nome: nome, chave: String.to_atom("grupo_#{i}"), resumos: Enum.map(alvos, &Resumo.de/1)}
      end)

    socket =
      Enum.reduce(grupos, socket, fn grupo, socket ->
        stream(socket, grupo.chave, grupo.resumos)
      end)

    {:ok,
     socket
     |> assign(
       espaco: espaco,
       page_title: "Painel",
       vazio: grupos == [],
       grupos:
         Enum.map(
           grupos,
           &%{nome: &1.nome, chave: &1.chave, ids: Enum.map(&1.resumos, fn r -> r.id end)}
         ),
       grupo_de: for(g <- grupos, r <- g.resumos, into: %{}, do: {r.id, g.chave})
     )
     |> com_resultados(for g <- grupos, r <- g.resumos, into: %{}, do: {r.id, r.resultado})}
  end

  @impl true
  def handle_info({:leitura, %Leitura{alvo_id: id}}, socket) do
    with %{} = alvo <- Monitor.alvo(id),
         {:ok, chave} <- Map.fetch(socket.assigns.grupo_de, id) do
      resumo = Resumo.de(alvo)

      {:noreply,
       socket
       |> stream_insert(chave, resumo)
       |> com_resultados(Map.put(socket.assigns.resultados, id, resumo.resultado))}
    else
      _ -> {:noreply, socket}
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
          :if={@espaco == :real}
          href={~p"/sair"}
          method="delete"
          class="text-sm text-suave underline underline-offset-2 hover:text-texto"
        >
          Sair
        </.link>
      </header>

      <div
        :if={@espaco == :demo}
        class="mt-5 flex flex-wrap items-center justify-between gap-3 rounded-xl border border-destaque/40 bg-destaque/8 px-4 py-3 text-sm"
      >
        <p>
          Dados fictícios de demonstração, simulados pelo próprio Vigia.
          <span :if={@login_habilitado}>Entre para ver os serviços reais.</span>
        </p>
        <.link
          :if={@login_habilitado}
          href={~p"/entrar"}
          class="rounded-lg bg-texto px-3 py-1.5 text-sm font-medium text-fundo hover:opacity-90"
        >
          Entrar
        </.link>
      </div>

      <p :if={@vazio} class="mt-10 text-sm text-suave">
        Nenhum alvo configurado. Defina <code class="font-mono">VIGIA_ALVOS</code>.
      </p>

      <section :for={grupo <- @grupos} class="mt-8">
        <header class="mb-3 flex items-baseline justify-between gap-3">
          <h2 class="text-sm font-semibold tracking-tight">{grupo.nome}</h2>
          <p class="text-xs text-suave">
            <span class={[
              "font-mono",
              @contagens[grupo.chave].fora > 0 && "text-fora",
              @contagens[grupo.chave].fora == 0 && "text-texto"
            ]}>
              {@contagens[grupo.chave].no_ar}/{@contagens[grupo.chave].total}
            </span>
            no ar
          </p>
        </header>
        <div
          id={"grupo-#{grupo.chave}"}
          phx-update="stream"
          class="grid gap-3 sm:grid-cols-2 lg:grid-cols-3"
        >
          <.cartao
            :for={{dom_id, resumo} <- Map.fetch!(@streams, grupo.chave)}
            id={dom_id}
            resumo={resumo}
          />
        </div>
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
    contagens =
      Map.new(socket.assigns.grupos, fn grupo ->
        {grupo.chave, grupo.ids |> Enum.map(&Map.fetch!(resultados, &1)) |> Resumo.contagem()}
      end)

    assign(socket,
      resultados: resultados,
      contagem: Resumo.contagem(Map.values(resultados)),
      contagens: contagens
    )
  end
end
