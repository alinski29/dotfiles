#!/usr/bin/env bash
# Chromium launcher for agent-browser inside the nono sandbox.
#
# agent-browser always launches Chromium with `--remote-debugging-port=0` and then waits for Chromium to write
# `DevToolsActivePort` into the user-data-dir. Neither half works under Landlock: nono refuses to emit a port-0 rule
# on Linux (it is macOS-only), and when an explicit port is passed instead, Chromium serves CDP but never writes
# `DevToolsActivePort` (it only publishes that file for a port it picked itself).
#
# This shim picks a port from the profile's allowed range and writes the discovery file itself, so the stock
# launch path - `agent-browser open`, the pi browser tools, `sessionMode: fresh` - works unmodified.
#
# Wire it up with AGENT_BROWSER_EXECUTABLE_PATH pointing at this file.
set -uo pipefail

args=()
user_data_dir=
for arg in "$@"; do
  case "$arg" in
    # Repinned below: 0 is denied by the sandbox, any other value suppresses the discovery file.
    --remote-debugging-port=* | --remote-debugging-address=*) continue ;;
    --user-data-dir=*) user_data_dir="${arg#--user-data-dir=}" ;;
  esac
  args+=("$arg")
done

# Start at a pid-derived offset so two concurrent launches rarely race for the same port, then take the first port
# in 9222-9242 (the range the nono profile grants) that is actually free.
port="$(python3 - "$(($$ % 21))" <<'PYTHON'
import socket, sys
for offset in range(21):
    candidate = 9222 + (int(sys.argv[1]) + offset) % 21
    probe = socket.socket()
    try:
        probe.bind(("127.0.0.1", candidate))
        print(candidate)
        break
    except OSError:
        pass
    finally:
        probe.close()
PYTHON
)"
if [[ -z "$port" ]]; then
  printf 'agent-browser-chrome: no free CDP port in 9222-9242\n' >&2
  exit 1
fi

chromium "${args[@]}" --remote-debugging-port="$port" --remote-debugging-address=127.0.0.1 &
browser=$!
trap 'kill "$browser" 2>/dev/null' INT TERM HUP

publish_devtools_port() {
  python3 - "$port" "$user_data_dir" "$browser" <<'PYTHON'
import json, os, sys, time, urllib.request

port, user_data_dir, browser_pid = sys.argv[1], sys.argv[2], int(sys.argv[3])
if not user_data_dir:
    sys.exit(0)

deadline = time.time() + 20
while time.time() < deadline:
    try:
        with urllib.request.urlopen(f"http://127.0.0.1:{port}/json/version", timeout=2) as response:
            debugger_url = json.load(response)["webSocketDebuggerUrl"]
        # "/devtools/browser/<id>" - Chromium keeps the leading slash, so do we.
        path = debugger_url.split(f":{port}", 1)[1]
    except Exception:
        if not os.path.exists(f"/proc/{browser_pid}"):
            sys.exit(1)
        time.sleep(0.1)
        continue
    target = os.path.join(user_data_dir, "DevToolsActivePort")
    partial = f"{target}.shim"
    with open(partial, "w") as handle:
        handle.write(f"{port}\n{path}")
    os.replace(partial, target)
    sys.exit(0)
PYTHON
}
publish_devtools_port &

wait "$browser"
