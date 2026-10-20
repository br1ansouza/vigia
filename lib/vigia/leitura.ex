defmodule Vigia.Leitura do
  @moduledoc """
  O resultado de uma verificação.
  """

  @enforce_keys [:alvo_id, :em, :resultado]
  defstruct [:alvo_id, :em, :resultado, :latencia, :detalhe]

  @type resultado :: :no_ar | :lento | :fora
  @type t :: %__MODULE__{
          alvo_id: String.t(),
          em: integer(),
          resultado: resultado(),
          latencia: non_neg_integer() | nil,
          detalhe: String.t() | nil
        }
end
