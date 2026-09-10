#!/bin/bash
set -o errexit

while test $# -gt 0; do

    # Do whatever you want
    case $1 in
        docker)
            systemctl daemon-reload
            ;;
    esac

    shift
done