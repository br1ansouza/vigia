defmodule Vigia.Push do
  @moduledoc """
  Web Push sem biblioteca, só com `:crypto` e `:public_key`.

    * Cifragem da mensagem: RFC 8291 (ECDH P-256, HKDF-SHA256 e AES-128-GCM
      no formato `aes128gcm` da RFC 8188).
    * Identificação do servidor: VAPID, RFC 8292 (JWT assinado com ES256).

  O serviço de push do navegador só repassa bytes cifrados; quem decifra é o
  celular, com a chave que ele mesmo gerou na inscrição.
  """

  @tamanho_registro 4096
  @validade_jwt 12 * 3600

  @type inscricao :: %{endpoint: String.t(), p256dh: binary(), auth: binary()}

  @spec gerar_chaves() :: %{publica: String.t(), privada: String.t()}
  def gerar_chaves do
    {publica, privada} = :crypto.generate_key(:ecdh, :prime256v1)
    %{publica: b64(publica), privada: b64(privada)}
  end

  @spec configurado?() :: boolean()
  def configurado?,
    do: match?(%{publica: p, privada: s} when is_binary(p) and is_binary(s), chaves())

  @spec chave_publica() :: String.t() | nil
  def chave_publica, do: chaves()[:publica]

  @spec enviar(inscricao(), map()) :: :ok | :expirada | {:erro, String.t()}
  def enviar(inscricao, mensagem) do
    corpo = cifrar(Jason.encode!(mensagem), inscricao.p256dh, inscricao.auth)

    requisicao =
      Req.new(
        url: inscricao.endpoint,
        body: corpo,
        retry: false,
        receive_timeout: 10_000,
        headers: cabecalhos(inscricao.endpoint)
      )
      |> Req.merge(Application.get_env(:vigia, :req_push, []))

    case Req.post(requisicao) do
      {:ok, %Req.Response{status: status}} when status in 200..299 -> :ok
      {:ok, %Req.Response{status: status}} when status in [404, 410] -> :expirada
      {:ok, %Req.Response{status: status}} -> {:erro, "serviço de push respondeu #{status}"}
      {:error, erro} -> {:erro, Exception.message(erro)}
    end
  end

  @spec cabecalhos(String.t()) :: [{String.t(), String.t()}]
  def cabecalhos(endpoint) do
    [
      {"content-encoding", "aes128gcm"},
      {"content-type", "application/octet-stream"},
      {"ttl", "86400"},
      {"urgency", "high"},
      {"authorization", vapid(endpoint)}
    ]
  end

  @doc """
  Cifra `texto` para a inscrição. `opcoes` aceita `:sal` e `:chaves_servidor`
  só para reproduzir o vetor de teste da RFC; em uso normal os dois são
  aleatórios a cada mensagem.
  """
  @spec cifrar(binary(), binary(), binary(), keyword()) :: binary()
  def cifrar(texto, ua_publica, auth, opcoes \\ []) do
    sal = Keyword.get_lazy(opcoes, :sal, fn -> :crypto.strong_rand_bytes(16) end)

    {as_publica, as_privada} =
      Keyword.get_lazy(opcoes, :chaves_servidor, fn ->
        :crypto.generate_key(:ecdh, :prime256v1)
      end)

    segredo = :crypto.compute_key(:ecdh, ua_publica, as_privada, :prime256v1)
    prk_chave = hmac(auth, segredo)
    ikm = hmac(prk_chave, "WebPush: info" <> <<0>> <> ua_publica <> as_publica <> <<1>>)
    prk = hmac(sal, ikm)
    <<cek::binary-16, _::binary>> = hmac(prk, "Content-Encoding: aes128gcm" <> <<0, 1>>)
    <<nonce::binary-12, _::binary>> = hmac(prk, "Content-Encoding: nonce" <> <<0, 1>>)

    {cifrado, tag} =
      :crypto.crypto_one_time_aead(:aes_128_gcm, cek, nonce, texto <> <<2>>, <<>>, true)

    sal <> <<@tamanho_registro::32, byte_size(as_publica)::8>> <> as_publica <> cifrado <> tag
  end

  @spec vapid(String.t(), integer()) :: String.t()
  def vapid(endpoint, agora \\ System.os_time(:second)) do
    %URI{scheme: esquema, host: host} = URI.parse(endpoint)
    %{publica: publica, privada: privada, contato: contato} = chaves()

    cabecalho = b64(Jason.encode!(%{typ: "JWT", alg: "ES256"}))

    corpo =
      b64(Jason.encode!(%{aud: "#{esquema}://#{host}", exp: agora + @validade_jwt, sub: contato}))

    assinado = cabecalho <> "." <> corpo

    der = :crypto.sign(:ecdsa, :sha256, assinado, [de_b64(privada), :prime256v1])
    {:"ECDSA-Sig-Value", r, s} = :public_key.der_decode(:"ECDSA-Sig-Value", der)

    "vapid t=#{assinado}.#{b64(<<r::256, s::256>>)}, k=#{publica}"
  end

  @spec de_b64(String.t()) :: binary()
  def de_b64(texto), do: Base.url_decode64!(texto, padding: false)

  defp b64(binario), do: Base.url_encode64(binario, padding: false)

  defp hmac(chave, dados), do: :crypto.mac(:hmac, :sha256, chave, dados)

  defp chaves, do: Map.new(Application.get_env(:vigia, __MODULE__, []))
end
