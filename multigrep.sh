#!/usr/bin/env bash

VERSION='0.0.3'

main() {
    # Check arguments
    [[ "${#1}" -lt 1 ]] && help_exit
    [[ "$1" == '--help' ]] && help_exit

    # Declare variables, check paths
    declare -a outfiles pids
    local base_dir start_time result_dir

    base_dir="$(realpath "$1")"
    start_time="$(date '+%Y-%m-%dT%H:%M:%S')"
    result_dir="${base_dir}/.results/$start_time"

    if [ ! -d "$base_dir" ]
    then
        >&2 echo "Could not find directory '$base_dir'"
        exit 2
    fi
    if [ ! -d "$result_dir" ]
    then
        echo "Creating result directory '$result_dir'"
        mkdir -p "$result_dir"
    fi
    shift

    # Find the longest search term
    local lst=6
    for term in "$@"
    do
        [[ "${#term}" -gt "$lst" ]] && lst="${#term}"
    done

    # Start search for each parameter
    while (( "$#" ))
    do
        local term="$1"
        local outfile="${result_dir}/${term}.grep"
        outfiles+=("$outfile")

        echo "Starting search for '$term'"
        grep -rnsiIF --exclude-dir="$result_dir" "$term" "$base_dir" >"$outfile" &
        pids+=("$!")
        shift
    done

    sleep 2
    clear

    # Print status as long as search is going
    while :
    do
        # Print number of jobs running and start time
        separator
        echo "Jobs started at $start_time"

        local jobs
        jobs="$(ps --no-headers -p "${pids[@]}" | wc -l - | awk '{print $1}')"
        echo "Jobs running: $jobs"

        # Print PID table
        separator
        printf "%10s %-${lst}s %s\\n" 'PID' 'Search' 'Current File'
        for p in "${pids[@]}"
        do
            pidfile="/proc/$p/cmdline"
            if [ -f "$pidfile" ]
            then
                printf "%10s %-${lst}s %s\\n" \
                    "$p" \
                    "$(sed 's/\x0/<<split>>/g' "$pidfile" | awk -F'<<split>>' '{printf "%s", $4}')" \
                    "$(readlink "/proc/$p/fd/"[^012] | awk '{if ( length > x ) { x = length; y = $0 }} END{printf "%s\n", y}' | sed "s|$base_dir/||")"
            fi
        done

        # Print current number of results
        separator
        local res=" Results File
        "
        res+="$(wc -l "${outfiles[@]}" | sed -e "s|$result_dir/||g" -e 's/  +//g' -e 's/^ //')"
        awk '{printf "%10s %-10s\n", $1, $2}' <<<"$res"

        # Stop if no more jobs are running
        if [ "$jobs" -eq 0 ]
        then
            echo "No more jobs are running"
            break
        fi

        # Sleep
        separator
        echo "Sleeping for 10 seconds..."
        sleep 10
        clear
    done

    echo "Jobs finished at $(date '+%Y-%m-%dT%H:%M:%S')"
    exit 0
}

handle_sigint() {
    >&2 printf '\n'
    >&2 separator
    >&2 echo "Received interrupt signal!"
    >&2 echo "Stopping searches..."
    kill "${pids[@]}"
    >&2 echo "Exiting..."
    exit 1
}

separator() {
    echo '================================================================================'
}

help_exit() {
    printf 'Multigrep V%s\n' "${VERSION}"
    printf 'Usage:\n'
    printf 'grep.sh DIRECTORY TERMS...\n'
    printf 'Search recursively in DIRECTORY for any of the search TERMs.\n'
    exit 0
}

trap handle_sigint SIGINT
main "$@"

