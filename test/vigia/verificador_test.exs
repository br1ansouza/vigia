defmodule Vigia.VerificadorTest do
  use ExUnit.Case, async: true

  alias Vigia.{Alvo, Historico, Leitura, Verificador}

  defp alvo(campos \\ []) do
    struct!(
      Alvo,
      [
        id: "ver-#{System.unique_integer([:positive])}",
        nome: "API",
        tipo: :http,
        url: "http://api.teste/saude"
      ] ++
        campos
    )
  end

  describe "medir/2 com a sonda HTTP" do
    test "2xx rápido fica no ar" do
      Req.Test.stub(Vigia.Sonda.Http, &Plug.Conn.send_resp(&1, 204, ""))

      assert %Leitura{resultado: :no_ar, detalhe: "HTTP 204"} =
               Verificador.medir(alvo(), Vigia.Sonda.Http)
    end

    test "5xx fica fora" do
      Req.Test.stub(Vigia.Sonda.Http, &Plug.Conn.send_resp(&1, 503, ""))

      assert %Leitura{resultado: :fora, detalhe: "HTTP 503"} =
               Verificador.medir(alvo(), Vigia.Sonda.Http)
    end

    test "falha de transporte fica fora com motivo legível" do
      Req.Test.stub(Vigia.Sonda.Http, &Req.Test.transport_error(&1, :econnrefused))

      assert %Leitura{resultado: :fora, detalhe: "conexão recusada"} =
               Verificador.medir(alvo(), Vigia.Sonda.Http)
    end

    test "acima do limite de latência fica lento" do
      Req.Test.stub(Vigia.Sonda.Http, fn conn ->
        Process.sleep(30)
        Plug.Conn.send_resp(conn, 200, "")
      end)

      assert %Leitura{resultado: :lento} = Verificador.medir(alvo(lento: 10), Vigia.Sonda.Http)
    end
  end

  defmodule SondaQuebrada do
    @behaviour Vigia.Sonda
    def verificar(_), do: raise("sonda quebrou")
  end

  test "exceção na sonda vira leitura fora em vez de derrubar o processo" do
    assert %Leitura{resultado: :fora, detalhe: "sonda quebrou"} =
             Verificador.medir(alvo(), SondaQuebrada)
  end

  test "o processo verifica, grava no histórico e publica no tópico do espaço" do
    alvo = alvo(tipo: :demo, espaco: :demo, intervalo: 60_000, perfil: %{base: 1, variacao: 0})
    Phoenix.PubSub.subscribe(Vigia.PubSub, Verificador.topico(:demo))

    start_supervised!({Verificador, alvo})
    Verificador.verificar_agora(alvo.id)

    assert_receive {:leitura, %Leitura{alvo_id: id, resultado: :no_ar}}, 1_000
    assert id == alvo.id
    assert {%Leitura{}, _} = Historico.situacao(alvo.id)
  end
end
