defmodule Vigia.Resumo do
  @moduledoc """
  O que a interface mostra de um alvo, montado a partir do histórico.
  """

  alias Vigia.{Alvo, Historico, Leitura}

  @pontos 60
  @janela :timer.hours(24)

  @enforce_keys [:id, :nome, :resultado]
  defstruct [
    :id,
    :nome,
    :resultado,
    :latencia,
    :detalhe,
    :desde,
    :ultima_em,
    :disponibilidade,
    :limite_lento,
    pontos: []
  ]

  @type resultado :: Leitura.resultado() | :aguardando
  @type t :: %__MODULE__{
          id: String.t(),
          nome: String.t(),
          resultado: resultado(),
          latencia: non_neg_integer() | nil,
          detalhe: String.t() | nil,
          desde: integer() | nil,
          ultima_em: integer() | nil,
          disponibilidade: float() | nil,
          limite_lento: pos_integer() | nil,
          pontos: [{Leitura.resultado(), non_neg_integer() | nil}]
        }

  @spec de(Alvo.t(), integer()) :: t()
  def de(%Alvo{} = alvo, agora \\ System.os_time(:millisecond)) do
    base = %__MODULE__{
      id: alvo.id,
      nome: alvo.nome,
      resultado: :aguardando,
      limite_lento: if(Alvo.mede_latencia?(alvo), do: alvo.lento)
    }

    case Historico.situacao(alvo.id) do
      nil ->
        base

      {%Leitura{} = ultima, desde} ->
        %__MODULE__{
          base
          | resultado: ultima.resultado,
            latencia: ultima.latencia,
            detalhe: ultima.detalhe,
            desde: desde,
            ultima_em: ultima.em,
            disponibilidade: Historico.disponibilidade(alvo.id, agora - @janela),
            pontos:
              alvo.id |> Historico.recentes(@pontos) |> Enum.map(&{&1.resultado, &1.latencia})
        }
    end
  end

  @spec contagem([resultado()]) :: %{
          total: non_neg_integer(),
          no_ar: non_neg_integer(),
          fora: non_neg_integer()
        }
  def contagem(resultados) do
    %{
      total: length(resultados),
      no_ar: Enum.count(resultados, &(&1 in [:no_ar, :lento])),
      fora: Enum.count(resultados, &(&1 == :fora))
    }
  end
end
