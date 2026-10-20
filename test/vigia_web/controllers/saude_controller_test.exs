defmodule VigiaWeb.SaudeControllerTest do
  use VigiaWeb.ConnCase, async: true

  test "GET /saude", %{conn: conn} do
    assert conn |> get(~p"/saude") |> response(200) == "ok"
  end
end
