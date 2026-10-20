defmodule Vigia.AlvoTest do
  use ExUnit.Case, async: true

  alias Vigia.Alvo

  test "converte a lista JSON com valores padrão em milissegundos" do
    json = ~s([
      {"id": "api", "nome": "API", "tipo": "http", "url": "https://exemplo.com/saude", "intervalo": 60},
      {"id": "cam", "nome": "Câmera", "tipo": "tailscale", "dispositivo": "tablet"}
    ])

    assert {:ok, [api, cam]} = Alvo.de_json(json)
    assert %Alvo{tipo: :http, intervalo: 60_000, tempo_limite: 5_000, espaco: :real} = api
    assert %Alvo{tipo: :tailscale, dispositivo: "tablet", intervalo: 30_000} = cam
    refute Alvo.mede_latencia?(cam)
  end

  test "ausente ou vazio vira lista vazia" do
    assert {:ok, []} = Alvo.de_json(nil)
    assert {:ok, []} = Alvo.de_json("")
  end

  test "recusa entradas inválidas com motivo legível" do
    assert {:error, "VIGIA_ALVOS precisa ser uma lista JSON"} = Alvo.de_json(~s({"id": "x"}))

    assert {:error, "tipo desconhecido: \"ftp\""} =
             Alvo.de_json(~s([{"id":"a","nome":"A","tipo":"ftp"}]))

    assert {:error, "alvo a: url http(s) obrigatória"} =
             Alvo.de_json(~s([{"id":"a","nome":"A","tipo":"http"}]))

    assert {:error, "cada alvo precisa de id, nome e tipo"} = Alvo.de_json(~s([{"nome":"A"}]))
    assert {:error, _} = Alvo.de_json("[{")
  end

  test "recusa ids repetidos" do
    item = ~s({"id":"a","nome":"A","tipo":"http","url":"https://a.dev"})
    assert {:error, "id repetido: a"} = Alvo.de_json("[#{item},#{item}]")
  end

  test "não aceita o tipo demo pelo JSON" do
    assert {:error, "tipo desconhecido: \"demo\""} =
             Alvo.de_json(~s([{"id":"a","nome":"A","tipo":"demo"}]))
  end

  test "aceita_status valida códigos HTTP" do
    base = ~s("id":"a","nome":"A","tipo":"http","url":"https://a.dev")

    assert {:ok, [%Alvo{aceita_status: [403]}]} =
             Alvo.de_json(~s([{#{base},"aceita_status":[403]}]))

    assert {:ok, [%Alvo{aceita_status: []}]} = Alvo.de_json(~s([{#{base}}]))
    assert {:error, _} = Alvo.de_json(~s([{#{base},"aceita_status":["403"]}]))
    assert {:error, _} = Alvo.de_json(~s([{#{base},"aceita_status":403}]))
  end

  test "grupo é opcional e, sem ele, a seção leva o nome do alvo" do
    json = ~s([
      {"id":"a","nome":"API","tipo":"http","url":"https://a.dev","grupo":"TrackRide"},
      {"id":"b","nome":"PistaCerta","tipo":"http","url":"https://b.dev"}
    ])

    assert {:ok, [a, b]} = Alvo.de_json(json)
    assert Alvo.grupo(a) == "TrackRide"
    assert Alvo.grupo(b) == "PistaCerta"
  end
end
