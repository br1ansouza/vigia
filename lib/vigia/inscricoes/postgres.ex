defmodule Vigia.Inscricoes.Postgres do
  @moduledoc false

  @behaviour Vigia.Inscricoes

  @impl true
  def iniciar do
    """
    CREATE TABLE IF NOT EXISTS inscricoes (
      endpoint text PRIMARY KEY,
      p256dh bytea NOT NULL,
      auth bytea NOT NULL,
      criada_em timestamptz NOT NULL DEFAULT now()
    )
    """
    |> executar([])
  end

  @impl true
  def carregar do
    with {:ok, %Postgrex.Result{rows: linhas}} <-
           Postgrex.query(Vigia.Banco, "SELECT endpoint, p256dh, auth FROM inscricoes", []) do
      {:ok, for([e, p, a] <- linhas, do: %{endpoint: e, p256dh: p, auth: a})}
    end
  end

  @impl true
  def salvar(%{endpoint: endpoint, p256dh: p256dh, auth: auth}) do
    executar(
      """
      INSERT INTO inscricoes (endpoint, p256dh, auth) VALUES ($1, $2, $3)
      ON CONFLICT (endpoint) DO UPDATE SET p256dh = EXCLUDED.p256dh, auth = EXCLUDED.auth
      """,
      [endpoint, p256dh, auth]
    )
  end

  @impl true
  def remover(endpoint), do: executar("DELETE FROM inscricoes WHERE endpoint = $1", [endpoint])

  defp executar(sql, parametros) do
    case Postgrex.query(Vigia.Banco, sql, parametros) do
      {:ok, _} -> :ok
      {:error, erro} -> {:error, erro}
    end
  end
end
