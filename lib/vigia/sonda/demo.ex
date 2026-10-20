defmodule Vigia.Sonda.Demo do
  @moduledoc """
  Simula um serviço para o modo de demonstração. O perfil do alvo define a
  latência base, a variação e a chance de falha. O tempo é gasto de verdade no
  processo do verificador, então o gráfico mostra o que o código mediria.
  """

  @behaviour Vigia.Sonda

  alias Vigia.Alvo

  @impl true
  def verificar(%Alvo{perfil: perfil}) do
    base = Map.get(perfil, :base, 80)
    variacao = Map.get(perfil, :variacao, 40)
    Process.sleep(base + :rand.uniform(variacao + 1) - 1)

    if :rand.uniform() < Map.get(perfil, :falha, 0.0) do
      {:erro, Enum.random(["HTTP 502", "HTTP 503", "tempo esgotado"])}
    else
      {:ok, "HTTP 200"}
    end
  end
end
