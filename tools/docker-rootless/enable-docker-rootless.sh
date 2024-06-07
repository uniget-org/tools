#!/bin/bash
set -o errexit

if ! systemctl >/dev/null 2>&1; then
    echo "ERROR: SystemD is not available."
    exit 1
fi

if test -z "${HOME}"; then
    echo "ERROR: Environment variable HOME is not set"
    exit 1
fi

# Until "uniget env" is vailable
source <(uniget env 2>/dev/null)
if test -z "${UNIGET_TARGET}"; then
    echo "WARNING: Environment variable UNIGET_TARGET is not set."
    echo "         You are probably using an outdated version of uniget. Please update ASAP."
    UNIGET_TARGET="$( dirname $( dirname $( readlink -f $0 ) ) )"
fi

cat "${UNIGET_TARGET}/state/uniget/contrib/docker-rootless/docker.service" \
| sed "s/\${HOME}/${HOME}/" \
>"${HOME}/.config/systemd/user/docker.service"
systemctl --user daemon-reload
systemctl --user start docker

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
