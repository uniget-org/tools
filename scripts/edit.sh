#!/bin/bash
set -o errexit

function usage() {
    echo "Usage: $0 <command> [args...]"
}

if test -z "$1"; then
    usage
    exit 1
fi

function main() {
    if test "$#" == 0; then
        usage
        exit 1
    fi

    COMMAND=$1
    shift

    if test -z "$COMMAND"; then
        usage
        exit 1
    fi

    case $COMMAND in
        "tag")

            command_tag "$@"
            ;;
        *)
            echo "Unknown command: $COMMAND"
            exit 1
            ;;
    esac
}

function usage_tag() {
    echo "Usage: $0 tag <subcommand> [args...]"
    echo "Subcommands:"
    echo "  add <tag> <tool> [<tool>...]"
    echo "  remove <tag> <tool> [<tool>...]"
}

function command_tag() {
    if test "$#" == 0; then
        usage_tag
        exit 1
    fi

    SUBCOMMAND=$1
    shift

    if test -z "$SUBCOMMAND"; then
        usage_tag
        exit 1
    fi

    case $SUBCOMMAND in
        "add")
            if test "$#" == 0; then
                usage_tag
                exit 1
            fi
            tag="$1"
            shift
            if test "$#" == 0; then
                usage_tag
                exit 1
            fi
            for tool in $@; do
                if test -f "tools/${tool}/manifest.yaml"; then
                    echo "Adding tag ${tag} to ${tool}"
                    tag="${tag}" yq --inplace '.tags = (.tags *+ [env(tag)] | unique)' "tools/${tool}/manifest.yaml"
                    sed -i -E 's/^  -/-/' "tools/${tool}/manifest.yaml"
                else
                    echo "Tool ${tool} does not exist"
                    exit 1
                fi
            done
            ;;

        "remove")
            if test "$#" == 0; then
                usage_tag
                exit 1
            fi
            tag="$1"
            shift
            if test "$#" == 0; then
                usage_tag
                exit 1
            fi
            for tool in $@; do
                if test -f "tools/${tool}/manifest.yaml"; then
                    echo "Removing tag ${tag} from ${tool}"
                    tag="${tag}" yq --inplace 'del( .tags[] | select(. == env(tag)) )' "tools/${tool}/manifest.yaml"
                    sed -i -E 's/^  -/-/' "tools/${tool}/manifest.yaml"
                else
                    echo "Tool ${tool} does not exist"
                    exit 1
                fi
            done
            ;;

        *)
            echo "Unknown subcommand: $SUBCOMMAND"
            exit 1
            ;;
    esac
}

main "$@"