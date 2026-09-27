# Inventory

Machine-readable summary of everything in this repository, produced by reading
every COBOL, JCL, control-card, DDL and compiler-listing member.

## Batch jobs

Every job is a one-step `EXEC TRDPROC` (see `proc/TRDPROC.proc`), which runs
`IKJEFT01` (TSO batch) and takes its DSN control card from `RUNPARM`. The card
issues `DSN SYSTEM(DBCG)` / `RUN PROGRAM(...) PLAN(CLFRPLAN) PARM(...)`, so
every job is really "run one DB2-bound COBOL program with a parameter string".

| Job | Card | Program | PARM | Purpose |
|---|---|---|---|---|
| `ACCP<CCY>` (10 jobs) | `controlcard/ACCP<CCY>` | `TRDPB000` | `'<CCY> 0100'` | Validate + match buy/sell orders for one currency |
| `SETL<CCY>` (10 jobs) | `controlcard/SETL<CCY>` | `TRDPB001` | `'<CCY> 0100'` | Settle the matched trades queued by acceptance |
| `EXECRPT` | `controlcard/EXECRPT` | `TRDPB004` | none | Exception, run-log and customer-summary reports |
| `TRADERPT` | `controlcard/TRADERPT` | `TRDPB006` | none | Customer-wise detailed trade report |

`<CCY>` ∈ CAD, CHF, CNY, EUR, GBX, INR, JPY, KRW, MXN, USD. The 10 acceptance
jobs are independent of each other (partitioned by currency); `SETL<CCY>` depends
only on `ACCP<CCY>`.

`TRADERPT` additionally runs `IEFBR14` first to delete/reallocate the report
dataset, and allocates `REPORDER` as `FB/LRECL=161/RECFM=FBA` (ANSI carriage
control in column 1).

The `PARM` string is `X(3)` currency + 1 filler + `9(4)` commit frequency
(`LK-CHKP-FREQUENCY`, forced to 100 when below 100).

## Programs

| Program | Role | Called by | Calls | Tables |
|---|---|---|---|---|
| `TRDPB000` | Acceptance / matching (1,376 lines) | `ACCP<CCY>` | `MSTPB001`, `MSTPB002`, `TRDPBEXC` | `TBTRDORD`, `TBTRDSAC`, `TBTRDMAC`, `TBTRDSTQ`, `TBTRDLOG` |
| `TRDPB001` | Settlement driver (548 lines) | `SETL<CCY>` | `TRDPB002`, `TRDPB003`, `TRDPBEXC` | `TBTRDSTQ`, `TBTRDORD`, `TBTRDLOG`, `TBTRDSUM` |
| `TRDPB002` | Securities book-keeping | `TRDPB001` | `TRDPBEXC` | `TBTRDPOS` |
| `TRDPB003` | Money book-keeping | `TRDPB001` | `TRDPBEXC` | `TBTRDMAC` |
| `TRDPB004` | Exception / run-log / summary reports (822 lines) | `EXECRPT` | — | `TBTRDEXC`, `TBTRDLOG`, `TBTRDSUM`, `TBTRDSTQ` |
| `TRDPB006` | Trade order report (461 lines) | `TRADERPT` | — | `TBTRDORD`, `TBTRDCUS`, `TBTRDSEC` |
| `TRDPB007` | MQ put to `TRADING.QUEUE` | *nothing in this repo* | `MQCONN`, `MQPUT1`, `MQDISC` | — |
| `MSTPB001` | Customer master lookup API | `TRDPB000` | — | `TBTRDCUS` |
| `MSTPB002` | Security master lookup API | `TRDPB000`, `TRDPB006` | — | `TBTRDSEC` |
| `TRDPBEXC` | Exception handler / logger | all business programs | `ILBOABN0` | `TBTRDEXC` |

`TRDPB005` does not exist. `TRDPB007` is orphaned: no JCL or control card
references it, so MQ is out of scope for a behaviour-preserving migration
unless the customer confirms otherwise.

## Data

| Artifact | Contents |
|---|---|
| `db2/mainframe-db2-setup/ddl/` | Tablespace + table + index DDL for the 10 tables, plus `#CREATDB` |
| `db2/mainframe-db2-setup/input/` | EBCDIC/packed load files (`*.SMALL`) for the 6 seeded tables |
| `db2/mainframe-db2-setup/ldcntl/` | `LOAD` utility control cards |
| `db2/portable-db2-h2/Trade-db.mv.db` | **H2 2.x copy of the whole schema, pre-run state** — see below |
| `output/*.MF` | Golden report output from a mainframe run |
| `metadata/VSAMDEF` | Empty — this application uses no VSAM |

### Portable H2 database (the single most useful asset here)

`db2/portable-db2-h2/Trade-db.mv.db` opens with H2 2.2.224, user `sa`, empty
password, schema `TRADE`. Row counts:

| Table | Rows | State |
|---|---|---|
| `TBTRDORD` | 10,000 | 1,000 per currency, **all `ORD_STATUS = '101'`** (accepted, unmatched) |
| `TBTRDSEC` | 171,289 | security master |
| `TBTRDPOS` | 9,828 | opening securities positions |
| `TBTRDCUS` | 50 | customer master |
| `TBTRDSAC` | 50 | securities accounts |
| `TBTRDMAC` | 50 | money accounts |
| `TBTRDEXC`, `TBTRDLOG`, `TBTRDSUM`, `TBTRDSTQ` | 0 | produced by the run |

So the repository ships a **clean pre-run input state** and the
**post-run golden reports** in `output/`. That is exactly the input/output pair
an equivalence harness needs; see `03-equivalence-harness.md`.

## Recovered copybooks

`cobol/` `COPY`s and `EXEC SQL INCLUDE`s 23 members that are not committed.
All of them are recoverable from `compiler-listings/`, which contain the fully
expanded compile of every program. `tools/extract_copybooks.py` reconstructs
them into `copybook/`:

| Kind | Members |
|---|---|
| DCLGEN (table declaration + indicator array) | `TBTRDCUS`, `TBTRDEXC`, `TBTRDLOG`, `TBTRDMAC`, `TBTRDORD`, `TBTRDPOS`, `TBTRDSAC`, `TBTRDSEC`, `TBTRDSTQ`, `TBTRDSUM` |
| Interface records | `CUSTOMER`, `SECURITY`, `TRDORDER`, `EXCPTION` |
| Procedure copybooks | `EXCPCOPY` (report-exception paragraph), `SUMMARY` / `SUMMCOPY` (customer summary upkeep) |
| DB2 runtime | `SQLCA` |
| IBM MQ (only `TRDPB007`) | `CMQV`, `CMQMDV`, `CMQODV`, `CMQPMOV`, `CSQ4VB1` |

Nothing referenced by the sources is missing after extraction.
