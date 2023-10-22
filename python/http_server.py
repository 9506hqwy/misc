#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from http import HTTPStatus
from http.server import BaseHTTPRequestHandler
import json


class DebugHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        for k, v in self.headers.items():
            print("{}={}".format(k, v))

        length = self.headers.get("content-length")
        body = self.rfile.read(int(length))

        ctype = self.headers.get("content-type")
        if "json" in ctype:
            print(json.dumps(json.loads(body), ensure_ascii=False, indent=2))
        else:
            print(body.decode("utf-8"))

        self.send_response(HTTPStatus.OK)
        self.end_headers()


if __name__ == "__main__":
    from http.server import HTTPServer
    import os
    import ssl
    import sys

    httpd = HTTPServer((sys.argv[1], int(sys.argv[2])), DebugHandler)

    if os.path.isfile("key.pem") and os.path.isfile("cert.pem"):
        ctx = ssl.create_default_context(purpose=ssl.Purpose.CLIENT_AUTH)
        ctx.load_cert_chain("cert.pem", keyfile="key.pem")

        httpd.socket = ctx.wrap_socket(httpd.socket)

    httpd.serve_forever()
