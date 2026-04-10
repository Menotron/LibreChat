FROM node:20-bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl jq \
  && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash vscode
RUN mkdir -p /workspaces && chown -R vscode:vscode /workspaces
WORKDIR /workspaces
