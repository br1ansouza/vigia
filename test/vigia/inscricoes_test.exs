defmodule Vigia.InscricoesTest do
  use ExUnit.Case, async: false

  alias Vigia.Inscricoes

  defp b64(bin), do: Base.url_encode64(bin, padding: false)

  defp inscricao(endpoint) do
    {publica, _} = :crypto.generate_key(:ecdh, :prime256v1)

    %{
      "endpoint" => endpoint,
      "keys" => %{"p256dh" => b64(publica), "auth" => b64(:crypto.strong_rand_bytes(16))}
    }
  end

  test "adiciona, lista e remove" do
    endpoint = "https://push.teste/#{System.unique_integer([:positive])}"

    assert :ok = Inscricoes.adicionar(inscricao(endpoint))
    assert Enum.any?(Inscricoes.todas(), &(&1.endpoint == endpoint))

    Inscricoes.remover(endpoint)
    refute Enum.any?(Inscricoes.todas(), &(&1.endpoint == endpoint))
  end

  test "recusa endpoint sem https e chaves de tamanho errado" do
    assert {:error, :invalida} = Inscricoes.adicionar(inscricao("http://push.teste/x"))

    curta = put_in(inscricao("https://push.teste/y"), ["keys", "auth"], b64(<<1, 2, 3>>))
    assert {:error, :invalida} = Inscricoes.adicionar(curta)

    assert {:error, :invalida} = Inscricoes.adicionar(%{"endpoint" => "https://x"})
  end
end
