defmodule VigiaWeb.SessaoControllerTest do
  use VigiaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Vigia.Acesso.Limite

  @senha "senha-de-teste-longa"

  setup_all do
    hash = Vigia.Acesso.gerar_hash(@senha)
    Application.put_env(:vigia, :senha_hash, hash)
    on_exit(fn -> Application.delete_env(:vigia, :senha_hash) end)
  end

  setup %{conn: conn} do
    ip = "10.0.0.#{:rand.uniform(250)}"
    Limite.limpar(ip)
    {:ok, conn: put_req_header(conn, "x-forwarded-for", "1.2.3.4, #{ip}"), ip: ip}
  end

  test "senha certa abre o espaço real e sair volta para a demonstração", %{conn: conn} do
    conn = post(conn, ~p"/entrar", senha: @senha)
    assert redirected_to(conn) == ~p"/"
    assert get_session(conn, "acesso")

    {:ok, _view, html} = conn |> recycle() |> live(~p"/")
    refute html =~ "demonstração"
    assert html =~ "Sair"

    conn = conn |> recycle() |> delete(~p"/sair")
    {:ok, _view, html} = conn |> recycle() |> live(~p"/")
    assert html =~ "demonstração"
  end

  test "senha errada responde 401 e não cria sessão", %{conn: conn} do
    conn = post(conn, ~p"/entrar", senha: "errada")
    assert html_response(conn, 401) =~ "Senha incorreta"
    refute get_session(conn, "acesso")
  end

  test "a sexta tentativa do mesmo IP é bloqueada mesmo com a senha certa", %{conn: conn, ip: ip} do
    for _ <- 1..5, do: Limite.registrar_falha(ip)

    conn = post(conn, ~p"/entrar", senha: @senha)
    assert html_response(conn, 429) =~ "Muitas tentativas"
  end

  test "trocar a senha invalida a sessão aberta", %{conn: conn} do
    conn = post(conn, ~p"/entrar", senha: @senha)
    anterior = Application.get_env(:vigia, :senha_hash)
    Application.put_env(:vigia, :senha_hash, Vigia.Acesso.gerar_hash("outra-senha-qualquer"))
    on_exit(fn -> Application.put_env(:vigia, :senha_hash, anterior) end)

    {:ok, _view, html} = conn |> recycle() |> live(~p"/")
    assert html =~ "demonstração"
  end

  test "sem senha configurada a página de login redireciona" do
    anterior = Application.get_env(:vigia, :senha_hash)
    Application.delete_env(:vigia, :senha_hash)
    on_exit(fn -> Application.put_env(:vigia, :senha_hash, anterior) end)

    assert build_conn() |> get(~p"/entrar") |> redirected_to() == ~p"/"
  end
end
