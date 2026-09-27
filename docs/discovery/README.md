# Discovery

Read-only analysis of the TradingApp mainframe artifacts, and the plan for
modernising them without changing behaviour.

| Document | Contents |
|---|---|
| [`00-inventory.md`](00-inventory.md) | Jobs, programs, tables, data files, recovered copybooks |
| [`01-call-graph.md`](01-call-graph.md) | Call graph, order status lifecycle, per-program business logic |
| [`02-data-dictionary.md`](02-data-dictionary.md) | DB2 ↔ COBOL ↔ target type mapping, table and report layouts |
| [`03-equivalence-harness.md`](03-equivalence-harness.md) | How to prove a port behaves identically, using the fixtures already in this repo |
| [`04-clusters.md`](04-clusters.md) | Independently convertible slices and the order to do them in |
| [`05-gotchas.md`](05-gotchas.md) | The 13 things that will break a naive conversion |
| [`06-optimization-opportunities.md`](06-optimization-opportunities.md) | COBOL, DB2 and JCL optimizations, with the exact code change for each |

## Getting started in one page

1. **Recover the copybooks** (they are not in the repository; the compiler
   listings contain them):

   ```bash
   python3 tools/extract_copybooks.py      # writes copybook/
   ```

2. **Open the portable database** — `db2/portable-db2-h2/Trade-db.mv.db` is an
   H2 copy of the full DB2 schema in its pre-run state (10,000 orders, all
   `ORD_STATUS='101'`), and `output/*.MF` holds the mainframe reports from the
   run over that data. Together they are a complete input/output fixture.

3. **Start with the reports** (cluster 2 in `04-clusters.md`). `TRDPB006` is
   read-only, has a byte-exact golden, and exercises the parts of the toolchain
   every later conversion needs.

4. **Diff on two levels** — reports byte-for-byte *and* the final contents of
   `TBTRDORD`, `TBTRDPOS`, `TBTRDMAC`, `TBTRDSUM`. See
   `03-equivalence-harness.md`.

5. **Ask the mainframe team for the missing fixtures** listed at the end of
   `03-equivalence-harness.md` before converting the settlement and acceptance
   clusters.
