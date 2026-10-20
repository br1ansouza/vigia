defmodule Vigia.Historico do
  @moduledoc """
  Guarda as leituras em ETS. O processo só é dono das tabelas e apaga o que
  passou da janela; quem escreve é cada verificador e quem lê é a interface,
  direto na tabela, sem passar por mensagem.

  `:vigia_leituras` é um `ordered_set` com chave `{alvo_id, em}`, então as
  leituras de um alvo ficam contíguas e em ordem de tempo. `:vigia_situacao`
  guarda a última leitura de cada alvo e desde quando o resultado é o mesmo.
  """

  use GenServer

  alias Vigia.Leitura

  @leituras :vigia_leituras
  @situacao :vigia_situacao
  @janela :timer.hours(24)
  @limpeza :timer.minutes(5)

  def start_link(opcoes), do: GenServer.start_link(__MODULE__, opcoes, name: __MODULE__)

  @spec registrar(Leitura.t()) :: :ok
  def registrar(%Leitura{} = leitura) do
    :ets.insert(
      @leituras,
      {{leitura.alvo_id, leitura.em}, leitura.resultado, leitura.latencia, leitura.detalhe}
    )

    desde =
      case :ets.lookup(@situacao, leitura.alvo_id) do
        [{_, %Leitura{resultado: resultado}, desde}] when resultado == leitura.resultado -> desde
        _ -> leitura.em
      end

    :ets.insert(@situacao, {leitura.alvo_id, leitura, desde})
    :ok
  end

  @spec situacao(String.t()) :: {Leitura.t(), integer()} | nil
  def situacao(alvo_id) do
    case :ets.lookup(@situacao, alvo_id) do
      [{_, leitura, desde}] -> {leitura, desde}
      [] -> nil
    end
  end

  @spec recentes(String.t(), pos_integer()) :: [Leitura.t()]
  def recentes(alvo_id, quantidade) do
    padrao = [{{{alvo_id, :_}, :_, :_, :_}, [], [:"$_"]}]

    case :ets.select_reverse(@leituras, padrao, quantidade) do
      {linhas, _continuacao} -> linhas |> Enum.reverse() |> Enum.map(&para_leitura/1)
      :"$end_of_table" -> []
    end
  end

  @spec disponibilidade(String.t(), integer()) :: float() | nil
  def disponibilidade(alvo_id, desde) do
    total = contar(alvo_id, desde, :_)

    if total == 0,
      do: nil,
      else: (total - contar(alvo_id, desde, :fora)) / total * 100
  end

  defp contar(alvo_id, desde, resultado) do
    :ets.select_count(@leituras, [
      {{{alvo_id, :"$1"}, resultado, :_, :_}, [{:>=, :"$1", desde}], [true]}
    ])
  end

  @spec limpar(integer()) :: non_neg_integer()
  def limpar(antes_de) do
    :ets.select_delete(@leituras, [{{{:_, :"$1"}, :_, :_, :_}, [{:<, :"$1", antes_de}], [true]}])
  end

  defp para_leitura({{alvo_id, em}, resultado, latencia, detalhe}) do
    %Leitura{alvo_id: alvo_id, em: em, resultado: resultado, latencia: latencia, detalhe: detalhe}
  end

  @impl true
  def init(_opcoes) do
    tabela = [:named_table, :public, read_concurrency: true, write_concurrency: true]
    :ets.new(@leituras, [:ordered_set | tabela])
    :ets.new(@situacao, [:set | tabela])
    agendar_limpeza()
    {:ok, nil}
  end

  @impl true
  def handle_info(:limpar, estado) do
    limpar(System.os_time(:millisecond) - @janela)
    agendar_limpeza()
    {:noreply, estado}
  end

  defp agendar_limpeza, do: Process.send_after(self(), :limpar, @limpeza)
end
