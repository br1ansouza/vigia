defmodule Mix.Tasks.Vigia.Vapid do
  @shortdoc "Gera o par de chaves VAPID para os avisos push"
  @moduledoc """
  Imprime `VAPID_PUBLICA` e `VAPID_PRIVADA`. Gere uma vez: trocar as chaves
  invalida todas as inscrições existentes.

      mix vigia.vapid
  """

  use Mix.Task

  @impl true
  def run(_args) do
    %{publica: publica, privada: privada} = Vigia.Push.gerar_chaves()
    Mix.shell().info("VAPID_PUBLICA=#{publica}\nVAPID_PRIVADA=#{privada}")
  end
end
