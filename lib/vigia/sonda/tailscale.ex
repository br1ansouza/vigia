defmodule Vigia.Sonda.Tailscale do
  @moduledoc """
  Diz se um aparelho da tailnet está conectado ao Tailscale. Não entra na
  tailnet nem fala com o aparelho: só consulta a API. O `dispositivo` do alvo
  casa com o hostname ou com o começo do nome MagicDNS.
  """

  @behaviour Vigia.Sonda

  alias Vigia.{Alvo, Tailscale}

  @fuso_brasilia -3 * 3600

  @impl true
  def verificar(%Alvo{dispositivo: procurado}) do
    with {:ok, lista} <- Tailscale.dispositivos() do
      case Enum.find(lista, &casa?(&1, procurado)) do
        nil -> {:erro, "aparelho não encontrado na tailnet"}
        %{conectado: true} -> {:ok, "conectado ao Tailscale"}
        %{visto_em: nil} -> {:erro, "desconectado"}
        %{visto_em: visto} -> {:erro, "desconectado, visto em #{formatar(visto)}"}
      end
    end
  end

  defp casa?(%{hostname: hostname, nome: nome}, procurado) do
    hostname == procurado or String.starts_with?(nome || "", procurado <> ".")
  end

  defp formatar(data) do
    data |> DateTime.add(@fuso_brasilia) |> Calendar.strftime("%d/%m %H:%M")
  end
end
