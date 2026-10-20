defmodule Vigia.Acesso.LimiteTest do
  use ExUnit.Case, async: true

  alias Vigia.Acesso.Limite

  test "bloqueia depois de cinco falhas e libera ao limpar" do
    ip = "teste-#{System.unique_integer([:positive])}"

    for _ <- 1..4, do: Limite.registrar_falha(ip)
    assert Limite.permitido?(ip)

    assert Limite.registrar_falha(ip) == 5
    refute Limite.permitido?(ip)

    Limite.limpar(ip)
    assert Limite.permitido?(ip)
  end

  test "falhas simultâneas são todas contadas" do
    ip = "corrida-#{System.unique_integer([:positive])}"

    1..50
    |> Task.async_stream(fn _ -> Limite.registrar_falha(ip) end, max_concurrency: 50)
    |> Stream.run()

    assert Limite.registrar_falha(ip) == 51
  end
end
