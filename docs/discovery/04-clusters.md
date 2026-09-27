# Migration clusters

Clusters are groups of programs that must be converted together because they
share a call boundary or a table. Each cluster below can be given to a separate
Devin session; the ordering only matters where a dependency is listed.

| # | Cluster | Programs | Why it is separable | Risk |
|---|---|---|---|---|
| 1 | Master data APIs | `MSTPB001`, `MSTPB002` | Pure single-table lookups behind a fixed linkage record; no writes, no transaction state | Low |
| 2 | Reporting | `TRDPB006`, `TRDPB004` | Read-only; validated byte-for-byte against `output/*.MF` | Low, high payoff |
| 3 | Exception handling | `TRDPBEXC` + `EXCPCOPY` | Called by everything, but its contract is one record in / one row out | Medium — abend semantics |
| 4 | Book-keeping legs | `TRDPB002`, `TRDPB003` | Each updates exactly one balance table from the 88-byte trade record | Medium — decimal arithmetic |
| 5 | Settlement driver | `TRDPB001` + `SUMMCOPY`/`SUMMARY` | Depends on 3 and 4 | High — transaction boundaries |
| 6 | Acceptance / matching | `TRDPB000` | Depends on 1 and 3; the largest program (1,376 lines) | High — the actual business rules |
| 7 | Job orchestration | 22 JCL members + control cards + `TRDPROC` | Replaceable by a scheduler once 1–6 exist | Medium |
| 8 | MQ publisher | `TRDPB007` | Orphaned — no job runs it | Defer, confirm with the business |

## Suggested order

1. **Cluster 2 first.** The reports are read-only and there is a byte-exact
   golden for each, so the first conversion proves the whole toolchain
   (data access, decimal formatting, page breaks, carriage control) without
   risking any state.
2. **Clusters 1 and 3** — small, and everything else calls them.
3. **Cluster 4**, then **5**, then **6**.
4. **Cluster 7** last: 20 of the 22 jobs are the same two jobs parameterised by
   currency, so the scheduler definition is a 10-way fan-out of acceptance
   followed by a per-currency settlement, not 22 distinct jobs.

## Parallelism that already exists

The application is already partitioned by currency: `TBTRDORD`, `TBTRDMAC`,
`TBTRDSAC`, `TBTRDPOS` and `TBTRDSTQ` are all partitioned or keyed on currency,
and `ACCP<CCY>` jobs are run concurrently. A target design that serialises the
ten currencies will meet the batch window differently from today — keep the
per-currency partitioning.
