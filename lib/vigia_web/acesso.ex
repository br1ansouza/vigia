defmodule VigiaWeb.Acesso do
  @moduledoc """
  Decide o espaço de quem abre o painel: `:real` com sessão válida, `:demo`
  sem ela.
  """

  import Phoenix.Component, only: [assign: 3]

  alias Vigia.Acesso

  def on_mount(:padrao, _params, session, socket) do
    espaco = if autenticado?(session), do: :real, else: :demo

    {:cont,
     socket
     |> assign(:espaco, espaco)
     |> assign(:login_habilitado, Acesso.habilitado?())}
  end

  @spec autenticado?(map()) :: boolean()
  def autenticado?(%{"acesso" => marca}) when is_binary(marca),
    do: Plug.Crypto.secure_compare(marca, Acesso.marca() || "")

  def autenticado?(_session), do: false

  @spec ip(Plug.Conn.t()) :: String.t()
  def ip(conn) do
    case Plug.Conn.get_req_header(conn, "x-forwarded-for") do
      [] -> conn.remote_ip |> :inet.ntoa() |> to_string()
      valores -> valores |> Enum.join(",") |> String.split(",") |> List.last() |> String.trim()
    end
  end
end
