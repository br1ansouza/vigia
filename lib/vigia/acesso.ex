defmodule Vigia.Acesso do
  @moduledoc """
  Senha única do painel, guardada só como hash em `VIGIA_SENHA_HASH`.

  Formato do hash: `pbkdf2-sha256$<iterações>$<sal base64>$<chave base64>`.
  Usa só `:crypto` do OTP; a comparação é em tempo constante.
  """

  @iteracoes 600_000
  @tamanho 32

  @spec gerar_hash(String.t()) :: String.t()
  def gerar_hash(senha) when is_binary(senha) do
    sal = :crypto.strong_rand_bytes(16)
    chave = derivar(senha, sal, @iteracoes)
    Enum.join(["pbkdf2-sha256", @iteracoes, Base.encode64(sal), Base.encode64(chave)], "$")
  end

  @spec confere?(String.t(), String.t() | nil) :: boolean()
  def confere?(senha, hash) when is_binary(senha) and is_binary(hash) do
    with ["pbkdf2-sha256", iteracoes, sal, esperada] <- String.split(hash, "$"),
         {iteracoes, ""} <- Integer.parse(iteracoes),
         {:ok, sal} <- Base.decode64(sal),
         {:ok, esperada} <- Base.decode64(esperada) do
      Plug.Crypto.secure_compare(derivar(senha, sal, iteracoes), esperada)
    else
      _ -> false
    end
  end

  def confere?(_senha, _hash), do: false

  @spec habilitado?() :: boolean()
  def habilitado?, do: is_binary(hash_configurado())

  @spec entrar(String.t()) :: :ok | :erro
  def entrar(senha) do
    if confere?(senha, hash_configurado()), do: :ok, else: :erro
  end

  @doc """
  Marca guardada na sessão. Derivada do hash, então trocar a senha derruba
  todas as sessões abertas.
  """
  @spec marca() :: String.t() | nil
  def marca do
    case hash_configurado() do
      nil -> nil
      hash -> :crypto.hash(:sha256, hash) |> binary_part(0, 12) |> Base.url_encode64()
    end
  end

  defp hash_configurado do
    case Application.get_env(:vigia, :senha_hash) do
      "" -> nil
      hash -> hash
    end
  end

  defp derivar(senha, sal, iteracoes),
    do: :crypto.pbkdf2_hmac(:sha256, senha, sal, iteracoes, @tamanho)
end
