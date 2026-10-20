defmodule Vigia.Verificador do
  @moduledoc """
  Um processo por alvo. Verifica no intervalo do alvo, grava a leitura no
  histórico e avisa quem estiver ouvindo o espaço do alvo.

  A primeira verificação sai com um atraso aleatório para os alvos não
  dispararem todos no mesmo instante quando o sistema sobe.
  """

  use GenServer, restart: :permanent

  alias Vigia.{Alvo, Historico, Leitura, Sonda}

  @spec start_link(Alvo.t()) :: GenServer.on_start()
  def start_link(%Alvo{} = alvo), do: GenServer.start_link(__MODULE__, alvo, name: via(alvo.id))

  @spec via(String.t()) :: {:via, Registry, {Vigia.Registro, String.t()}}
  def via(alvo_id), do: {:via, Registry, {Vigia.Registro, alvo_id}}

  @spec verificar_agora(String.t()) :: :ok
  def verificar_agora(alvo_id) do
    case GenServer.whereis(via(alvo_id)) do
      nil -> nil
      pid -> send(pid, :verificar)
    end

    :ok
  end

  @spec topico(Alvo.espaco()) :: String.t()
  def topico(espaco), do: "monitor:#{espaco}"

  @impl true
  def init(%Alvo{} = alvo) do
    agendado = Process.send_after(self(), :verificar, :rand.uniform(min(alvo.intervalo, 2_000)))
    {:ok, %{alvo: alvo, sonda: Sonda.para(alvo), agendado: agendado}}
  end

  @impl true
  def handle_info(:verificar, %{alvo: alvo, sonda: sonda} = estado) do
    Process.cancel_timer(estado.agendado)

    leitura = medir(alvo, sonda)
    Historico.registrar(leitura)
    Phoenix.PubSub.broadcast(Vigia.PubSub, topico(alvo.espaco), {:leitura, leitura})

    {:noreply, %{estado | agendado: Process.send_after(self(), :verificar, alvo.intervalo)}}
  end

  @spec medir(Alvo.t(), module()) :: Leitura.t()
  def medir(%Alvo{} = alvo, sonda) do
    inicio = System.monotonic_time()
    resposta = chamar(sonda, alvo)
    latencia = System.convert_time_unit(System.monotonic_time() - inicio, :native, :millisecond)

    {resultado, detalhe} =
      case resposta do
        {:ok, detalhe} -> {classificar(alvo, latencia), detalhe}
        {:erro, detalhe} -> {:fora, detalhe}
      end

    %Leitura{
      alvo_id: alvo.id,
      em: System.os_time(:millisecond),
      resultado: resultado,
      latencia: if(Alvo.mede_latencia?(alvo), do: latencia),
      detalhe: detalhe
    }
  end

  defp chamar(sonda, alvo) do
    sonda.verificar(alvo)
  rescue
    erro -> {:erro, Exception.message(erro)}
  end

  defp classificar(%Alvo{lento: lento} = alvo, latencia) do
    if Alvo.mede_latencia?(alvo) and latencia > lento, do: :lento, else: :no_ar
  end
end
