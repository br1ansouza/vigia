defmodule Vigia.PushTest do
  use ExUnit.Case, async: false

  alias Vigia.Push

  @rfc %{
    texto: "When I grow up, I want to be a watermelon",
    as_publica:
      "BP4z9KsN6nGRTbVYI_c7VJSPQTBtkgcy27mlmlMoZIIgDll6e3vCYLocInmYWAmS6TlzAC8wEqKK6PBru3jl7A8",
    as_privada: "yfWPiYE-n46HLnH0KqZOF1fJJU3MYrct3AELtAQ-oRw",
    ua_publica:
      "BCVxsr7N_eNgVRqvHtD0zTZsEc6-VV-JvLexhqUzORcxaOzi6-AYWXvTBHm4bjyPjs7Vd8pZGH6SRpkNtoIAiw4",
    sal: "DGv6ra1nlYgDCS1FRnbzlw",
    auth: "BTBZMqHH6r4Tts7J_aSIgg",
    cabecalho:
      "DGv6ra1nlYgDCS1FRnbzlwAAEABBBP4z9KsN6nGRTbVYI_c7VJSPQTBtkgcy27mlmlMoZIIgDll6e3vCYLocInmYWAmS6TlzAC8wEqKK6PBru3jl7A8",
    cifrado: "8pfeW0KbunFT06SuDKoJH9Ql87S1QUrdirN6GcG7sFz1y1sqLgVi1VhjVkHsUoEsbI_0LpXMuGvnzQ"
  }

  test "reproduz byte a byte o exemplo da RFC 8291" do
    d = &Push.de_b64/1

    corpo =
      Push.cifrar(@rfc.texto, d.(@rfc.ua_publica), d.(@rfc.auth),
        sal: d.(@rfc.sal),
        chaves_servidor: {d.(@rfc.as_publica), d.(@rfc.as_privada)}
      )

    assert corpo == d.(@rfc.cabecalho) <> d.(@rfc.cifrado)
  end

  describe "VAPID" do
    setup do
      chaves = Push.gerar_chaves()
      Application.put_env(:vigia, Push, Map.to_list(chaves) ++ [contato: "https://vigia.teste"])
      on_exit(fn -> Application.delete_env(:vigia, Push) end)
      chaves
    end

    test "o JWT é aceito pela chave pública e aponta para a origem do serviço de push", chaves do
      cabecalho = Push.vapid("https://fcm.googleapis.com/fcm/send/abc", 1_000)

      assert ["vapid t=" <> jwt, "k=" <> k] = String.split(cabecalho, ", ")
      assert k == chaves.publica

      [cab, corpo, assinatura] = String.split(jwt, ".")
      assert %{"alg" => "ES256"} = cab |> Push.de_b64() |> Jason.decode!()

      assert %{
               "aud" => "https://fcm.googleapis.com",
               "exp" => 44_200,
               "sub" => "https://vigia.teste"
             } =
               corpo |> Push.de_b64() |> Jason.decode!()

      <<r::256, s::256>> = Push.de_b64(assinatura)
      der = :public_key.der_encode(:"ECDSA-Sig-Value", {:"ECDSA-Sig-Value", r, s})

      assert :crypto.verify(:ecdsa, :sha256, cab <> "." <> corpo, der, [
               Push.de_b64(chaves.publica),
               :prime256v1
             ])
    end

    test "o corpo vai marcado como aes128gcm" do
      assert {"content-encoding", "aes128gcm"} in Push.cabecalhos("https://push.teste/x")
    end

    test "envio trata inscrição vencida e erro do serviço" do
      {ua_publica, _} = :crypto.generate_key(:ecdh, :prime256v1)

      inscricao = %{
        endpoint: "https://push.teste/x",
        p256dh: ua_publica,
        auth: :crypto.strong_rand_bytes(16)
      }

      Req.Test.stub(Push, fn conn ->
        ["vapid t=" <> _] = Plug.Conn.get_req_header(conn, "authorization")
        ["86400"] = Plug.Conn.get_req_header(conn, "ttl")
        Plug.Conn.send_resp(conn, 201, "")
      end)

      assert Push.enviar(inscricao, %{titulo: "oi"}) == :ok

      Req.Test.stub(Push, &Plug.Conn.send_resp(&1, 410, ""))
      assert Push.enviar(inscricao, %{titulo: "oi"}) == :expirada

      Req.Test.stub(Push, &Plug.Conn.send_resp(&1, 500, ""))
      assert {:erro, "serviço de push respondeu 500"} = Push.enviar(inscricao, %{titulo: "oi"})
    end
  end
end
