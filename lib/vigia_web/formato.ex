defmodule VigiaWeb.Formato do
  @moduledoc false

  @spec latencia(non_neg_integer() | nil) :: {String.t(), String.t() | nil}
  def latencia(nil), do: {"—", nil}
  def latencia(ms) when ms < 1_000, do: {Integer.to_string(ms), "ms"}
  def latencia(ms), do: {decimal(ms / 1_000, 2), "s"}

  @spec porcentagem(float() | nil) :: String.t()
  def porcentagem(nil), do: "—"
  def porcentagem(valor) when valor == 100, do: "100"
  def porcentagem(valor), do: decimal(Float.floor(valor, 2), 2)

  @spec duracao(integer()) :: String.t()
  def duracao(ms) when ms < 60_000, do: "#{max(div(ms, 1_000), 0)} s"
  def duracao(ms) when ms < 3_600_000, do: "#{div(ms, 60_000)} min"

  def duracao(ms) when ms < 86_400_000,
    do: "#{div(ms, 3_600_000)} h #{rem(div(ms, 60_000), 60)} min"

  def duracao(ms), do: "#{div(ms, 86_400_000)} d #{rem(div(ms, 3_600_000), 24)} h"

  defp decimal(valor, casas) do
    valor |> :erlang.float_to_binary(decimals: casas) |> String.replace(".", ",")
  end
end
