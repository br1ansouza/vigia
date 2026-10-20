defmodule VigiaWeb.PainelLiveTest do
  use VigiaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Vigia.{Alvo, Historico, Leitura, Verificador}

  setup do
    anteriores = :persistent_term.get({Vigia.Monitor, :alvos}, [])

    alvos = [
      %Alvo{id: "painel-a", nome: "API", grupo: "Loja", tipo: :demo, espaco: :demo},
      %Alvo{id: "painel-b", nome: "Fila", tipo: :demo, espaco: :demo},
      %Alvo{id: "painel-c", nome: "Site", grupo: "Loja", tipo: :demo, espaco: :demo},
      %Alvo{id: "painel-real", nome: "Secreto", tipo: :demo, espaco: :real}
    ]

    :persistent_term.put({Vigia.Monitor, :alvos}, alvos)
    on_exit(fn -> :persistent_term.put({Vigia.Monitor, :alvos}, anteriores) end)
  end

  test "sem entrar mostra só os alvos de demonstração", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")

    assert html =~ "Dados fictícios de demonstração"
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

    assert view |> element("#grupo_0-painel-a") |> render() =~ "HTTP 503"
    assert render(view) =~ ~r/text-fora">\s*1\s*</
  end

  test "agrupa por app na ordem da configuração e conta por grupo", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/")

    assert [{"h2", _, ["Loja"]}, {"h2", _, ["Fila"]}] =
             html
             |> LazyHTML.from_document()
             |> LazyHTML.query("section h2")
             |> LazyHTML.to_tree()

    assert has_element?(view, "#grupo-grupo_0 #grupo_0-painel-c")
    assert has_element?(view, "#grupo-grupo_1 #grupo_1-painel-b")
  end
end
