#!/usr/bin/env bash
#  vim:ts=4:sts=4:sw=4:et
#
#  Author: Hari Sekhon
#  Date: 2016-02-10 23:18:47 +0000 (Wed, 10 Feb 2016)
#
#  https://github.com/harisekhon/nagios-plugins
#
#  License: see accompanying Hari Sekhon LICENSE file
#
#  If you're using my code you're welcome to connect with me on LinkedIn and optionally send me feedback
#
#  https://www.linkedin.com/in/harisekhon
#

set -euo pipefail
[ -n "${DEBUG:-}" ] && set -x
srcdir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "$srcdir/.."

. "$srcdir/utils.sh"

section "A l l u x i o"

export ALLUXIO_VERSIONS="${@:-${ALLUXIO_VERSIONS:-latest 1.0 1.1 1.2 1.3 1.4 1.5 1.6}}"

ALLUXIO_HOST="${DOCKER_HOST:-${ALLUXIO_HOST:-${HOST:-localhost}}}"
ALLUXIO_HOST="${ALLUXIO_HOST##*/}"
ALLUXIO_HOST="${ALLUXIO_HOST%%:*}"
export ALLUXIO_HOST

export ALLUXIO_MASTER_PORT_DEFAULT=19999
export ALLUXIO_WORKER_PORT_DEFAULT=30000

startupwait 30

check_docker_available

trap_debug_env alluxio

test_alluxio(){
    local version="$1"
    section2 "Setting up Alluxio $version test container"
    if is_CI; then
        VERSION="$version" docker-compose pull $docker_compose_quiet
    fi
    VERSION="$version" docker-compose up -d
    echo "getting Alluxio dynamic port mappings:"
    docker_compose_port "Alluxio Master"
    docker_compose_port "Alluxio Worker"
    hr
    when_ports_available "$ALLUXIO_HOST" "$ALLUXIO_MASTER_PORT" "$ALLUXIO_WORKER_PORT"
    hr
    if [ -n "${NOTESTS:-}" ]; then
        exit 0
    fi
    if [ "$version" = "latest" ]; then
        echo "latest version, fetching latest version from DockerHub master branch"
        local version="$(dockerhub_latest_version alluxio)"
        echo "expecting version '$version'"
    fi
    hr
    echo "retrying for $startupwait secs to give Alluxio time to initialize"
    SECONDS=0
    count=1
    while true; do
        echo "try $count: "
        if ./check_alluxio_master_version.py -v -e "$version" -t 5 &&
           ./check_alluxio_worker_version.py -v -e "$version" -t 5; then
            echo "Alluxio Master & Worker up after $SECONDS secs, continuing with tests"
            break
        fi
        # ! [] is better then [ -gt ] because if either variable breaks the test will fail correctly
        if ! [ $SECONDS -le $startupwait ]; then
            echo "FAIL: Alluxio did not start up within $startupwait secs"
            exit 1
        fi
        let count+=1
        sleep 1
    done
    hr
    run ./check_alluxio_master_version.py -v -e "$version"
    hr
    run_fail 2 ./check_alluxio_master_version.py -v -e "fail-version"
    hr
    run_conn_refused ./check_alluxio_master_version.py -v -e "$version"
    hr
    run ./check_alluxio_worker_version.py -v -e "$version"
    hr
    run_fail 2 ./check_alluxio_worker_version.py -v -e "fail-version"
    hr
    run_conn_refused ./check_alluxio_worker_version.py -v -e "$version"
    hr
    run ./check_alluxio_master.py -v
    hr
    run_conn_refused ./check_alluxio_master.py -v
    hr
    run ./check_alluxio_worker.py -v
    hr
    run_conn_refused ./check_alluxio_worker.py -v
    hr
    run ./check_alluxio_running_workers.py -v
    hr
    run_conn_refused ./check_alluxio_running_workers.py -v
    hr
    run ./check_alluxio_dead_workers.py -v
    hr
    run_conn_refused ./check_alluxio_dead_workers.py -v
    hr
    echo "Completed $run_count Alluxio tests"
    hr
    [ -n "${KEEPDOCKER:-}" ] ||
    docker-compose down
    echo
}

run_test_versions Alluxio
