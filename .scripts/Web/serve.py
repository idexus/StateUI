# SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
# SPDX-License-Identifier: Apache-2.0
#
# Serves a Web head's page: serve.py <site> <port> <facts> [<query>]. Listens on
# <port> on every interface of this machine - so a phone or a tablet on the same
# network opens the page too - on any free port where it is taken, writes
# {"url": ...} to <facts> once it listens - this machine's own address - and
# serves until it is stopped. The browser keeps nothing of it: every answer says
# not to, so a build is always the one shown.
import functools
import http.server
import json
import socket
import subprocess
import sys

site, port, facts = sys.argv[1], int(sys.argv[2]), sys.argv[3]
query = sys.argv[4] if len(sys.argv) > 4 else ""


class Page(http.server.SimpleHTTPRequestHandler):
    extensions_map = {
        **http.server.SimpleHTTPRequestHandler.extensions_map,
        ".wasm": "application/wasm", ".js": "text/javascript", ".svg": "image/svg+xml",
    }

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def log_message(self, format, *args):
        # A picture asked for as a PNG and found as its SVG answers 404 first, which says nothing wrong.
        if "/Images/" in getattr(self, "path", "") and "404" in format % args:
            return
        if not args or not str(args[1]).startswith(("2", "3")):
            super().log_message(format, *args)


class Server(http.server.ThreadingHTTPServer):
    allow_reuse_address = True


def addresses():
    """This machine's IPv4 addresses on its networks, the loopback aside."""
    try:
        listed = subprocess.run(["ifconfig"], capture_output=True, text=True).stdout.split()
        found = [listed[i + 1] for i, word in enumerate(listed[:-1]) if word == "inet"]
    except OSError:
        found = [socket.gethostbyname(socket.gethostname())]
    return [each for each in found if not each.startswith("127.")]


handler = functools.partial(Page, directory=site)
try:
    server = Server(("0.0.0.0", port), handler)
except OSError:
    server = Server(("0.0.0.0", 0), handler)

listening = server.server_address[1]
url = f"http://127.0.0.1:{listening}/{query}"
with open(facts, "w") as file:
    json.dump({"url": url}, file)
print(f"serving:    {url}", flush=True)
for each in addresses():
    print(f"            http://{each}:{listening}/{query}", flush=True)
try:
    server.serve_forever()
except KeyboardInterrupt:
    pass
