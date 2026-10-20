defmodule VigiaWeb.PainelLiveTest do
  use VigiaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Vigia.{Alvo, Historico, Leitura, Verificador}

  setup do
    anteriores = :persistent_term.get({Vigia.Monitor, :alvos}, [])

    alvos = [
      %Alvo{id: "painel-a", nome: "API", tipo: :demo, espaco: :demo},
      %Alvo{id: "painel-b", nome: "Fila", tipo: :demo, espaco: :demo},
      %Alvo{id: "painel-real", nome: "Secreto", tipo: :demo, espaco: :real}
    ]

    :persistent_term.put({Vigia.Monitor, :alvos}, alvos)
    on_exit(fn -> :persistent_term.put({Vigia.Monitor, :alvos}, anteriores) end)
  end

  test "sem entrar mostra só os alvos de demonstração", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")

    assert html =~ "demonstração"
    assert html =~ "API"
    assert html =~ "aguardando"
    refute html =~ "Secreto"
  end

  test "uma leitura nova atualiza o cartão e a contagem", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    leitura = %Leitura{
      alvo_id: "painel-a",
      em: System.os_time(:millisecond),
      resultado: :fora,
      detalhe: "HTTP 503"
    }

    Historico.registrar(leitura)
    Phoenix.PubSub.broadcast(Vigia.PubSub, Verificador.topico(:demo), {:leitura, leitura})

    assert view |> element("#alvos-painel-a") |> render() =~ "HTTP 503"
    assert render(view) =~ ~r/text-fora">\s*1\s*</
  end
end
