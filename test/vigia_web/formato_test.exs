defmodule VigiaWeb.FormatoTest do
  use ExUnit.Case, async: true

  alias VigiaWeb.Formato

  test "latência separa valor e unidade" do
    assert Formato.latencia(nil) == {"—", nil}
    assert Formato.latencia(87) == {"87", "ms"}
    assert Formato.latencia(1_234) == {"1,23", "s"}
  end

  test "porcentagem trunca em vez de arredondar para não mostrar 100 com falha" do
    assert Formato.porcentagem(nil) == "—"
    assert Formato.porcentagem(100.0) == "100"
    assert Formato.porcentagem(99.999) == "99,99"
  end

  test "duração escolhe a unidade pela grandeza" do
    assert Formato.duracao(-5) == "0 s"
    assert Formato.duracao(42_000) == "42 s"
    assert Formato.duracao(5 * 60_000) == "5 min"
    assert Formato.duracao(:timer.hours(3) + :timer.minutes(7)) == "3 h 7 min"
    assert Formato.duracao(:timer.hours(50)) == "2 d 2 h"
  end
end
