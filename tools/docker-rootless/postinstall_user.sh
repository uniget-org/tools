#!/bin/bash
set -o errexit

# TODO: Copy systemd unit
# TODO: Replace $HOME in systemd unit
# TODO: systemctl --user daemon-reload
# TODO: systemctl --user start docker

# Background knowledge:
#echo -n rootless | sha256sum
#12b961af5feb3e9d39f93b2cefb9a1a944f18d02cca0cac2f04f5a982240605f  -
#cat .docker/contexts/meta/12b961af5feb3e9d39f93b2cefb9a1a944f18d02cca0cac2f04f5a982240605f/meta.json
#{"Name":"rootless","Metadata":{"Description":"Rootless Docker"},"Endpoints":{"docker":{"Host":"unix:///home/rootless/.cache/dockerd-rootless/docker.sock","SkipTLSVerify":false}}}
docker context create rootless \
    --description "Rootless Docker" \
    --docker "host=unix://${HOME}/.cache/dockerd-rootless/docker.sock"
#cat .docker/config.json
#{"currentContext": "rootless"}
docker context use rootless
