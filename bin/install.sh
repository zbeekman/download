#!/bin/bash
#
# Install RadiaSoft containers
#
install_check() {
    if [[ $(ls -A) ]]; then
        install_err 'Current directory is not empty.
Please create a new directory, cd to it, and re-run this command.'
    fi
}

install_err() {
    install_msg "$@"
    install_msg "If you don't know what to do, please contact support@radiasoft.net."
    exit 1
}

install_err_trap() {
    set +e
    trap - ERR
    install_err 'Unexpected error; Install failed.'
}

install_main() {
    trap install_err_trap ERR
    install_check
    install_vars "$@"
    local cmd=$install_type.sh
    local file=$(dirname "$0")/$cmd
    local eval
    if [[ -r $file ]]; then
        eval=$(<$file)
    else
        eval=$(curl -L -s -S "$install_url/$cmd")
    fi
    eval "$eval"
}

install_msg() {
    echo "$@" 1>&2
}

install_usage() {
    install_err "$@
usage: $(basename $0) [vagrant|docker] beamsim|python2|sirepo"
}

install_vars() {
    case "$(uname)" in
        [Dd]arwin)
            if [[ $(type -t vagrant) ]]; then
                install_type=vagrant
            else
                install_err 'Please install Vagrant and restart install'
            fi
            ;;
        [Ll]inux)
            if [[ $(type -t docker) ]]; then
                install_type=docker
            elif [[ $(type -t vagrant) ]]; then
                install_type=vagrant
            else
                install_err 'Please install Docker or Vagrant and restart install'
            fi
            ;;
        *)
            install_err "$(uname) is an unsupported system, sorry"
            ;;
    esac
    while [[ "$1" ]]; do
        case "$1" in
            python2|beamsim|sirepo)
                install_container=radiasoft/$1
                ;;
            vagrant|docker)
                install_type=$1
                ;;
            *)
                install_usage "$1: unknown install option"
                ;;
        esac
        shift
    done
    if [[ ! $install_container ]]; then
        install_usage "Please supply a container name: beamsim, python2, or sirepo"
    fi
    install_url=https://raw.githubusercontent.com/radiasoft/download/master/bin
}

if [[ $0 == ${BASH_SOURCE[0]} ]]; then
    set -e
    install_main "$@"
fi
