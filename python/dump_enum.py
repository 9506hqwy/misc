#!/usr/bin/env python3

import sys
from clang.cindex import (
    Cursor,
    CursorKind,
    Index,
)


def collect(cursor: Cursor) -> None:
    try:
        if cursor.kind == CursorKind.TYPEDEF_DECL:
            child = next(cursor.get_children())
            if child.kind == CursorKind.ENUM_DECL:
                print(cursor.spelling)

                for const in child.get_children():
                    if const.kind != CursorKind.ENUM_CONSTANT_DECL:
                        continue

                    print("    %s\t = %d" % (const.spelling, const.enum_value))

        for child in cursor.get_children():
            collect(child)
    except StopIteration:
        pass


def main():
    index = Index.create()
    tu = index.parse(None, sys.argv)

    for diag in tu.diagnostics:
        print(diag)

    collect(tu.cursor)


if __name__ == "__main__":
    # dump_enm.py <FILE> [Clang Option]....
    main()
