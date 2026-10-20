defmodule Vigia.Sonda.TailscaleTest do
  use ExUnit.Case, async: false

  alias Vigia.{Alvo, Tailscale}
  alias Vigia.Sonda.Tailscale, as: Sonda

  @dispositivos %{
    "devices" => [
      %{"name" => "tablet.tail1234.ts.net", "hostname" => "tablet", "connectedToControl" => true},
      %{
        "name" => "s21.tail1234.ts.net",
        "hostname" => "Galaxy-S21",
        "connectedToControl" => false,
        "lastSeen" => "2026-10-20T17:03:00Z"
      }
    ]
  }

  setup do
    :sys.replace_state(Tailscale, fn _ ->
      %{token: nil, token_expira: 0, lista: nil, lida_em: 0}
    end)

    on_exit(fn -> Application.delete_env(:vigia, Tailscale) end)
  end

  defp alvo(dispositivo),
    do: %Alvo{id: "ts", nome: "Câmera", tipo: :tailscale, dispositivo: dispositivo}

  defp stub(plug) do
    Req.Test.stub(Tailscale, plug)
    Req.Test.allow(Tailscale, self(), Process.whereis(Tailscale))
  end

  defp api_com_oauth(contador) do
    Application.put_env(:vigia, Tailscale, oauth_id: "id", oauth_segredo: "segredo")

    stub(fn
      %{request_path: "/api/v2/oauth/token"} = conn ->
        Agent.update(contador, &Map.update(&1, :token, 1, fn n -> n + 1 end))
        Req.Test.json(conn, %{"access_token" => "tok", "expires_in" => 3600})

      %{request_path: "/api/v2/tailnet/-/devices"} = conn ->
        ["Bearer tok"] = Plug.Conn.get_req_header(conn, "authorization")
        Agent.update(contador, &Map.update(&1, :lista, 1, fn n -> n + 1 end))
        Req.Test.json(conn, @dispositivos)
    end)
  end

  test "conectado, desconectado com horário de Brasília e não encontrado" do
    api_com_oauth(start_supervised!({Agent, fn -> %{} end}))

    assert {:ok, "conectado ao Tailscale"} = Sonda.verificar(alvo("tablet"))
    assert {:erro, "desconectado, visto em 20/10 14:03"} = Sonda.verificar(alvo("s21"))
    assert {:erro, "aparelho não encontrado na tailnet"} = Sonda.verificar(alvo("tab"))
  end

  test "várias sondas simultâneas usam um token e uma ida à API" do
    contador = start_supervised!({Agent, fn -> %{} end})
    api_com_oauth(contador)

    1..20
    |> Task.async_stream(fn _ -> Sonda.verificar(alvo("tablet")) end, max_concurrency: 20)
    |> Enum.each(fn {:ok, resposta} -> assert {:ok, _} = resposta end)

    assert Agent.get(contador, & &1) == %{token: 1, lista: 1}
  end

  test "token de API direto e credencial recusada" do
    Application.put_env(:vigia, Tailscale, token: "tskey-api-x")
    stub(&Plug.Conn.send_resp(&1, 401, ""))

    assert {:erro, "credencial do Tailscale recusada"} = Sonda.verificar(alvo("tablet"))
  end

  test "sem credencial explica o que falta" do
    assert {:erro, "credenciais do Tailscale não configuradas"} = Sonda.verificar(alvo("tablet"))
  end
end
