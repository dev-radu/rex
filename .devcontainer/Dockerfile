FROM debian:bookworm-slim

RUN groupadd -g 1000 rex && \
    useradd -u 1000 -g rex -m -s /bin/bash devcontainer && \
    echo PS1=\"\\e[1\;32m\\u\\e[0m \\e[1m⟶\\e[0m \\e[34m\\w\\e[0m \\$ \" \
    >> /home/devcontainer/.bashrc && mkdir -p /home/devcontainer/rex

ENTRYPOINT [ "sh", "-c", "while sleep 1000; do :; done" ]
