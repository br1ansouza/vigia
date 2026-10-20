defmodule VigiaWeb.PageControllerTest do
  use VigiaWeb.ConnCase

  test "GET /", %{conn: conn} do
    assert conn |> get(~p"/") |> html_response(200) =~ "Vigia"
  end

  test "GET /saude", %{conn: conn} do
    assert conn |> get(~p"/saude") |> response(200) == "ok"
  end
end
