import json
from pathlib import Path
import socket
import subprocess
import sys
import time


def check_candidate(engine, strategy):
    with socket.socket() as listener:
        listener.bind(("127.0.0.1", 0))
        port = listener.getsockname()[1]
    arguments = [
        "-H:discord.com i.ytimg.com" if argument == "{palka_targets}" else argument
        for argument in strategy["commandArgs"]
    ]
    with subprocess.Popen(
        [engine, "-i", "127.0.0.1", "-p", str(port), *arguments],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
    ) as process:
        try:
            deadline = time.monotonic() + 3
            while True:
                if process.poll() is not None:
                    raise RuntimeError(process.stderr.read().decode(errors="replace"))
                try:
                    with socket.create_connection(("127.0.0.1", port), timeout=1) as client:
                        client.sendall(bytes([5, 1, 0]))
                        response = bytearray()
                        while len(response) < 2:
                            chunk = client.recv(2 - len(response))
                            if not chunk:
                                raise RuntimeError("SOCKS handshake closed")
                            response.extend(chunk)
                        if response != bytes([5, 0]):
                            raise RuntimeError("SOCKS handshake rejected")
                    break
                except OSError:
                    if time.monotonic() >= deadline:
                        raise
                    time.sleep(0.05)
            print(f"PASS {strategy['id']}: native parser and SOCKS5 handshake")
        finally:
            process.terminate()
            try:
                process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()


if __name__ == "__main__":
    catalog = json.loads(Path(sys.argv[2]).read_text())
    candidates = [strategy for strategy in catalog["strategies"] if not strategy.get("deprecated", False)]
    if not candidates:
        raise SystemExit("No active strategies found")
    for candidate in candidates:
        check_candidate(sys.argv[1], candidate)
