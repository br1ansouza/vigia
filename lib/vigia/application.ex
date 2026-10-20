defmodule Vigia.Application do
  @moduledoc false
  use Application

  require Logger

  @impl true
  def start(_type, _args) do
    children = [
      {Phoenix.PubSub, name: Vigia.PubSub},
      Vigia.Acesso.Limite,
      {Vigia.Monitor, alvos()},
      VigiaWeb.Endpoint
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Vigia.Supervisor)
  end

  defp alvos do
    demo = if Application.get_env(:vigia, :demo, true), do: Vigia.Demo.alvos(), else: []

    case Vigia.Alvo.de_json(Application.get_env(:vigia, :alvos_json)) do
      {:ok, reais} ->
        demo ++ reais

      {:error, motivo} ->
        Logger.error("VIGIA_ALVOS inválido, seguindo só com a demonstração: #{motivo}")
        demo
    end
  end

  @impl true
  def config_change(changed, _new, removed) do
    VigiaWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
