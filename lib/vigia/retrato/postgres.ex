defmodule Vigia.Retrato.Postgres do
  @moduledoc """
  Armazena o retrato numa tabela com uma linha por alvo, pela conexão de
  `Vigia.Banco`. Só Postgrex, sem Ecto: são três comandos SQL.
  """

  @behaviour Vigia.Retrato

  @impl true
  def iniciar(opcoes) do
    conexao = Keyword.get(opcoes, :conexao, Vigia.Banco)

    with {:ok, _} <-
           Postgrex.query(
             conexao,
             """
             CREATE TABLE IF NOT EXISTS retratos (
               alvo_id text PRIMARY KEY,
               dados bytea NOT NULL,
               atualizado_em timestamptz NOT NULL DEFAULT now()
             )
             """,
             []
           ) do
      {:ok, conexao}
    end
  end

  @impl true
  def carregar(conexao) do
    with {:ok, %Postgrex.Result{rows: linhas}} <-
           Postgrex.query(conexao, "SELECT alvo_id, dados FROM retratos", []) do
      {:ok, Enum.map(linhas, &List.to_tuple/1)}
    end
  end

  @impl true
  def salvar(conexao, linhas, ids_vigentes) do
    resultado =
      Postgrex.transaction(conexao, fn transacao ->
        Enum.each(linhas, fn {id, dados} ->
          Postgrex.query!(
            transacao,
            """
            INSERT INTO retratos (alvo_id, dados) VALUES ($1, $2)
            ON CONFLICT (alvo_id) DO UPDATE SET dados = EXCLUDED.dados, atualizado_em = now()
            """,
            [id, dados]
          )
        end)

        Postgrex.query!(transacao, "DELETE FROM retratos WHERE NOT (alvo_id = ANY($1))", [
          ids_vigentes
        ])
      end)

    case resultado do
      {:ok, _} -> :ok
      {:error, motivo} -> {:error, motivo}
    end
  end
end
