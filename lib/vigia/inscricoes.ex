defmodule Vigia.Inscricoes do
  @moduledoc """
  Aparelhos inscritos para receber avisos. Ficam em ETS para leitura direta e,
  com banco configurado, também no Postgres, para sobreviver a deploys.
  Escritas passam pelo processo, então ETS e banco nunca divergem.
  """

  use GenServer

  require Logger

  alias Vigia.Push

  @tabela :vigia_inscricoes

  @callback iniciar() :: :ok | {:error, term()}
  @callback carregar() :: {:ok, [Push.inscricao()]} | {:error, term()}
  @callback salvar(Push.inscricao()) :: :ok | {:error, term()}
  @callback remover(String.t()) :: :ok | {:error, term()}

  def start_link(opcoes), do: GenServer.start_link(__MODULE__, opcoes, name: __MODULE__)

  @spec todas() :: [Push.inscricao()]
  def todas do
    for {endpoint, p256dh, auth} <- :ets.tab2list(@tabela),
        do: %{endpoint: endpoint, p256dh: p256dh, auth: auth}
  end

  @spec adicionar(map()) :: :ok | {:error, :invalida}
  def adicionar(%{
        "endpoint" => "https://" <> _ = endpoint,
        "keys" => %{"p256dh" => p, "auth" => a}
      })
      when is_binary(p) and is_binary(a) do
    with {:ok, <<4, _::binary-64>> = p256dh} <- Base.url_decode64(p, padding: false),
         {:ok, <<_::binary-16>> = auth} <- Base.url_decode64(a, padding: false) do
      GenServer.call(__MODULE__, {:adicionar, %{endpoint: endpoint, p256dh: p256dh, auth: auth}})
    else
      _ -> {:error, :invalida}
    end
  end

  def adicionar(_), do: {:error, :invalida}

  @spec remover(String.t()) :: :ok
  def remover(endpoint), do: GenServer.call(__MODULE__, {:remover, endpoint})

  @impl true
  def init(_opcoes) do
    :ets.new(@tabela, [:named_table, :protected, :set, read_concurrency: true])
    armazem = Application.get_env(:vigia, __MODULE__)
    {:ok, %{armazem: armazem}, {:continue, :carregar}}
  end

  @impl true
  def handle_continue(:carregar, %{armazem: nil} = estado), do: {:noreply, estado}

  def handle_continue(:carregar, %{armazem: armazem} = estado) do
    with :ok <- armazem.iniciar(),
         {:ok, inscricoes} <- armazem.carregar() do
      Enum.each(inscricoes, &inserir/1)
    else
      {:error, motivo} -> Logger.error("inscrições não carregadas: #{inspect(motivo)}")
    end

    {:noreply, estado}
  end

  @impl true
  def handle_call({:adicionar, inscricao}, _de, estado) do
    inserir(inscricao)
    persistir(estado, :salvar, inscricao)
    {:reply, :ok, estado}
  end

  def handle_call({:remover, endpoint}, _de, estado) do
    :ets.delete(@tabela, endpoint)
    persistir(estado, :remover, endpoint)
    {:reply, :ok, estado}
  end

  defp inserir(%{endpoint: endpoint, p256dh: p256dh, auth: auth}),
    do: :ets.insert(@tabela, {endpoint, p256dh, auth})

  defp persistir(%{armazem: nil}, _operacao, _dado), do: :ok

  defp persistir(%{armazem: armazem}, operacao, dado) do
    case apply(armazem, operacao, [dado]) do
      :ok -> :ok
      {:error, motivo} -> Logger.warning("inscrição não persistida: #{inspect(motivo)}")
    end
  end
end
