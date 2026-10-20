defmodule Vigia.Sonda do
  @moduledoc """
  Contrato de uma sonda. O verificador mede o tempo da chamada; a sonda só diz
  se o alvo respondeu como esperado.
  """

  alias Vigia.Alvo

  @callback verificar(Alvo.t()) :: {:ok, String.t() | nil} | {:erro, String.t()}

  @spec para(Alvo.t()) :: module()
  def para(%Alvo{tipo: :http}), do: Vigia.Sonda.Http
  def para(%Alvo{tipo: :demo}), do: Vigia.Sonda.Demo
end
