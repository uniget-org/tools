#!/bin/bash
set -o errexit

while test $# -gt 0; do

    # Do whatever you want
    case $1 in
        docker)
            systemctl daemon-reload
            systemctl enable docker.socket
            systemctl start docker.socket
            systemctl enable docker.service
            ;;
    esac

    shift
done