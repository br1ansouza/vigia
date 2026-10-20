defmodule Vigia.Demo do
  @moduledoc """
  Alvos fictícios mostrados para quem abre o painel sem entrar. Cada perfil
  imita um tipo de serviço: rápido e estável, lento, instável.
  """

  alias Vigia.Alvo

  @spec alvos() :: [Alvo.t()]
  def alvos do
    [
      alvo("api-pagamentos", "API de pagamentos", %{base: 45, variacao: 30, falha: 0.002}),
      alvo("site", "Site institucional", %{base: 120, variacao: 80, falha: 0.0}),
      alvo("busca", "Serviço de busca", %{base: 380, variacao: 900, falha: 0.01}),
      alvo("fila", "Worker de filas", %{base: 25, variacao: 15, falha: 0.06}),
      alvo("relatorios", "Gerador de relatórios", %{base: 900, variacao: 1_400, falha: 0.03}),
      alvo("cdn", "CDN de imagens", %{base: 18, variacao: 12, falha: 0.0})
    ]
  end

  defp alvo(id, nome, perfil) do
    %Alvo{
      id: "demo-" <> id,
      nome: nome,
      tipo: :demo,
      espaco: :demo,
      intervalo: 5_000,
      lento: 1_000,
      perfil: perfil
    }
  end
end
