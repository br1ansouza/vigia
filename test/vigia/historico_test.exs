defmodule Vigia.HistoricoTest do
  use ExUnit.Case, async: true

  alias Vigia.{Historico, Leitura}

  defp id, do: "hist-#{System.unique_integer([:positive])}"

  defp leitura(alvo_id, em, resultado, latencia \\ 50) do
    %Leitura{alvo_id: alvo_id, em: em, resultado: resultado, latencia: latencia}
  end

  test "recentes devolve as últimas N em ordem de tempo e só do alvo pedido" do
    alvo = id()
    outro = id()
    for em <- 1..10, do: Historico.registrar(leitura(alvo, em, :no_ar, em))
    Historico.registrar(leitura(outro, 99, :fora))

    assert [8, 9, 10] = alvo |> Historico.recentes(3) |> Enum.map(& &1.latencia)
    assert [] = Historico.recentes(id(), 3)
  end

  test "situação guarda desde quando o resultado não muda" do
    alvo = id()
    Historico.registrar(leitura(alvo, 100, :no_ar))
    Historico.registrar(leitura(alvo, 200, :no_ar))
    assert {%Leitura{em: 200}, 100} = Historico.situacao(alvo)

    Historico.registrar(leitura(alvo, 300, :fora))
    assert {%Leitura{resultado: :fora}, 300} = Historico.situacao(alvo)
    assert Historico.situacao(id()) == nil
  end

  test "disponibilidade conta lento como no ar e respeita a janela" do
    alvo = id()
    Historico.registrar(leitura(alvo, 10, :fora))
    for em <- [20, 30, 40], do: Historico.registrar(leitura(alvo, em, :no_ar))
    Historico.registrar(leitura(alvo, 50, :lento))

    assert Historico.disponibilidade(alvo, 0) == 80.0
    assert Historico.disponibilidade(alvo, 20) == 100.0
    assert Historico.disponibilidade(id(), 0) == nil
  end
end
