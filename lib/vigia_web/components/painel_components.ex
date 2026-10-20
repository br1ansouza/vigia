defmodule VigiaWeb.PainelComponents do
  @moduledoc false
  use Phoenix.Component

  alias Vigia.Resumo
  alias VigiaWeb.Formato

  @colunas 60
  @altura 36

  attr :id, :string, required: true
  attr :resumo, Resumo, required: true

  def cartao(assigns) do
    {valor, unidade} = Formato.latencia(assigns.resumo.latencia)
    assigns = assign(assigns, valor: valor, unidade: unidade)

    ~H"""
    <article id={@id} class="flex flex-col rounded-xl border border-borda bg-superficie p-4">
      <header class="flex items-start justify-between gap-3">
        <h3 class="truncate text-sm font-medium">{@resumo.nome}</h3>
        <.selo resultado={@resumo.resultado} />
      </header>

      <div class="mt-3 flex items-baseline justify-between gap-3">
        <p>
          <span class="font-mono text-2xl tabular-nums tracking-tight">{@valor}</span>
          <span :if={@unidade} class="ml-0.5 text-sm text-suave">{@unidade}</span>
        </p>
        <p class="text-xs text-suave">
          <span class="font-mono text-texto">{Formato.porcentagem(@resumo.disponibilidade)}</span>%
          em 24 h
        </p>
      </div>

      <.barras pontos={@resumo.pontos} limite={@resumo.limite_lento} />

      <p class="mt-2 truncate text-xs text-suave">{legenda(@resumo)}</p>
    </article>
    """
  end

  attr :resultado, :atom, required: true

  def selo(assigns) do
    ~H"""
    <span class={[
      "inline-flex shrink-0 items-center gap-1.5 rounded-full px-2 py-0.5 text-xs font-medium",
      cor_selo(@resultado)
    ]}>
      <span class={[
        "size-1.5 rounded-full bg-current",
        @resultado == :fora && "motion-safe:animate-pulse"
      ]} />
      {rotulo(@resultado)}
    </span>
    """
  end

  attr :pontos, :list, required: true
  attr :limite, :integer, default: nil

  def barras(assigns) do
    assigns =
      assign(assigns,
        barras: posicionar(assigns.pontos, assigns.limite),
        vazias: for(i <- 0..(@colunas - length(assigns.pontos) - 1)//1, do: i * 4),
        largura: @colunas * 4,
        altura: @altura
      )

    ~H"""
    <svg
      viewBox={"0 0 #{@largura} #{@altura}"}
      preserveAspectRatio="none"
      class="mt-4 h-9 w-full"
      role="img"
      aria-label={"Últimas #{length(@pontos)} verificações"}
    >
      <rect
        :for={x <- @vazias}
        x={x}
        y={@altura - 3}
        width="3"
        height="3"
        rx="0.75"
        class="fill-borda"
      />
      <rect
        :for={{x, y, h, resultado} <- @barras}
        x={x}
        y={y}
        width="3"
        height={h}
        rx="0.75"
        class={cor_barra(resultado)}
      />
    </svg>
    """
  end

  defp posicionar(pontos, limite) do
    escala = escala(pontos, limite)
    deslocamento = @colunas - length(pontos)

    pontos
    |> Enum.with_index(deslocamento)
    |> Enum.map(fn {{resultado, latencia}, i} ->
      h = altura(resultado, latencia, escala)
      {i * 4, @altura - h, h, resultado}
    end)
  end

  defp escala(pontos, limite) do
    maior = pontos |> Enum.map(&elem(&1, 1)) |> Enum.reject(&is_nil/1) |> Enum.max(fn -> 0 end)
    max(maior, round((limite || 1) * 1.2))
  end

  defp altura(:fora, _, _), do: @altura
  defp altura(_, nil, _), do: @altura
  defp altura(_, latencia, escala), do: (latencia / escala * @altura) |> round() |> max(3)

  defp legenda(%Resumo{resultado: :aguardando}), do: "aguardando a primeira verificação"

  defp legenda(%Resumo{} = resumo) do
    estado = "#{estado(resumo.resultado)} há #{Formato.duracao(resumo.ultima_em - resumo.desde)}"
    if resumo.detalhe, do: "#{estado} · #{resumo.detalhe}", else: estado
  end

  defp estado(:no_ar), do: "no ar"
  defp estado(:lento), do: "lento"
  defp estado(:fora), do: "fora"

  defp rotulo(:no_ar), do: "no ar"
  defp rotulo(:lento), do: "lento"
  defp rotulo(:fora), do: "fora"
  defp rotulo(:aguardando), do: "aguardando"

  defp cor_selo(:no_ar), do: "bg-no-ar/12 text-no-ar"
  defp cor_selo(:lento), do: "bg-lento/12 text-lento"
  defp cor_selo(:fora), do: "bg-fora/12 text-fora"
  defp cor_selo(:aguardando), do: "bg-sem-dado/15 text-suave"

  defp cor_barra(:no_ar), do: "fill-no-ar"
  defp cor_barra(:lento), do: "fill-lento"
  defp cor_barra(:fora), do: "fill-fora"
end
