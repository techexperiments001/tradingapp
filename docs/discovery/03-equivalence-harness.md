# Equivalence harness

Modernisation only stays safe if every port is checked against machine-readable
evidence of the legacy behaviour. This repository already ships both halves of
that evidence, which is unusual and worth exploiting immediately.

## What we already have

| Half | Artifact |
|---|---|
| Input state | `db2/portable-db2-h2/Trade-db.mv.db` — H2 2.x, schema `TRADE`, 10,000 orders all at `ORD_STATUS='101'`, empty `TBTRDSTQ`/`TBTRDSUM`/`TBTRDLOG`/`TBTRDEXC` |
| Expected output | `output/*.MF` — the four reports from a mainframe run |

Opening the database:

```bash
java -cp h2-2.2.224.jar org.h2.tools.Shell \
     -url "jdbc:h2:$PWD/db2/portable-db2-h2/Trade-db" -user sa -password "" \
     -sql "select ord_status, count(*) from trade.tbtrdord group by ord_status"
```

## The loop

```
             ┌────────────────────────────────────────────┐
  fixture ──▶│ legacy run  (mainframe, or GnuCOBOL+ESQL)  │──▶ golden reports + table dump
             └────────────────────────────────────────────┘
                                                              byte/field diff
             ┌────────────────────────────────────────────┐
  fixture ──▶│ ported run  (Java / Python, same DB)       │──▶ reports + table dump
             └────────────────────────────────────────────┘
```

Compare on two levels, not one:

1. **Reports** — byte-for-byte against `output/*.MF`, including the
   carriage-control character in column 1 and trailing blanks.
2. **Final table state** — a deterministic dump of `TBTRDORD` (status per trade
   id), `TBTRDPOS`, `TBTRDMAC`, `TBTRDSUM`. Reports alone will not catch a
   balance that is right in total but wrong per account.

Fields that legitimately differ every run must be normalised before diffing:
`TBTRDLOG.LOG_START_TS` / `LOG_END_TS`, the `Page :` counters and any date line
in the report headers. Normalise them; do not exclude whole records.

## Running the legacy code locally (optional, and not required)

GnuCOBOL 3.1.2 installs from Ubuntu's archive and compiles batch COBOL, but this
application is DB2-bound: every program is full of `EXEC SQL`, which GnuCOBOL
does not process. Two workable routes:

- **GixSQL or OceSQL precompiler + PostgreSQL.** Load the H2 data into
  PostgreSQL, precompile the `EXEC SQL`, and the programs become runnable
  locally. Cost: building the precompiler, translating the DB2 dialect
  (`WITH HOLD` cursors, `-803`/`100` SQLCODE handling, identity columns) and
  emulating `ILBOABN0`.
- **Do not run the legacy at all.** The golden reports already record the
  legacy behaviour for this fixture; port against them and get additional
  fixtures from a mainframe UAT run when a case is not covered.

The second route is the cheaper default. Take the first only when you need to
generate new fixtures faster than the mainframe team can produce them.

## What is already wired up

`java/trade-reports` is the Spring Batch port of `TRDPB006`, and
`TradeOrderReportEquivalenceTest` is the first live instance of this harness:
it runs the job against the H2 fixture and asserts the 11,816-record output is
byte-for-byte identical to `output/CLOUDFRM.TRADING.BATCHDB2.REPORDER.REPORT.MF`.

One caveat it documents in code: the shipped H2 database is pre-run state (all
orders `101`) and does not belong to the run that produced the golden report,
so the test replays `ORD_STATUS`, `ORD_QUANTITY` and `ORD_AMOUNT` from the
report onto a copy of the database before running the job. A post-run database
dump from the mainframe removes the replay — it is the first item on the
fixture request list below.

## Where the goldens are thin

`output/*.MF` is one run of one dataset. Before conversion starts, ask the
mainframe team for runs that exercise:

- a **post-run dump of `TBTRDORD`** for the run the reports in `output/` came
  from (see above);
- every overdue status `301`–`308` (the current exception report only shows
  inactive-customer and a few other cases);
- a settlement that fails on the money leg after the securities leg succeeded
  (status `401`);
- a checkpoint restart, i.e. an abend part-way through a currency;
- an empty currency (no buy orders — `TRDPB000` reports a `DATA` exception).
