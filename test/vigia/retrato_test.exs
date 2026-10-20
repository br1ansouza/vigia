defmodule Vigia.RetratoTest do
  use ExUnit.Case, async: false

  alias Vigia.{Alvo, Historico, Leitura, Retrato}

  defmodule Memoria do
    @behaviour Vigia.Retrato

    def iniciar(opcoes), do: {:ok, Keyword.fetch!(opcoes, :agente)}
    def carregar(agente), do: {:ok, Agent.get(agente, &Map.to_list/1)}

    def salvar(agente, linhas, vigentes) do
      Agent.update(agente, fn atual ->
        atual |> Map.take(vigentes) |> Map.merge(Map.new(linhas))
      end)
    end
  end

  setup do
    agente = start_supervised!({Agent, fn -> %{} end})
    Application.put_env(:vigia, Retrato, {Memoria, agente: agente})
    on_exit(fn -> Application.delete_env(:vigia, Retrato) end)
    %{agente: agente}
  end

  defp alvo(id, espaco \\ :real), do: %Alvo{id: id, nome: id, tipo: :demo, espaco: espaco}

  defp registrar(id, em, resultado) do
    Historico.registrar(%Leitura{alvo_id: id, em: em, resultado: resultado, latencia: 10})
  end

  defp apagar(id) do
    :ets.match_delete(:vigia_leituras, {{id, :_}, :_, :_, :_})
    :ets.delete(:vigia_situacao, id)
  end

  test "salva só alvos reais e remove os que saíram da configuração", %{agente: agente} do
    Agent.update(agente, &Map.put(&1, "ret-removido", <<0>>))
    registrar("ret-real", 1, :no_ar)
    registrar("ret-demo", 1, :no_ar)

    start_supervised!({Retrato, [alvo("ret-real"), alvo("ret-demo", :demo)]})
    Retrato.salvar_agora()

    assert agente |> Agent.get(&Map.keys/1) |> Enum.sort() == ["ret-real"]
  end

  test "restaura leituras e a situação antes de qualquer verificação", %{agente: agente} do
    registrar("ret-volta", 100, :fora)
    registrar("ret-volta", 200, :fora)
    Agent.update(agente, &Map.put(&1, "ret-volta", Historico.exportar("ret-volta")))
    apagar("ret-volta")
    assert Historico.recentes("ret-volta", 10) == []

    start_supervised!({Retrato, [alvo("ret-volta")]})

    assert [%Leitura{em: 100}, %Leitura{em: 200}] = Historico.recentes("ret-volta", 10)
    assert {%Leitura{resultado: :fora}, 100} = Historico.situacao("ret-volta")
  end

  test "ao parar, grava o que tiver em memória", %{agente: agente} do
    start_supervised!({Retrato, [alvo("ret-fim")]})
    registrar("ret-fim", 1, :no_ar)

    stop_supervised!(Retrato)

    assert Agent.get(agente, &Map.has_key?(&1, "ret-fim"))
  end

  test "sem armazenamento configurado não sobe" do
    Application.delete_env(:vigia, Retrato)
    assert Retrato.start_link([]) == :ignore
  end
end
