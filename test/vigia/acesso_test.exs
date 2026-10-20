defmodule Vigia.AcessoTest do
  use ExUnit.Case, async: true

  alias Vigia.Acesso

  test "o hash gerado confere só com a mesma senha" do
    hash = Acesso.gerar_hash("cavalo-bateria-grampo")

    assert "pbkdf2-sha256$600000$" <> _ = hash
    assert Acesso.confere?("cavalo-bateria-grampo", hash)
    refute Acesso.confere?("cavalo-bateria-grampa", hash)
    refute hash == Acesso.gerar_hash("cavalo-bateria-grampo")
  end

  test "hash malformado ou ausente nunca confere" do
    refute Acesso.confere?("x", nil)
    refute Acesso.confere?("x", "")
    refute Acesso.confere?("x", "md5$1$a$b")
    refute Acesso.confere?("x", "pbkdf2-sha256$abc$AA==$AA==")
    refute Acesso.confere?("x", "pbkdf2-sha256$1$não-é-base64$AA==")
  end
end
