defmodule VigiaWeb.PainelLive do
  @moduledoc """
  O painel assina o tópico do espaço e, a cada leitura, reenvia só o cartão do
  alvo que mudou. Cada grupo tem seu stream: o servidor não guarda os cartões
  depois do primeiro render, só o resultado atual de cada alvo para as
  contagens.
  """

  use VigiaWeb, :live_view

  import VigiaWeb.PainelComponents

  alias Vigia.{Avisos, Inscricoes, Leitura, Monitor, Push, Resumo, Verificador}

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
       avisos: espaco == :real and Push.configurado?(),
       avisos_ativos: false,
       chave_vapid: Push.chave_publica(),
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
  def handle_event(_evento, _params, %{assigns: %{avisos: false}} = socket),
    do: {:noreply, socket}

  def handle_event("avisos_estado", %{"ativo" => ativo}, socket),
    do: {:noreply, assign(socket, avisos_ativos: ativo == true)}

  def handle_event("inscrever", inscricao, socket) do
    case Inscricoes.adicionar(inscricao) do
      :ok ->
        Avisos.testar()
        {:noreply, socket |> assign(avisos_ativos: true) |> put_flash(:info, "Avisos ativados.")}

      {:error, :invalida} ->
        {:noreply, put_flash(socket, :error, "O navegador mandou uma inscrição inválida.")}
    end
  end

  def handle_event("testar", _params, socket) do
    Avisos.testar()
    {:noreply, put_flash(socket, :info, "Aviso de teste enviado.")}
  end

  def handle_event("avisos_negados", _params, socket) do
    {:noreply, put_flash(socket, :error, "Permissão de notificação negada no navegador.")}
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
        <div :if={@espaco == :real} class="flex items-center gap-4">
          <button
            :if={@avisos}
            id="avisos"
            type="button"
            phx-hook=".Avisos"
            data-chave={@chave_vapid}
            class="cursor-pointer rounded-lg border border-borda px-3 py-1.5 text-sm hover:border-texto"
          >
            {if @avisos_ativos, do: "Testar aviso", else: "Ativar avisos"}
          </button>
          <script :type={Phoenix.LiveView.ColocatedHook} name=".Avisos">
            const bytes = (b64) => {
              const base = (b64 + "=".repeat((4 - (b64.length % 4)) % 4)).replace(/-/g, "+").replace(/_/g, "/")
              return Uint8Array.from(atob(base), (c) => c.charCodeAt(0))
            }

            export default {
              async mounted() {
                if (!("serviceWorker" in navigator) || !("PushManager" in window)) {
                  this.el.hidden = true
                  return
                }
                const registro = await navigator.serviceWorker.register("/sw.js")
                const inscricao = await registro.pushManager.getSubscription()
                this.pushEvent("avisos_estado", {ativo: inscricao !== null})
                this.el.addEventListener("click", () => this.alternar())
              },

              async alternar() {
                const registro = await navigator.serviceWorker.ready
                if (await registro.pushManager.getSubscription()) {
                  this.pushEvent("testar", {})
                  return
                }
                if ((await Notification.requestPermission()) !== "granted") {
                  this.pushEvent("avisos_negados", {})
                  return
                }
                const inscricao = await registro.pushManager.subscribe({
                  userVisibleOnly: true,
                  applicationServerKey: bytes(this.el.dataset.chave),
                })
                this.pushEvent("inscrever", inscricao.toJSON())
              },
            }
          </script>
          <.link
            href={~p"/sair"}
            method="delete"
            class="text-sm text-suave underline underline-offset-2 hover:text-texto"
          >
            Sair
          </.link>
        </div>
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
