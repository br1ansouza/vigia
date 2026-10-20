defmodule Vigia.Sonda.Http do
  @moduledoc """
  GET simples. Qualquer status 2xx ou 3xx conta como no ar.
  """

  @behaviour Vigia.Sonda

  alias Vigia.Alvo

  @impl true
  def verificar(%Alvo{url: url, tempo_limite: tempo_limite}) do
    opcoes =
      [
        url: url,
        retry: false,
        redirect: false,
        decode_body: false,
        receive_timeout: tempo_limite,
        connect_options: [timeout: tempo_limite],
        headers: [{"user-agent", "vigia"}]
      ]
      |> Keyword.merge(Application.get_env(:vigia, :req_sonda, []))

    case Req.get(opcoes) do
      {:ok, %Req.Response{status: status}} when status in 200..399 -> {:ok, "HTTP #{status}"}
      {:ok, %Req.Response{status: status}} -> {:erro, "HTTP #{status}"}
      {:error, erro} -> {:erro, motivo(erro)}
    end
  end

  defp motivo(%Req.TransportError{reason: :timeout}), do: "tempo esgotado"
  defp motivo(%Req.TransportError{reason: :econnrefused}), do: "conexão recusada"
  defp motivo(%Req.TransportError{reason: :nxdomain}), do: "domínio não encontrado"
  defp motivo(%Req.TransportError{reason: reason}), do: inspect(reason)
  defp motivo(erro) when is_exception(erro), do: Exception.message(erro)
end
