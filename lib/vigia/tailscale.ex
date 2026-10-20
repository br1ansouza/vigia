defmodule Vigia.Tailscale do
  @moduledoc """
  Cliente da API do Tailscale com cache. Um único processo guarda o token e a
  última lista de dispositivos; todas as sondas `:tailscale` perguntam a ele.
  Como o `call` é serializado, várias sondas ao mesmo tempo geram uma só ida à
  API.

  Credenciais, em ordem de preferência:

    * `TAILSCALE_OAUTH_ID` e `TAILSCALE_OAUTH_SEGREDO`: cliente OAuth com
      leitura de `devices:core`. Não expira; o token de 1 h é renovado aqui.
    * `TAILSCALE_TOKEN`: token de API, expira em até 90 dias.
  """

  use GenServer

  @api "https://api.tailscale.com/api/v2"
  @validade_lista :timer.seconds(20)
  @folga_token :timer.minutes(5)

  @type dispositivo :: %{
          nome: String.t(),
          hostname: String.t(),
          conectado: boolean(),
          visto_em: DateTime.t() | nil
        }

  def start_link(opcoes), do: GenServer.start_link(__MODULE__, opcoes, name: __MODULE__)

  @spec dispositivos() :: {:ok, [dispositivo()]} | {:erro, String.t()}
  def dispositivos, do: GenServer.call(__MODULE__, :dispositivos, :timer.seconds(20))

  @impl true
  def init(_opcoes), do: {:ok, %{token: nil, token_expira: 0, lista: nil, lida_em: 0}}

  @impl true
  def handle_call(:dispositivos, _de, estado) do
    agora = System.monotonic_time(:millisecond)

    if estado.lista && agora - estado.lida_em < @validade_lista do
      {:reply, {:ok, estado.lista}, estado}
    else
      case buscar(estado, agora) do
        {:ok, lista, estado} -> {:reply, {:ok, lista}, %{estado | lista: lista, lida_em: agora}}
        {:erro, motivo, estado} -> {:reply, {:erro, motivo}, estado}
      end
    end
  end

  defp buscar(estado, agora) do
    with {:ok, token, estado} <- token(estado, agora),
         {:ok, %Req.Response{status: 200, body: %{"devices" => brutos}}} <-
           Req.get(requisicao(), url: "/tailnet/-/devices", auth: {:bearer, token}) do
      {:ok, Enum.map(brutos, &converter/1), estado}
    else
      {:erro, motivo, estado} ->
        {:erro, motivo, estado}

      {:ok, %Req.Response{status: 401}} ->
        {:erro, "credencial do Tailscale recusada", %{estado | token: nil}}

      {:ok, %Req.Response{status: status}} ->
        {:erro, "API do Tailscale respondeu #{status}", estado}

      {:error, erro} ->
        {:erro, "API do Tailscale: #{Exception.message(erro)}", estado}
    end
  end

  defp token(%{token: token, token_expira: expira} = estado, agora)
       when is_binary(token) and agora < expira,
       do: {:ok, token, estado}

  defp token(estado, agora) do
    case credenciais() do
      {:token, token} ->
        {:ok, token, %{estado | token: token, token_expira: :infinity}}

      {:oauth, id, segredo} ->
        case Req.post(requisicao(),
               url: "/oauth/token",
               form: [client_id: id, client_secret: segredo, grant_type: "client_credentials"]
             ) do
          {:ok, %Req.Response{status: 200, body: %{"access_token" => token, "expires_in" => s}}} ->
            expira = agora + :timer.seconds(s) - @folga_token
            {:ok, token, %{estado | token: token, token_expira: expira}}

          {:ok, %Req.Response{status: status}} ->
            {:erro, "OAuth do Tailscale respondeu #{status}", estado}

          {:error, erro} ->
            {:erro, "OAuth do Tailscale: #{Exception.message(erro)}", estado}
        end

      nil ->
        {:erro, "credenciais do Tailscale não configuradas", estado}
    end
  end

  defp credenciais do
    config = Application.get_env(:vigia, __MODULE__, [])

    case {config[:oauth_id], config[:oauth_segredo], config[:token]} do
      {id, segredo, _} when is_binary(id) and id != "" and is_binary(segredo) ->
        {:oauth, id, segredo}

      {_, _, token} when is_binary(token) and token != "" ->
        {:token, token}

      _ ->
        nil
    end
  end

  defp requisicao do
    Req.new(base_url: @api, retry: false, receive_timeout: 10_000)
    |> Req.merge(Application.get_env(:vigia, :req_tailscale, []))
  end

  defp converter(bruto) do
    %{
      nome: bruto["name"],
      hostname: bruto["hostname"],
      conectado: bruto["connectedToControl"] == true,
      visto_em: data(bruto["lastSeen"])
    }
  end

  defp data(nil), do: nil

  defp data(texto) do
    case DateTime.from_iso8601(texto) do
      {:ok, data, _} -> data
      _ -> nil
    end
  end
end
