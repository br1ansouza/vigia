defmodule Vigia.Alvo do
  @moduledoc """
  Um serviço monitorado. Vem do JSON em `VIGIA_ALVOS` ou da lista de demonstração.
  """

  @tipos %{"http" => :http, "tailscale" => :tailscale}

  @enforce_keys [:id, :nome, :tipo]
  defstruct [
    :id,
    :nome,
    :tipo,
    :url,
    :dispositivo,
    :grupo,
    aceita_status: [],
    espaco: :real,
    intervalo: 30_000,
    tempo_limite: 5_000,
    lento: 1_500,
    perfil: %{}
  ]

  @type espaco :: :real | :demo
  @type t :: %__MODULE__{
          id: String.t(),
          nome: String.t(),
          tipo: :http | :tailscale | :demo,
          url: String.t() | nil,
          dispositivo: String.t() | nil,
          grupo: String.t() | nil,
          aceita_status: [100..599],
          espaco: espaco(),
          intervalo: pos_integer(),
          tempo_limite: pos_integer(),
          lento: pos_integer(),
          perfil: map()
        }

  @spec de_json(String.t() | nil) :: {:ok, [t()]} | {:error, String.t()}
  def de_json(nil), do: {:ok, []}
  def de_json(""), do: {:ok, []}

  def de_json(texto) do
    with {:ok, lista} when is_list(lista) <- Jason.decode(texto),
         {:ok, alvos} <- converter_todos(lista),
         :ok <- ids_unicos(alvos) do
      {:ok, alvos}
    else
      {:ok, _} -> {:error, "VIGIA_ALVOS precisa ser uma lista JSON"}
      {:error, %Jason.DecodeError{} = erro} -> {:error, Exception.message(erro)}
      {:error, motivo} -> {:error, motivo}
    end
  end

  defp converter_todos(lista) do
    Enum.reduce_while(lista, {:ok, []}, fn mapa, {:ok, acc} ->
      case novo(mapa) do
        {:ok, alvo} -> {:cont, {:ok, [alvo | acc]}}
        {:error, motivo} -> {:halt, {:error, motivo}}
      end
    end)
    |> case do
      {:ok, alvos} -> {:ok, Enum.reverse(alvos)}
      erro -> erro
    end
  end

  defp ids_unicos(alvos) do
    case alvos -- Enum.uniq_by(alvos, & &1.id) do
      [] -> :ok
      [repetido | _] -> {:error, "id repetido: #{repetido.id}"}
    end
  end

  @spec novo(map()) :: {:ok, t()} | {:error, String.t()}
  def novo(%{"id" => id, "nome" => nome, "tipo" => tipo} = mapa)
      when is_binary(id) and is_binary(nome) do
    with {:ok, tipo} <- tipo(tipo),
         {:ok, extras} <- campos(tipo, mapa) do
      {:ok,
       struct!(
         __MODULE__,
         [
           id: id,
           nome: nome,
           tipo: tipo,
           grupo: texto(mapa["grupo"]),
           intervalo: segundos(mapa, "intervalo", 30),
           tempo_limite: segundos(mapa, "tempo_limite", 5),
           lento: Map.get(mapa, "lento_ms", 1_500)
         ] ++ extras
       )}
    end
  end

  def novo(_), do: {:error, "cada alvo precisa de id, nome e tipo"}

  defp tipo(tipo) do
    case Map.fetch(@tipos, tipo) do
      {:ok, atomo} -> {:ok, atomo}
      :error -> {:error, "tipo desconhecido: #{inspect(tipo)}"}
    end
  end

  defp campos(:http, %{"url" => "http" <> _ = url} = mapa) do
    case Map.get(mapa, "aceita_status", []) do
      lista when is_list(lista) ->
        if Enum.all?(lista, &(is_integer(&1) and &1 in 100..599)),
          do: {:ok, url: url, aceita_status: lista},
          else: {:error, "alvo #{mapa["id"]}: aceita_status precisa ser lista de códigos HTTP"}

      _ ->
        {:error, "alvo #{mapa["id"]}: aceita_status precisa ser lista de códigos HTTP"}
    end
  end

  defp campos(:http, %{"id" => id}), do: {:error, "alvo #{id}: url http(s) obrigatória"}

  defp campos(:tailscale, %{"dispositivo" => dispositivo}) when is_binary(dispositivo),
    do: {:ok, dispositivo: dispositivo}

  defp campos(:tailscale, %{"id" => id}), do: {:error, "alvo #{id}: dispositivo obrigatório"}

  defp texto(valor) when is_binary(valor) and valor != "", do: valor
  defp texto(_valor), do: nil

  defp segundos(mapa, chave, padrao) do
    case Map.get(mapa, chave, padrao) do
      valor when is_integer(valor) and valor > 0 -> valor * 1_000
      _ -> padrao * 1_000
    end
  end

  @doc "Nome da seção do painel. Sem grupo, o alvo forma uma seção sozinho."
  @spec grupo(t()) :: String.t()
  def grupo(%__MODULE__{grupo: nil, nome: nome}), do: nome
  def grupo(%__MODULE__{grupo: grupo}), do: grupo

  @spec mede_latencia?(t()) :: boolean()
  def mede_latencia?(%__MODULE__{tipo: :tailscale}), do: false
  def mede_latencia?(%__MODULE__{}), do: true
end
