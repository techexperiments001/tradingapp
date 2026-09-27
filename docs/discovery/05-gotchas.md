# Gotchas and risks

Ordered by how much damage each one does if it is missed.

## 1. `TBTRDSTQ.STQ_TRADE_DATA` is binary inside a `CHAR(88)` column

The settlement queue row is the `TRDORDER` copybook record — packed decimal
(`COMP-3`) and big-endian binary (`COMP`) fields — moved into a character
column (layout in `02-data-dictionary.md`). Converting the table from EBCDIC to
UTF-8, or reading the column as a string in the target, silently corrupts
quantities, amounts and account numbers. Keep it as bytes or normalise it into
real columns during the port.

## 2. Every inter-program call is dynamic

`CALL WS-CUSTOMER-CHECK`, `CALL WS-SAC-BOOKING`, `CALL WS-EXCEPTION-HANDLER` —
the callee name lives in a working-storage field, not a literal. Any tool that
builds a call graph from `CALL 'NAME'` finds nothing. See
`01-call-graph.md` for the resolved graph.

## 3. `TRDPB003` declares `PROGRAM-ID. TRDPB002`

`cobol/TRDPB003` carries `PROGRAM-ID. TRDPB002` and a comment header that also
says `TRDPB002`. On z/OS the load module name comes from the link-edit member,
so the mismatch is invisible today; in any environment where the `PROGRAM-ID`
resolves the call (GnuCOBOL, a Java port keyed on program name), `TRDPB001`
will call the securities booking program twice and never touch money accounts.
This must be fixed deliberately, and the fix must not change mainframe
behaviour.

## 4. Packed decimal and rounding

All money and quantity columns are `DECIMAL(9,2)`/`DECIMAL(12,2)` held as
`COMP-3`. COBOL `ROUNDED` is half-up; IEEE floating point and Python's default
`ROUND_HALF_EVEN` are not. Use `BigDecimal`/`Decimal` with explicit
`ROUND_HALF_UP` and scale 2 everywhere. A single half-even rounding site
produces one-cent-per-account divergence that no code review will find.

## 5. `SQLCODE` is control flow, not error handling

The programs branch on specific SQLCODEs: `100` (no more rows) ends cursors and
is *also* reported as a `DATA` exception when a buy side has nothing to settle;
`-803` (duplicate key) is caught and turned into an `UPDATE` in `TBTRDLOG` and
in the exception insert. A port that maps "any SQL exception" to a single error
path changes behaviour. Map each code explicitly.

## 6. Transaction boundaries are checkpoint-based, not per-record

Both drivers `COMMIT` every `LK-CHKP-FREQUENCY` records (`0100` in every
control card, floored at 100). The securities leg and the money leg of a trade
land in the same unit of work as up to 99 other trades. Per-record transactions
in the target would change what survives a mid-run failure and how restart
works.

## 7. Abend, not return code

`TRDPBEXC` ends fatal paths with `CALL 'ILBOABN0'` and abend code 255, and every
job carries `COND=(8,LT)`. The target needs an equivalent hard-stop that the
scheduler treats the same way; returning a non-zero exit code is not
automatically equivalent.

## 8. Timestamps are `CHAR(26)` built in COBOL

`TBTRDLOG` start/end timestamps are formatted from `ACCEPT FROM DATE YYYYMMDD` /
`ACCEPT FROM TIME` into a character column, and the DB2 `CURRENT_TIMESTAMP`
alternative is commented out in the source. They have no sub-second precision
and no timezone, they sort as text, and they must be normalised before any
output comparison.

## 9. EBCDIC, code page 1140, `TRUNC(BIN)`, `ARITH(EXTEND)`

The compiler listings show `CODEPAGE(1140)`, `TRUNC(BIN)` and `ARITH(EXTEND)`
for the DB2 programs (`TRDPB007` is compiled `ARITH(COMPAT)`). Code page 1140
is EBCDIC with the euro sign, so the seed files in
`db2/mainframe-db2-setup/input/` are EBCDIC with embedded packed fields — they
are not readable as text and must be converted field-by-field, not with
`iconv`. `TRUNC(BIN)` changes how binary fields truncate on overflow.

## 10. Report layout is part of the contract

The reports are `FBA` with an ANSI carriage-control character in column 1,
page breaks driven by counters, and `PIC Z(3)`-style edited numerics. The
comparison against `output/*.MF` is byte-exact, so column positions, blank
padding and page-break behaviour all have to be reproduced.

## 11. Ten currencies, hard-coded twice

The currency list appears as an `88` level in `TRDPB000`/`TRDPB001`
(`LK-CURRENCY`), as the currency→exchange `EVALUATE`, and as ten DB2 partition
boundaries in `TBTRDORD`/`TBTRDMAC`/`TBTRDSAC`/`TBTRDPOS`/`TBTRDSTQ` DDL. Adding
a currency today means changing COBOL, DDL, JCL and control cards; the target
should make this data, but that is a *deliberate* behaviour change to agree with
the business, not a silent refactor.

## 12. `TRDPB007` is dead code in this repository

No JCL or control card runs it. It is the only program that needs IBM MQ (and
the only reason `CMQV` and friends are in `copybook/`). Confirm whether it runs
from somewhere outside this repository before scoping MQ work.

## 13. Copybooks are not in the repository

The 23 members the programs `COPY`/`INCLUDE` are missing; they were recovered
from `compiler-listings/` by `tools/extract_copybooks.py` into `copybook/`.
They are reconstructions, faithful to what the compiler saw at the time each
listing was produced (2023 for most programs, 2024 for `TRDPB007`). If the
mainframe libraries are available, diff them against these before relying on
them.
