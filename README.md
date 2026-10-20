# Vigia

Painel que uso pra saber se meus projetos estão no ar. Escrevi em Elixir porque queria aprender a linguagem com alguma coisa que eu fosse usar de verdade.

https://vigia.gigalixirapp.com

Sem login aparece uma demonstração com serviços inventados. Os meus ficam atrás de senha.

![Painel em modo demonstração](docs/painel.png)

## Como funciona

Cada serviço monitorado é um GenServer. Ele acorda no intervalo configurado, faz a verificação, grava o resultado numa tabela ETS e avisa pelo PubSub. O LiveView recebe o aviso e reenvia só o cartão daquele serviço.

O painel mostra as últimas 24 horas, e elas ficam em memória, no ETS. Pra não perder tudo a cada deploy, uma vez por minuto cada serviço vira uma linha no Postgres gratuito do Gigalixir, com o `term_to_binary` comprimido das leituras. Na subida, o Vigia restaura isso antes de voltar a verificar. Não usei Ecto: são três comandos SQL com Postgrex.

```
Vigia.Monitor (rest_for_one)
├── Registry            acha o processo de cada serviço pelo id
├── Vigia.Historico     dono das tabelas ETS
├── Vigia.Retrato       salva e restaura o histórico no Postgres
├── DynamicSupervisor
│   └── Vigia.Verificador (um por serviço)
└── Task                sobe os verificadores
```

Usei `rest_for_one` pra que, se o `Historico` cair e as tabelas sumirem, os verificadores reiniciem depois dele. Testei matando o processo na mão.

O gráfico de barras é SVG montado no servidor. O único JavaScript é o que já vem com o LiveView.

As câmeras de casa só existem dentro da minha rede Tailscale, e o Vigia não entra nela. Ele pergunta pra API do Tailscale se o aparelho está conectado. Um processo guarda o token e a lista de aparelhos por 20 segundos, assim várias verificações ao mesmo tempo viram uma chamada só.

A senha fica salva só como hash PBKDF2, feito com o `:crypto` do próprio Erlang. O login trava depois de cinco tentativas erradas do mesmo IP.

## Rodando local

Precisa de Erlang 29 e Elixir 1.20 (estão no `.tool-versions`).

```sh
mix setup
mix phx.server
```

Em `localhost:4000` aparece a demonstração. Pra testar com serviços de verdade:

```sh
export VIGIA_ALVOS="$(cat alvos.example.json)"
export VIGIA_SENHA_HASH='<saída do mix vigia.senha>'
mix phx.server
```

## Configuração

Tudo por variável de ambiente, nada fica no repositório.

| Variável | |
|---|---|
| `SECRET_KEY_BASE` | `mix phx.gen.secret` |
| `PHX_HOST` | domínio público |
| `VIGIA_SENHA_HASH` | `mix vigia.senha`. Sem ela, só a demonstração funciona |
| `VIGIA_ALVOS` | lista JSON, exemplo em `alvos.example.json` |
| `TAILSCALE_OAUTH_ID` e `TAILSCALE_OAUTH_SEGREDO` | cliente OAuth com leitura de Devices Core |
| `DATABASE_URL` | opcional. Sem ele, o histórico some quando o app reinicia |

Cada serviço tem `id`, `nome` e `tipo` (`http` ou `tailscale`). O `http` pede `url` e o `tailscale` pede `dispositivo`, que é o nome da máquina no Tailscale. Opcionais: `intervalo` e `tempo_limite` em segundos (padrão 30 e 5) e `lento_ms` (padrão 1500).

Tem também `aceita_status`. Existe por causa do PistaCerta, que bloqueia acesso de fora do Brasil e responde 403 pro Vigia, que roda nos EUA. Com `"aceita_status": [403]`, esse 403 conta como no ar.

## Deploy

Roda no plano gratuito do Gigalixir.

```sh
gigalixir create -n vigia
gigalixir config:set SECRET_KEY_BASE="$(mix phx.gen.secret)" PHX_HOST=vigia.gigalixirapp.com
git push gigalixir main
```
