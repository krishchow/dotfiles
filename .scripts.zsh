# Kill whatever process is listening on the given port, e.g. `port_kill 3000`
port_kill() {
    if [[ -z "$1" ]]; then
        echo "usage: port_kill <port>" >&2
        return 1
    fi
    local pids
    pids=$(lsof -ti "tcp:$1" -sTCP:LISTEN) || { echo "nothing listening on port $1" >&2; return 1; }
    echo "$pids" | xargs kill -9
}
