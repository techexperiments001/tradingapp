#!/usr/bin/env python3
"""Reconstruct missing copybooks and DCLGENs from IBM Enterprise COBOL listings.

The repository ships COBOL sources that ``COPY``/``EXEC SQL INCLUDE`` members which
are not committed. The compiler listings in ``compiler-listings/`` contain the fully
expanded text of every member, so the members can be recovered from them.

Listing layout (IBM Enterprise COBOL 4.1, ``SOURCE,MAP,XREF``)::

    col  3.. 9  LineID
    col     9  'C' when the line came from a COPY member
    col 18..98  the 80-column source image

``EXEC SQL INCLUDE`` expansions are not flagged with 'C'; they follow the
commented-out ``*****END-EXEC``. Most carry no sequence number, but members such
as ``EXCPCOPY`` are themselves sequence-numbered fixed-format source and so are
indistinguishable from program text by layout alone. The extractor therefore also
walks the right-margin sequence numbers of the original ``cobol/`` member in
lockstep: the DB2 coprocessor preserves them even on the statements it comments
out, so while an include is open a line whose margin sequence is not the
program's next one came from that include.
"""
from __future__ import annotations

import argparse
import re
from pathlib import Path

TEXT_START, TEXT_END = 18, 98
COPY_FLAG_COL = 9
# Column 1 carries an ANSI carriage-control character on the first line of a page.
LINE_ID = re.compile(r"^[01+\- ]{0,3}\d{6}")
SOURCE_SEQ = re.compile(r"^\d{6}")
COPY_STMT = re.compile(r"\bCOPY\s+[\"']?([A-Z0-9#@$]+)[\"']?", re.IGNORECASE)
INCLUDE_STMT = re.compile(r"\bINCLUDE\s+([A-Z0-9#@$]+)", re.IGNORECASE)
# The source listing section is delimited by `/* PROGNAME` and `*/ PROGNAME`;
# the cross-reference sections that follow it must not be parsed as source.
SECTION_START = re.compile(r"^0?\s*/\*\s+\S+\s*$")
SECTION_END = re.compile(r"^\s*\*/\s+\S+\s*$")
COMMENTED_SQL = re.compile(r"^(\s*)\*{5}")
GENERATED_CALL = re.compile(
    r"^\s*(PERFORM SQL-INITIAL UNTIL SQL-INIT-DONE|CALL 'DSNHLI' USING SQL-PLIST\d+|END-CALL)\s*$"
)


def margin_sequences(source: Path) -> list[str]:
    """Right-margin (columns 73-80) sequence numbers of a member, in source order."""
    return [
        margin
        for raw in source.read_text(encoding="latin-1").splitlines()
        if (margin := raw.ljust(80)[72:80].strip())
    ]


def restore_sql(lines: list[str]) -> list[str]:
    """Undo the DB2 coprocessor's rewrite of executable SQL.

    The coprocessor comments out each ``EXEC SQL`` block with ``*****`` and emits
    a ``CALL 'DSNHLI'`` sequence in its place. DCLGEN members are left alone:
    their ``*****EXEC SQL DECLARE`` block is commented out in the member itself
    and has no generated call after it.
    """
    restored: list[str] = []
    index = 0
    while index < len(lines):
        start = index
        while index < len(lines) and COMMENTED_SQL.match(lines[index]):
            index += 1
        block, after = lines[start:index], index
        while after < len(lines) and GENERATED_CALL.match(lines[after]):
            after += 1
        if block and after > index:
            restored += [COMMENTED_SQL.sub(r"\1     ", line) for line in block]
            index = after
            continue
        if block:
            restored += block
            continue
        if not GENERATED_CALL.match(lines[index]):
            restored.append(lines[index])
        index += 1
    return restored


def extract(listing: Path, source: Path | None = None) -> dict[str, list[str]]:
    members: dict[str, list[str]] = {}
    program = margin_sequences(source) if source and source.exists() else []
    cursor = 0
    pending_copy: str | None = None
    pending_include: str | None = None
    in_include = False
    text = listing.read_text(encoding="latin-1").splitlines()
    # Listings compiled without the DB2 coprocessor carry no section markers.
    in_source = not any(SECTION_START.match(line) for line in text)

    for raw in text:
        if SECTION_START.match(raw):
            in_source = True
            continue
        if SECTION_END.match(raw):
            break
        if not in_source or not LINE_ID.match(raw[:9]):
            continue
        window = raw[TEXT_START:TEXT_END].ljust(TEXT_END - TEXT_START)
        if not window.strip():
            continue
        flag = raw[COPY_FLAG_COL] if len(raw) > COPY_FLAG_COL else " "
        has_seq = bool(SOURCE_SEQ.match(window))
        margin = window[72:80].strip()
        # Blank out the sequence area rather than dropping it, so the recovered
        # member keeps fixed-format column alignment.
        body = (" " * 6 + window[6:72] if has_seq else window[:72]).rstrip()

        if flag == "C":
            if pending_copy:
                members.setdefault(pending_copy, []).append(body)
            in_include = False
            continue

        if margin and program:
            # Lines the compiler generated carry a margin sequence of their own
            # member, which never continues the program's own numbering.
            is_original = cursor < len(program) and program[cursor] == margin
            if is_original:
                cursor += 1
        else:
            is_original = has_seq or bool(margin)

        if is_original:
            in_include = False
            statement = body.lstrip().lstrip("*").strip().upper()
            if statement.startswith("EXEC SQL"):
                pending_include = None
            if match := INCLUDE_STMT.match(statement):
                pending_include = match.group(1).upper()
            elif match := COPY_STMT.search(body):
                pending_copy = match.group(1).upper()
            if statement.startswith("END-EXEC") and pending_include:
                in_include = True
            continue

        if in_include and pending_include:
            members.setdefault(pending_include, []).append(body)

    return members


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--listings", default="compiler-listings")
    parser.add_argument("--sources", default="cobol")
    parser.add_argument("--out", default="copybook")
    args = parser.parse_args()

    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)

    collected: dict[str, list[str]] = {}
    sources: dict[str, set[str]] = {}
    for listing in sorted(Path(args.listings).glob("*.list")):
        for name, lines in extract(listing, Path(args.sources) / listing.stem).items():
            sources.setdefault(name, set()).add(listing.stem)
            member = restore_sql(lines)
            if name not in collected or len(member) > len(collected[name]):
                collected[name] = member

    for name, lines in sorted(collected.items()):
        target = out_dir / f"{name}.cpy"
        target.write_text("\n".join(lines) + "\n")
        print(f"{name:10s} {len(lines):5d} lines  from {','.join(sorted(sources[name]))}")


if __name__ == "__main__":
    main()
