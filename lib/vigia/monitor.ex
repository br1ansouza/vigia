defmodule Vigia.Monitor do
  @moduledoc """
  Árvore do monitor. A estratégia `rest_for_one` garante a ordem: se o
  registro ou o histórico caírem, os verificadores sobem de novo depois deles.

      Monitor
      ├── Registry (Vigia.Registro)
      ├── Historico (dono das tabelas ETS)
      ├── Retrato (restaura e salva o histórico no Postgres)
      ├── DynamicSupervisor (Vigia.Verificadores)
      │   └── Verificador, um por alvo
      └── Task que inicia os verificadores

  A lista de alvos fica em `:persistent_term`: muda só na subida e é lida a cada
  render da interface.
  """

  use Supervisor

  alias Vigia.{Alvo, Verificador}

  def start_link(alvos), do: Supervisor.start_link(__MODULE__, alvos, name: __MODULE__)

  @spec alvos(Alvo.espaco()) :: [Alvo.t()]
  def alvos(espaco) do
    :persistent_term.get({__MODULE__, :alvos}, []) |> Enum.filter(&(&1.espaco == espaco))
  end

  @spec alvo(String.t()) :: Alvo.t() | nil
  def alvo(id), do: :persistent_term.get({__MODULE__, :alvos}, []) |> Enum.find(&(&1.id == id))

  @impl true
  def init(alvos) do
    :persistent_term.put({__MODULE__, :alvos}, alvos)

    children = [
      {Registry, keys: :unique, name: Vigia.Registro},
      Vigia.Historico,
      {Vigia.Retrato, alvos},
      {DynamicSupervisor, name: Vigia.Verificadores, strategy: :one_for_one},
      Supervisor.child_spec({Task, fn -> Enum.each(alvos, &iniciar/1) end}, restart: :transient)
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end

  @spec iniciar(Alvo.t()) :: DynamicSupervisor.on_start_child()
  def iniciar(%Alvo{} = alvo) do
    DynamicSupervisor.start_child(Vigia.Verificadores, {Verificador, alvo})
  end
end
