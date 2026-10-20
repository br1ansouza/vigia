defmodule Vigia.Demo do
  @moduledoc """
  Alvos fictícios mostrados para quem abre o painel sem entrar. Cada perfil
  imita um tipo de serviço: rápido e estável, lento, instável.
  """

  alias Vigia.Alvo

  @spec alvos() :: [Alvo.t()]
  def alvos do
    [
      alvo("loja-site", "Loja", "Site", %{base: 120, variacao: 80, falha: 0.0}),
      alvo("loja-api", "Loja", "API de pagamentos", %{base: 45, variacao: 30, falha: 0.002}),
      alvo("loja-busca", "Loja", "Busca", %{base: 380, variacao: 900, falha: 0.01}),
      alvo("interno-fila", "Interno", "Fila de e-mails", %{base: 25, variacao: 15, falha: 0.06}),
      alvo("interno-relatorios", "Interno", "Relatórios", %{
        base: 900,
        variacao: 1_400,
        falha: 0.03
      }),
      alvo("cdn", "CDN", "Imagens", %{base: 18, variacao: 12, falha: 0.0})
    ]
  end

  defp alvo(id, grupo, nome, perfil) do
    %Alvo{
      id: "demo-" <> id,
      nome: nome,
      grupo: grupo,
      tipo: :demo,
      espaco: :demo,
      intervalo: 5_000,
      lento: 1_000,
      perfil: perfil
    }
  end
end
