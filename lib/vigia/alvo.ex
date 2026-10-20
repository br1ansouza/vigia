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

  defp campos(:http, %{"url" => "http" <> _ = url}), do: {:ok, url: url}

  defp campos(:http, %{"id" => id}), do: {:error, "alvo #{id}: url http(s) obrigatória"}

  defp campos(:tailscale, %{"dispositivo" => dispositivo}) when is_binary(dispositivo),
    do: {:ok, dispositivo: dispositivo}

  defp campos(:tailscale, %{"id" => id}), do: {:error, "alvo #{id}: dispositivo obrigatório"}

  defp segundos(mapa, chave, padrao) do
    case Map.get(mapa, chave, padrao) do
      valor when is_integer(valor) and valor > 0 -> valor * 1_000
      _ -> padrao * 1_000
    end
  end

  @spec mede_latencia?(t()) :: boolean()
  def mede_latencia?(%__MODULE__{tipo: :tailscale}), do: false
  def mede_latencia?(%__MODULE__{}), do: true
end
