# Debian v12.1 Bookworm (Slim Version)
FROM debian:bookworm-slim

ARG NODE_MAJOR_VERSION
ARG PNPM_MAJOR_VERSION

ARG GROUP_NAME
ARG USERNAME
ARG SHELL

COPY setup.sh .

RUN chmod +x setup.sh && ./setup.sh --quiet

# Necessary for DevContainer configuration.
ENTRYPOINT [ "bash", "-c", "sleep infinity" ]
