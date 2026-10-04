#!/usr/bin/env python3
"""Tiny local RPC backend for this example: two methods, no persistence, no
real auth. It exists only to give Iris.Client something real to call over
HTTP, matching the error-envelope shape Iris.Client.decodeResponse expects
({"error": {"code", "message"}}). It also serves this directory's static
files, so the demo page and the RPC endpoints share one origin and port."""
import functools
import http.server
import json
import sys
from pathlib import Path

TOKEN = "demo-token"


class Handler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def _send_json(self, status, payload):
        body = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length) if length else b"{}"
        try:
            request = json.loads(raw or b"{}")
        except json.JSONDecodeError:
            request = {}

        if self.path == "/rpc/v1/greet":
            name = request.get("name", "")
            if not name:
                self._send_json(400, {"error": {"code": "empty_name",
                                                 "message": "Name must not be empty"}})
            else:
                self._send_json(200, {"message": f"Hello, {name}!"})
        elif self.path == "/rpc/v1/secret":
            if self.headers.get("Authorization") == f"Bearer {TOKEN}":
                self._send_json(200, {"secret": "The cake is a lie."})
            else:
                self._send_json(401, {"error": {"code": "unauthorized",
                                                 "message": "Missing or invalid bearer token"}})
        else:
            self._send_json(404, {"error": {"code": "not_found",
                                             "message": "No such RPC method"}})


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8090
    handler = functools.partial(Handler, directory=str(Path(__file__).resolve().parent))
    server = http.server.ThreadingHTTPServer(("127.0.0.1", port), handler)
    print(f"Serving examples/client and the demo RPC backend on http://127.0.0.1:{port}")
    print(f"Valid token for /rpc/v1/secret: {TOKEN}")
    server.serve_forever()


if __name__ == "__main__":
    main()
