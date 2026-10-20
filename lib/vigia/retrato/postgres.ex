defmodule Vigia.Retrato.Postgres do
  @moduledoc """
  Armazena o retrato numa tabela com uma linha por alvo. Só Postgrex, sem Ecto:
  são três comandos SQL.

  O banco gratuito do Gigalixir assina o certificado com uma CA própria. Ela
  fica em `priv/certs/gigalixir-ca.pem` e a conexão valida a cadeia e o
  hostname contra ela.
  """

  @behaviour Vigia.Retrato

  @impl true
  def iniciar(opcoes) do
    opcoes = Keyword.put_new_lazy(opcoes, :ssl, fn -> tls(opcoes[:hostname]) end)

    with {:ok, conexao} <- Postgrex.start_link(opcoes ++ [pool_size: 1]),
         {:ok, _} <-
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

  @spec opcoes(String.t()) :: keyword()
  def opcoes(url) do
    uri = URI.parse(url)
    [usuario, senha] = uri.userinfo |> String.split(":", parts: 2) |> Enum.map(&URI.decode/1)

    [
      hostname: uri.host,
      port: uri.port || 5432,
      database: String.trim_leading(uri.path, "/"),
      username: usuario,
      password: senha,
      backoff_type: :exp,
      connect_timeout: 5_000
    ]
  end

  defp tls(hostname) do
    [
      verify: :verify_peer,
      cacertfile: Path.join(:code.priv_dir(:vigia), "certs/gigalixir-ca.pem"),
      server_name_indication: String.to_charlist(hostname),
      customize_hostname_check: [match_fun: :public_key.pkix_verify_hostname_match_fun(:https)]
    ]
  end
end
