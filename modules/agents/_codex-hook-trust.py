"""Approve every user-level Codex hook at its current hash.

Codex pins hook trust to the hook declaration and to a hash of the whole plugin
directory, so every plugin or Codex update needs a fresh approval and stale
pins make the hooks fail silently. Codex already runs with approval "never" and
full access here, so activation approves whatever hooks Codex lists for $HOME,
the same way the TUI review does: config/batchWrite of
hooks.state.<key>.trusted_hash = currentHash. Hooks inside a project's own
.codex/ are not listed for $HOME and still need approval per project.

Usage: codex-hook-trust.py <codex>
"""

import itertools
import json
import os
import signal
import subprocess
import sys

NEEDS_TRUST = ("untrusted", "modified")


def main(codex):
    home = os.environ["HOME"]
    signal.alarm(60)
    proc = subprocess.Popen(
        [codex, "app-server"],
        cwd=home,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
    )
    ids = itertools.count()

    def send(message):
        proc.stdin.write(json.dumps(message) + "\n")
        proc.stdin.flush()

    def request(method, params):
        request_id = next(ids)
        send({"id": request_id, "method": method, "params": params})
        for line in proc.stdout:
            message = json.loads(line)
            if message.get("id") != request_id:
                continue
            if "error" in message:
                raise RuntimeError(f"{method}: {message['error']}")
            return message["result"]
        raise RuntimeError(f"{method}: codex app-server exited")

    def stale_hooks():
        inventory = request("hooks/list", {"cwds": [home]})
        return {
            hook["key"]: hook["currentHash"]
            for entry in inventory["data"]
            for hook in entry["hooks"]
            if hook["trustStatus"] in NEEDS_TRUST
        }

    try:
        request("initialize", {"clientInfo": {"name": "home-manager", "version": "0"}})
        send({"method": "initialized"})
        stale = stale_hooks()
        if not stale:
            return
        edit = {key: {"trusted_hash": current} for key, current in stale.items()}
        request(
            "config/batchWrite",
            {"edits": [{"keyPath": "hooks.state", "value": edit, "mergeStrategy": "upsert"}]},
        )
        remaining = stale_hooks()
        if remaining:
            raise RuntimeError(f"still untrusted after write: {sorted(remaining)}")
        print(f"codex: trusted {len(stale)} hook(s): {', '.join(sorted(stale))}")
    finally:
        proc.terminate()


if __name__ == "__main__":
    main(sys.argv[1])
