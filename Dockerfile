#syntax=docker/dockerfile
FROM docker/sandbox-templates:shell

USER root
RUN --mount=type=cache,target=/var/cache/apt <<EOF
apt-get update
apt-get install -y \
    git \
    curl
curl -sLf https://gitlab.com/uniget-org/cli/-/releases/permalink/latest/downloads/uniget_Linux_$(uname -m).tar.gz \
| sudo tar -xzC /usr/local/bin uniget
uniget install opencode
EOF

USER agent
#custom