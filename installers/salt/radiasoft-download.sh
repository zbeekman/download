#!/bin/bash
#
# To run: curl radia.run | sudo bash -s salt
#
set -e

salt_alarm() {
    local timeout=$1
    local rc=0 sleep_pid op_pid
    timeout=$1
    shift
    bash -c "$@" &
    op_pid=$!
    {
        sleep "$timeout"
        kill -9 "$op_pid" >& /dev/null || true
    } &
    sleep_pid=$!
    wait "$op_pid" >& /dev/null
    rc=$?
    kill "$sleep_pid" >& /dev/null || true
    return $rc
}

salt_assert() {
    if (( $UID != 0 )); then
        install_err 'Must run as root'
    fi
    if [[ ! -r /etc/fedora-release ]]; then
        install_err 'Only runs on Fedora'
    fi
    if ! grep -s -q ' 23 ' /etc/fedora-release; then
        install_err 'Only runs on Fedora 23'
    fi
}

salt_bootstrap() {
    # Missing dependency; Only add for dnf systems for now
    if [[ -n $(type -p dnf) ]]; then
        dnf install -y python-psutil || true
    fi
    install_download https://bootstrap.saltstack.com \
        | bash ${install_debug:+-x} -s -- \
        -P -n ${install_debug:+-D} -A $salt_master git develop
    if [[ ! -f /etc/salt/minion ]]; then
        install_err 'bootstrap.saltstrack.com failed'
    fi
    local res
    if ! res=$(systemctl status salt-minion 2>&1); then
        install_err '${res}salt-minion failed to start'
    fi
    salt_minion_id=$(cat /etc/salt/minion_id)
}

salt_main() {
    salt_assert
    salt_master
    umask 022
    salt_bootstrap
    chmod -R go-rwx /etc/salt /var/log/salt /var/cache/salt /var/run/salt
    install_msg "

You need to accept this minion on the master:

    salt-key -y -a $salt_minion_id
"
}

salt_master() {
    local res
    salt_master=${install_extra_args[0]}
    if [[ -z $salt_master ]]; then
        install_err 'Must supply salt master as extra argument'
    fi
    if ! res=$(salt_alarm 3 ": < '/dev/tcp/$salt_master/4505'"); then
        install_err "$res$salt_master: is invalid or inaccessible"
    fi
}

salt_main
