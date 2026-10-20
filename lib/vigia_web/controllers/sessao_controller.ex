defmodule VigiaWeb.SessaoController do
  use VigiaWeb, :controller

  alias Vigia.Acesso
  alias Vigia.Acesso.Limite
  alias VigiaWeb.Acesso, as: AcessoWeb

  def new(conn, _params) do
    if Acesso.habilitado?(),
      do: render(conn, :new, erro: nil, page_title: "Entrar"),
      else: redirect(conn, to: ~p"/")
  end

  def create(conn, %{"senha" => senha}) when is_binary(senha) do
    ip = AcessoWeb.ip(conn)

    cond do
      not Limite.permitido?(ip) ->
        conn
        |> put_status(429)
        |> render(:new,
          erro: "Muitas tentativas. Tente de novo mais tarde.",
          page_title: "Entrar"
        )

      Acesso.entrar(senha) == :ok ->
        Limite.limpar(ip)

        conn
        |> configure_session(renew: true)
        |> put_session("acesso", Acesso.marca())
        |> redirect(to: ~p"/")

      true ->
        Limite.registrar_falha(ip)

        conn
        |> put_status(401)
        |> render(:new, erro: "Senha incorreta.", page_title: "Entrar")
    end
  end

  def create(conn, _params), do: redirect(conn, to: ~p"/entrar")

  def delete(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> redirect(to: ~p"/")
  end
end
