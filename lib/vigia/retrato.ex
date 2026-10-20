defmodule Vigia.Retrato do
  @moduledoc """
  Guarda o histórico fora da memória para sobreviver a deploys. A cada minuto,
  e quando a aplicação para, cada alvo real vira uma linha no armazenamento: o
  `term_to_binary` comprimido das suas leituras. Na subida, restaura antes dos
  verificadores começarem, porque fica antes deles na árvore do monitor.

  Sem armazenamento configurado o processo não sobe, e o histórico fica só em
  memória.
  """

  use GenServer

  require Logger

  alias Vigia.{Alvo, Historico}

  @intervalo :timer.minutes(1)

  @callback iniciar(keyword()) :: {:ok, term()} | {:error, term()}
  @callback carregar(term()) :: {:ok, [{String.t(), binary()}]} | {:error, term()}
  @callback salvar(term(), [{String.t(), binary()}], [String.t()]) :: :ok | {:error, term()}

  def start_link(alvos), do: GenServer.start_link(__MODULE__, alvos, name: __MODULE__)

  @spec salvar_agora() :: :ok
  def salvar_agora, do: GenServer.call(__MODULE__, :salvar)

  @impl true
  def init(alvos) do
    case Application.get_env(:vigia, __MODULE__) do
      nil ->
        :ignore

      {armazem, opcoes} ->
        Process.flag(:trap_exit, true)
        ids = for %Alvo{espaco: :real, id: id} <- alvos, do: id
        estado = %{armazem: armazem, conexao: nil, ids: ids}
        {:ok, estado |> conectar(opcoes) |> restaurar() |> agendar()}
    end
  end

  @impl true
  def handle_call(:salvar, _de, estado), do: {:reply, salvar(estado), estado}

  @impl true
  def handle_info(:salvar, estado) do
    salvar(estado)
    {:noreply, agendar(estado)}
  end

  def handle_info({:EXIT, _pid, _motivo}, estado), do: {:noreply, estado}

  @impl true
  def terminate(_motivo, estado), do: salvar(estado)

  defp conectar(%{armazem: armazem} = estado, opcoes) do
    case armazem.iniciar(opcoes) do
      {:ok, conexao} ->
        %{estado | conexao: conexao}

      {:error, motivo} ->
        Logger.error("retrato indisponível, histórico só em memória: #{inspect(motivo)}")
        estado
    end
  end

  defp restaurar(%{conexao: nil} = estado), do: estado

  defp restaurar(%{armazem: armazem, conexao: conexao, ids: ids} = estado) do
    case armazem.carregar(conexao) do
      {:ok, linhas} ->
        restaurados = for {id, binario} <- linhas, id in ids, do: Historico.importar(binario)
        Logger.info("retrato restaurado: #{length(restaurados)} alvos")

      {:error, motivo} ->
        Logger.error("falha ao restaurar o retrato: #{inspect(motivo)}")
    end

    estado
  end

  defp salvar(%{conexao: nil}), do: :ok

  defp salvar(%{armazem: armazem, conexao: conexao, ids: ids}) do
    linhas = for id <- ids, binario = Historico.exportar(id), do: {id, binario}

    case armazem.salvar(conexao, linhas, ids) do
      :ok ->
        :ok

      {:error, motivo} ->
        Logger.warning("falha ao salvar o retrato: #{inspect(motivo)}")
        :ok
    end
  end

  defp agendar(estado) do
    Process.send_after(self(), :salvar, @intervalo)
    estado
  end
end
