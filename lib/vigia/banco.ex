defmodule Vigia.Banco do
  @moduledoc """
  Conexão única com o Postgres, compartilhada pelo retrato e pelas inscrições
  de aviso. O banco gratuito do Gigalixir aceita duas conexões, e durante um
  deploy as instâncias velha e nova rodam juntas, então cada uma usa uma só.

  O banco assina o certificado com uma CA própria. Ela fica em
  `priv/certs/gigalixir-ca.pem` e a conexão valida a cadeia e o hostname
  contra ela.
  """

  @spec child_spec(term()) :: Supervisor.child_spec()
  def child_spec(_) do
    opcoes = Application.fetch_env!(:vigia, __MODULE__)
    opcoes = Keyword.put_new_lazy(opcoes, :ssl, fn -> tls(opcoes[:hostname]) end)
    Postgrex.child_spec([name: __MODULE__, pool_size: 1] ++ opcoes)
  end

  @spec configurado?() :: boolean()
  def configurado?, do: Application.get_env(:vigia, __MODULE__) != nil

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
