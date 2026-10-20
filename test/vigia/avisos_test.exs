defmodule Vigia.AvisosTest do
  use ExUnit.Case, async: true

  alias Vigia.{Avisos, Leitura}

  defp leitura(resultado, em), do: %Leitura{alvo_id: "a", em: em, resultado: resultado}

  defp rodar(leituras) do
    leituras
    |> Enum.map_reduce({:ok, nil, 0}, fn l, situacao ->
      {nova, aviso} = Avisos.avaliar(situacao, l)
      {aviso, nova}
    end)
    |> elem(0)
    |> Enum.reject(&is_nil/1)
  end

  test "uma falha isolada não avisa" do
    assert rodar([leitura(:fora, 1), leitura(:no_ar, 2)]) == []
  end

  test "duas falhas seguidas avisam uma vez, e a volta informa quanto tempo ficou fora" do
    leituras = [
      leitura(:fora, 0),
      leitura(:fora, 60_000),
      leitura(:fora, 120_000),
      leitura(:fora, 180_000),
      leitura(:lento, 780_000)
    ]

    assert rodar(leituras) == [:caiu, {:voltou, 720_000}]
  end

  test "quem já estava fora antes do deploy não gera aviso repetido" do
    assert {{:fora, 10, 3}, nil} = Avisos.avaliar({:fora, 10, 2}, leitura(:fora, 20))
  end
end
