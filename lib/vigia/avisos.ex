defmodule Vigia.Avisos do
  @moduledoc """
  Ouve as leituras dos alvos reais e avisa quando um serviço cai ou volta.

  Só avisa "fora" depois de duas falhas seguidas, para uma oscilação isolada
  não acordar ninguém. O estado inicial vem do histórico já restaurado, então
  um deploy não repete avisos de serviços que já estavam fora.

  O envio roda numa tarefa separada: um serviço de push lento não atrasa a
  leitura seguinte.
  """

  use GenServer

  require Logger

  alias Vigia.{Alvo, Historico, Inscricoes, Leitura, Monitor, Push, Verificador}

  @falhas_para_avisar 2

  @type situacao :: {:ok | :fora, integer() | nil, non_neg_integer()}

  def start_link(opcoes), do: GenServer.start_link(__MODULE__, opcoes, name: __MODULE__)

  @spec testar() :: :ok
  def testar do
    enviar(%{titulo: "Vigia", corpo: "Avisos ativos neste aparelho.", url: "/"})
  end

  @doc """
  Decide se uma leitura gera aviso. Recebe `{estado, fora_desde, falhas}` do
  alvo e devolve o novo valor e o aviso, se houver.
  """
  @spec avaliar(situacao(), Leitura.t()) :: {situacao(), :caiu | {:voltou, integer()} | nil}
  def avaliar({estado, desde, falhas}, %Leitura{resultado: :fora, em: em}) do
    falhas = falhas + 1

    cond do
      estado == :fora -> {{:fora, desde, falhas}, nil}
      falhas >= @falhas_para_avisar -> {{:fora, em, falhas}, :caiu}
      true -> {{:ok, nil, falhas}, nil}
    end
  end

  def avaliar({:fora, desde, _falhas}, %Leitura{em: em}),
    do: {{:ok, nil, 0}, {:voltou, em - desde}}

  def avaliar({:ok, _, _}, %Leitura{}), do: {{:ok, nil, 0}, nil}

  @impl true
  def init(_opcoes) do
    Phoenix.PubSub.subscribe(Vigia.PubSub, Verificador.topico(:real))
    {:ok, Map.new(Monitor.alvos(:real), &{&1.id, situacao_inicial(&1)})}
  end

  @impl true
  def handle_info({:leitura, %Leitura{alvo_id: id} = leitura}, estado) do
    {situacao, aviso} = avaliar(Map.get(estado, id, {:ok, nil, 0}), leitura)

    if aviso, do: avisar(Monitor.alvo(id), aviso, leitura)

    {:noreply, Map.put(estado, id, situacao)}
  end

  defp situacao_inicial(%Alvo{id: id}) do
    case Historico.situacao(id) do
      {%Leitura{resultado: :fora}, desde} -> {:fora, desde, @falhas_para_avisar}
      _ -> {:ok, nil, 0}
    end
  end

  defp avisar(nil, _aviso, _leitura), do: :ok

  defp avisar(alvo, :caiu, leitura) do
    enviar(%{titulo: "#{titulo(alvo)} fora", corpo: leitura.detalhe || "sem resposta", url: "/"})
  end

  defp avisar(alvo, {:voltou, duracao}, _leitura) do
    enviar(%{
      titulo: "#{titulo(alvo)} voltou",
      corpo: "Ficou fora por #{minutos(duracao)}.",
      url: "/"
    })
  end

  defp titulo(%Alvo{grupo: nil, nome: nome}), do: nome
  defp titulo(%Alvo{grupo: grupo, nome: nome}), do: "#{grupo} · #{nome}"

  defp minutos(ms) when ms < 60_000, do: "menos de 1 min"
  defp minutos(ms) when ms < 3_600_000, do: "#{div(ms, 60_000)} min"
  defp minutos(ms), do: "#{div(ms, 3_600_000)} h #{rem(div(ms, 60_000), 60)} min"

  defp enviar(mensagem) do
    if Push.configurado?() do
      Task.Supervisor.start_child(Vigia.Tarefas, fn ->
        Enum.each(Inscricoes.todas(), &entregar(&1, mensagem))
      end)
    end

    :ok
  end

  defp entregar(inscricao, mensagem) do
    case Push.enviar(inscricao, mensagem) do
      :ok -> :ok
      :expirada -> Inscricoes.remover(inscricao.endpoint)
      {:erro, motivo} -> Logger.warning("aviso não entregue: #{motivo}")
    end
  end
end
