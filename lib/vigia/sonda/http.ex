defmodule Vigia.Sonda.Http do
  @moduledoc """
  GET simples. Status 2xx ou 3xx contam como no ar, além dos listados em
  `aceita_status` (por exemplo, o 403 de um site com bloqueio geográfico).
  """

  @behaviour Vigia.Sonda

  alias Vigia.Alvo

  @impl true
  def verificar(%Alvo{url: url, tempo_limite: tempo_limite, aceita_status: aceitos}) do
    opcoes =
      [
        url: url,
        retry: &conexao_fechada?/2,
        max_retries: 1,
        retry_delay: 0,
        retry_log_level: false,
        redirect: false,
        decode_body: false,
        receive_timeout: tempo_limite,
        connect_options: [timeout: tempo_limite],
        headers: [{"user-agent", "vigia"}]
      ]
      |> Keyword.merge(Application.get_env(:vigia, :req_sonda, []))

    case Req.get(opcoes) do
      {:ok, %Req.Response{status: status}} ->
        if status in 200..399 or status in aceitos,
          do: {:ok, "HTTP #{status}"},
          else: {:erro, "HTTP #{status}"}

      {:error, erro} ->
        {:erro, motivo(erro)}
    end
  end

  defp conexao_fechada?(_requisicao, %Req.TransportError{reason: :closed}), do: true
  defp conexao_fechada?(_requisicao, _resposta), do: false

  defp motivo(%Req.TransportError{reason: :timeout}), do: "tempo esgotado"
  defp motivo(%Req.TransportError{reason: :closed}), do: "conexão fechada"
  defp motivo(%Req.TransportError{reason: :econnrefused}), do: "conexão recusada"
  defp motivo(%Req.TransportError{reason: :nxdomain}), do: "domínio não encontrado"
  defp motivo(%Req.TransportError{reason: reason}), do: inspect(reason)
  defp motivo(erro) when is_exception(erro), do: Exception.message(erro)
end
