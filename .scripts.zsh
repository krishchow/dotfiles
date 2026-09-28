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

# Print only the given column(s) of each line, e.g. `ls -la | field 1`.
# SPEC is a comma-separated list of 1-based indices, negative indices counting
# from the end, and ranges: `1`, `-1`, `1,3`, `2-4`, `3-` (to end of line).
# Splits on runs of whitespace unless -d gives an explicit delimiter, which is
# also used to join the output. Named `field` because `col`/`column` are taken.
field() {
    local delim=""
    while [[ "$1" == -d* ]]; do
        if [[ "$1" == "-d" ]]; then
            delim="$2"; shift 2
        else
            delim="${1#-d}"; shift
        fi
    done
    if [[ -z "$1" ]]; then
        echo "usage: field [-d DELIM] SPEC [FILE...]" >&2
        return 1
    fi
    local spec="$1"; shift
    awk -v spec="$spec" -v delim="$delim" '
    BEGIN {
        n = split(spec, toks, ",")
        if (delim != "") { FS = delim; OFS = delim } else { OFS = " " }
    }
    {
        out = ""; first = 1
        for (i = 1; i <= n; i++) {
            t = toks[i]
            if (t ~ /^-?[0-9]+$/) {
                lo = hi = t + 0
                if (lo < 0) { lo = hi = NF + 1 + lo }
            } else if (t ~ /^[0-9]+-$/) {
                lo = substr(t, 1, length(t) - 1) + 0; hi = NF
            } else if (t ~ /^[0-9]+-[0-9]+$/) {
                split(t, r, "-"); lo = r[1] + 0; hi = r[2] + 0
            } else {
                printf("field: bad spec: %s\n", t) > "/dev/stderr"
                bad = 1; exit 2
            }
            for (j = lo; j <= hi; j++) {
                if (j < 1 || j > NF) continue
                out = out (first ? "" : OFS) $j
                first = 0
            }
        }
        print out
    }
    END { if (bad) exit 2 }
    ' "$@"
}
