#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from email.parser import BytesParser
from email.policy import SMTP


class DebugHandler:
    async def handle_DATA(self, server, session, envelope):
        data = envelope.content

        parser = BytesParser(policy=SMTP)
        email = parser.parsebytes(data)

        print("---------- MESSAGE FOLLOWS ----------")
        for k, v in email.items():
            print("%s: %s" % (k, v))
        print()
        if email.is_multipart():
            for part in email.iter_parts():
                print("--- %s ---" % (part.get_content_type(),))
                for k, v in part.items():
                    print("%s: %s" % (k, v))
                print()
                print(part.get_content())
        else:
            print(email.get_content())
        print("------------ END MESSAGE ------------")
        print()
        print()

        return "250 OK"


if __name__ == "__main__":
    from aiosmtpd.controller import Controller
    import sys

    server = Controller(DebugHandler(), hostname=sys.argv[1], port=sys.argv[2])
    server.start()
    input("")
    server.stop()
