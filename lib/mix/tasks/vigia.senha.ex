defmodule Mix.Tasks.Vigia.Senha do
  @shortdoc "Gera o valor de VIGIA_SENHA_HASH"
  @moduledoc """
  Pede a senha sem mostrar no terminal e imprime o hash para `VIGIA_SENHA_HASH`.

      mix vigia.senha
  """

  use Mix.Task

  @impl true
  def run(_args) do
    senha = ler_oculto("Senha: ")
    confirmacao = ler_oculto("Repita: ")

    cond do
      senha != confirmacao -> Mix.raise("As senhas não conferem")
      String.length(senha) < 12 -> Mix.raise("Use pelo menos 12 caracteres")
      true -> Mix.shell().info(Vigia.Acesso.gerar_hash(senha))
    end
  end

  defp ler_oculto(prompt) do
    IO.write(prompt)
    :io.setopts(echo: false)
    senha = IO.gets("") |> to_string() |> String.trim_trailing("\n")
    :io.setopts(echo: true)
    IO.write("\n")
    senha
  end
end
