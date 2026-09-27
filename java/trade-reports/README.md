# trade-reports

Java 17 / Spring Batch port of the reporting cluster. First program: `TRDPB006`
(`TRADERPT` job), the customer-wise trading order report written to `REPORDER`.

Reporting was converted first because it is read-only and has a byte-exact
golden in `output/`, so the toolchain is proven without risking state.

## Layout

| COBOL | Java |
| --- | --- |
| `CLIENT_ORDERS` cursor | `TradeOrderReportJobConfig.CLIENT_ORDERS` + `JdbcCursorItemReader` |
| host variables of the fetch | `TradeOrderRow` |
| `3000-FETCH-PROCESS-ORDERS` header state machine | `TradeOrderReportWriter` |
| `WORKING-STORAGE` print lines | `ReportLayout` |
| edited pictures (`PIC X`, `9`, `Z`, `-,---,---.00`) | `Pic` |
| `REPORT-FILE` / `WRITE ... AFTER ADVANCING` | `PrintFile` |

Two data sources: Spring Batch keeps its metadata in an in-memory H2, the
trading data is read from the portable H2 database in `db2/portable-db2-h2/`,
opened read-only.

## Running

```bash
mvn spring-boot:run \
  -Dspring-boot.run.arguments="--trade.report.reporder-file=target/reports/REPORDER"
```

Override `TRADE_DB` (or `--trade.datasource.url`) to point at another database,
and `reportFile` as a job parameter to write elsewhere.

## Equivalence

`TradeOrderReportEquivalenceTest` runs the job and asserts the output is
byte-for-byte identical to
`output/CLOUDFRM.TRADING.BATCHDB2.REPORDER.REPORT.MF` — 11,816 records,
carriage control included.

The shipped H2 database is pre-run state (every order still `101`) and is not
the run the golden report came from, so `GoldenReportFixture` replays the three
run-dependent columns (`ORD_STATUS`, `ORD_QUANTITY`, `ORD_AMOUNT`) from the
report onto a copy of the database, and requires each replayed row to match
exactly one order. Everything the diff actually exercises — the four-way join
and self-join, the ordering, the sectioning, the pagination and every edited
picture — still comes from the database and the port. A post-run database dump
from the mainframe would remove the replay; it is on the fixture request list
in `docs/discovery/03-equivalence-harness.md`.

```bash
mvn test
```
