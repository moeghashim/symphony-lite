FROM elixir:1.19.5-otp-28-bookworm AS build

RUN apt-get update && \
    apt-get install -y --no-install-recommends build-essential git ca-certificates && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app/elixir

ENV MIX_ENV=prod

COPY elixir/mix.exs elixir/mix.lock ./
COPY elixir/config ./config

RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix deps.get --only prod

COPY elixir ./

RUN mix deps.compile && \
    mix escript.build

FROM elixir:1.19.5-otp-28-bookworm AS runtime

ARG CODEX_VERSION=0.114.0

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      git \
      gh \
      curl \
      ca-certificates \
      nodejs \
      npm \
      python3 \
      openssh-client && \
    npm install -g "@openai/codex@${CODEX_VERSION}" && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=build /app/elixir /app/elixir
COPY .agents /app/.agents
COPY docker/railway-entrypoint.sh /usr/local/bin/railway-entrypoint

RUN chmod +x /usr/local/bin/railway-entrypoint && \
    mkdir -p /data/workspaces /data/log

ENV MIX_ENV=prod
ENV PORT=8080
ENV WORKFLOW_PATH=/app/elixir/WORKFLOW.railway.md
ENV SYMPHONY_LOGS_ROOT=/data/log

EXPOSE 8080

ENTRYPOINT ["railway-entrypoint"]
