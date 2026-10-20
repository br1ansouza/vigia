defmodule Vigia.Acesso.Limite do
  @moduledoc """
  Limita tentativas de login por IP numa janela fixa. Conta em ETS com
  `update_counter`, que é atômico, então requisições simultâneas não escapam
  da contagem. O processo só limpa janelas vencidas.
  """

  use GenServer

  @tabela :vigia_tentativas
  @maximo 5
  @janela :timer.minutes(15)

  def start_link(opcoes), do: GenServer.start_link(__MODULE__, opcoes, name: __MODULE__)

  @spec permitido?(term()) :: boolean()
  def permitido?(chave) do
    case :ets.lookup(@tabela, {chave, janela_atual()}) do
      [{_, falhas}] -> falhas < @maximo
      [] -> true
    end
  end

  @spec registrar_falha(term()) :: non_neg_integer()
  def registrar_falha(chave) do
    :ets.update_counter(@tabela, {chave, janela_atual()}, 1, {{chave, janela_atual()}, 0})
  end

  @spec limpar(term()) :: :ok
  def limpar(chave) do
    :ets.match_delete(@tabela, {{chave, :_}, :_})
    :ok
  end

  defp janela_atual, do: div(System.os_time(:millisecond), @janela)

  @impl true
  def init(_opcoes) do
    :ets.new(@tabela, [:named_table, :public, :set, write_concurrency: true])
    agendar()
    {:ok, nil}
  end

  @impl true
  def handle_info(:limpar, estado) do
    atual = janela_atual()
    :ets.select_delete(@tabela, [{{{:_, :"$1"}, :_}, [{:<, :"$1", atual}], [true]}])
    agendar()
    {:noreply, estado}
  end

  defp agendar, do: Process.send_after(self(), :limpar, @janela)
end
