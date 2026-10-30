# 06 — Optimization opportunities (COBOL, DB2, JCL)

Scope: all nine in-scope programs (`MSTPB001`, `MSTPB002`, `TRDPB000`, `TRDPB001`,
`TRDPB002`, `TRDPB003`, `TRDPB004`, `TRDPB006`, `TRDPBEXC`), the DB2 DDL, and the
JCL/PROC/control-card layer. `TRDPB007` (MQ) is out of scope.

Every item carries the code as it is today and the exact replacement. Nothing here has
been applied to the repository — this is a review, and each item is classified so it can
be scheduled.

## How to read the classification

| Class | Meaning |
| --- | --- |
| **SAFE** | No change to any observable output, status, or failure behaviour. Apply after a normal regression run. |
| **MEASURE** | Very likely a win, but the size depends on the access path or volume. Needs `EXPLAIN` or a timed run before/after. |
| **BEHAVIOUR** | Changes locking, consistency, restart granularity or output. Needs a business decision plus an equivalence fixture. |
| **DEFECT** | Not an optimization. A correctness or capacity bug found during the review. |

A caution that applies throughout: the golden fixture in `output/` is one run of one
dataset. Any change classified BEHAVIOUR or DEFECT needs a *new* fixture that exercises
the case, otherwise the equivalence harness will pass while the behaviour changes.

No timings in this document are measurements taken on this application — there is no
mainframe here to measure on. Where a magnitude is given it is a call-count arithmetic
from the source, which is verifiable; CPU claims are explicitly marked as needing a
timed run.

---

## 1. Whole-application: SQL call volume

The dominant cost of this batch is the number of crossings into DB2, not the work done
inside any one statement. Counted from the source, per accepted buy order `TRDPB000`
issues:

| # | Statement | Where |
| --- | --- | --- |
| 1 | `FETCH BUY_SIDE_ORDERS` | `TRDPB000:451` |
| 2 | singleton `SELECT` matching sell-side order | `TRDPB000:522` |
| 3 | `SELECT TBTRDCUS` (buyer) via `CALL MSTPB001` | `MSTPB001:65` |
| 4 | `SELECT TBTRDCUS` (seller) via `CALL MSTPB001` | `MSTPB001:65` |
| 5 | `SELECT TBTRDSEC` via `CALL MSTPB002` | `MSTPB002` |
| 6 | `SELECT TBTRDSAC` (buyer) | `TRDPB000:821` |
| 7 | `SELECT TBTRDSAC` (seller) | `TRDPB000:929` |
| 8 | `SELECT TBTRDMAC` (buyer) | `TRDPB000:1034` |
| 9 | `SELECT TBTRDMAC` (seller) | `TRDPB000:1138` |
| 10 | `UPDATE TBTRDORD` (buy side) | `TRDPB000:1322` |
| 11 | `UPDATE TBTRDORD` (sell side) | `TRDPB000:1322` |

≈ 11–12 SQL calls per order, so ≈ 115,000 calls for the 10,000-order golden run, and
settlement adds ≈ 8 more per trade (§4, §5). Items 1.1 and 1.2 attack that number
directly; everything in §3–§6 is smaller.

### 1.1 Multi-row FETCH on every driving cursor — **MEASURE**

All four driving cursors fetch one row per call:
`BUY_SIDE_ORDERS` (`TRDPB000:118`), `SETTLEMENT_QUEUE` (`TRDPB001:106`),
`CLIENT_ORDERS` (`TRDPB006:187`), and the three cursors in `TRDPB004:203,212,227`.

Before — `TRDPB006:284`:

```cobol
       EXEC SQL
           FETCH CLIENT_ORDERS
            INTO :ORD-TRADEID
                ,:ORD-TRADING-XCHNG
                ,:ORD-BUY-SELL-IND
                ...
       END-EXEC
```

After — declare host arrays and fetch a rowset:

```cobol
      * WORKING-STORAGE
       01  WS-ROWSET.
           05  WS-RS-MAX              PIC S9(4) COMP VALUE 100.
           05  WS-RS-COUNT            PIC S9(4) COMP VALUE 0.
           05  WS-RS-CURSOR           PIC S9(4) COMP VALUE 0.
           05  WS-RS-TRADEID          OCCURS 100 TIMES PIC X(16).
           05  WS-RS-TRADING-XCHNG    OCCURS 100 TIMES PIC X(4).
           05  WS-RS-BUY-SELL-IND     OCCURS 100 TIMES PIC X(1).
      *    ... one array per selected column ...

      * PROCEDURE DIVISION - replaces the singleton FETCH
       5100-FETCH-ROWSET.
           EXEC SQL
               FETCH NEXT ROWSET FROM CLIENT_ORDERS
                 FOR :WS-RS-MAX ROWS
                INTO :WS-RS-TRADEID
                    ,:WS-RS-TRADING-XCHNG
                    ,:WS-RS-BUY-SELL-IND
      *             ... one array per selected column ...
           END-EXEC
           MOVE SQLERRD(3) TO WS-RS-COUNT
           MOVE 0          TO WS-RS-CURSOR
           .
```

and the consumer walks `WS-RS-CURSOR` from 1 to `WS-RS-COUNT`, re-fetching when
exhausted. `SQLCODE = 100` with `SQLERRD(3) > 0` is a *partial* rowset and must still be
processed — the single most common bug when converting to rowset fetch:

```cobol
           IF SQLCODE = 100 AND WS-RS-COUNT = 0
              SET NO-MORE-ORDERS TO TRUE
           END-IF
```

The cursor must also be declared `WITH ROWSET POSITIONING`:

```cobol
           DECLARE CLIENT_ORDERS CURSOR WITH HOLD
                   WITH ROWSET POSITIONING FOR
```

Row order, row content and therefore report bytes are unchanged; only the number of
crossings changes. Classified MEASURE rather than SAFE only because the CPU saving
depends on the access path — the output equivalence is guaranteed.

### 1.2 Fold the per-order validation lookups into the driving cursor — **MEASURE**

Items 2 and 6–9 of the table above are all singleton `SELECT`s keyed off columns already
present in the fetched row. They can be joined into `BUY_SIDE_ORDERS` so one fetch
returns everything needed, taking ≈ 11 calls per order down to ≈ 3.

The exception messages must survive, and they can: keep the per-field `EVALUATE`s in
COBOL and drive them off the fetched columns and null indicators instead of off
`SQLCODE`. `LEFT OUTER JOIN` preserves the "not found" case.

Before — `TRDPB000:118`:

```sql
          DECLARE BUY_SIDE_ORDERS CURSOR WITH HOLD FOR
          SELECT ORD_TRADEID, ORD_BUY_SELL_IND, ORD_CUSTOMER_ID
                ,ORD_FIGI, ORD_QUANTITY, ORD_CURRENCY, ORD_AMOUNT
            FROM TBTRDORD
           WHERE ORD_CURRENCY      = :ORD-CURRENCY
             AND ORD_TRADING_XCHNG = :ORD-TRADING-XCHNG
             AND ORD_BUY_SELL_IND  = 'B'
             AND ORD_STATUS        = :ORD-STATUS
```

After:

```sql
          DECLARE BUY_SIDE_ORDERS CURSOR WITH HOLD
                  WITH ROWSET POSITIONING FOR
          SELECT  B.ORD_TRADEID
                 ,B.ORD_CUSTOMER_ID
                 ,B.ORD_FIGI
                 ,B.ORD_QUANTITY
                 ,B.ORD_AMOUNT
                 ,S.ORD_CUSTOMER_ID     AS SELLER_ID
                 ,S.ORD_STATUS          AS SELLER_STATUS
                 ,CB.CUS_STATUS         AS BUYER_CUS_STATUS
                 ,CS.CUS_STATUS         AS SELLER_CUS_STATUS
                 ,SE.SEC_STATUS         AS SEC_STATUS
                 ,SACB.SAC_NUMBER       AS BUYER_SAC
                 ,SACB.SAC_STATUS       AS BUYER_SAC_STATUS
                 ,SACS.SAC_NUMBER       AS SELLER_SAC
                 ,SACS.SAC_STATUS       AS SELLER_SAC_STATUS
                 ,MACB.MAC_NUMBER       AS BUYER_MAC
                 ,MACB.MAC_STATUS       AS BUYER_MAC_STATUS
                 ,MACS.MAC_NUMBER       AS SELLER_MAC
                 ,MACS.MAC_STATUS       AS SELLER_MAC_STATUS
            FROM TBTRDORD B
            LEFT OUTER JOIN TBTRDORD S
              ON  S.ORD_CURRENCY      = B.ORD_CURRENCY
              AND S.ORD_TRADING_XCHNG = B.ORD_TRADING_XCHNG
              AND S.ORD_TRADEID       = B.ORD_TRADEID
              AND S.ORD_FIGI          = B.ORD_FIGI
              AND S.ORD_BUY_SELL_IND  = 'S'
            LEFT OUTER JOIN TBTRDCUS CB  ON CB.CUS_CUSTOMER_ID = B.ORD_CUSTOMER_ID
            LEFT OUTER JOIN TBTRDCUS CS  ON CS.CUS_CUSTOMER_ID = S.ORD_CUSTOMER_ID
            LEFT OUTER JOIN TBTRDSEC SE  ON SE.SEC_FIGI        = B.ORD_FIGI
            LEFT OUTER JOIN TBTRDSAC SACB
              ON  SACB.SAC_CUSTOMER_ID = B.ORD_CUSTOMER_ID
              AND SACB.SAC_CURRENCY    = B.ORD_CURRENCY
            LEFT OUTER JOIN TBTRDSAC SACS
              ON  SACS.SAC_CUSTOMER_ID = S.ORD_CUSTOMER_ID
              AND SACS.SAC_CURRENCY    = B.ORD_CURRENCY
            LEFT OUTER JOIN TBTRDMAC MACB
              ON  MACB.MAC_CUSTOMER_ID = B.ORD_CUSTOMER_ID
              AND MACB.MAC_CURRENCY    = B.ORD_CURRENCY
            LEFT OUTER JOIN TBTRDMAC MACS
              ON  MACS.MAC_CUSTOMER_ID = S.ORD_CUSTOMER_ID
              AND MACS.MAC_CURRENCY    = B.ORD_CURRENCY
           WHERE B.ORD_CURRENCY      = :ORD-CURRENCY
             AND B.ORD_TRADING_XCHNG = :ORD-TRADING-XCHNG
             AND B.ORD_BUY_SELL_IND  = 'B'
             AND B.ORD_STATUS        = :ORD-STATUS
          FOR FETCH ONLY
```

with the "not found" branches driven by null indicators rather than `SQLCODE = 100`:

```cobol
           IF WS-IND-SELLER-SAC < 0
              SET DATA-EXCEPTION TO TRUE
      *       identical STRING / 9000-REPORT-EXCEPTION as today
           END-IF
```

Two traps make this the riskiest item in this document, and both must be handled before
it is attempted:

**The status columns must be selected, not just the account numbers.** `TRDPB000:822`
and `TRDPB000:1035` reject the order when `SAC-STATUS`/`MAC-STATUS` is not `'A'`, which
is a *different* rejection from "row not found". A join that returns only
`SAC_NUMBER`/`MAC_NUMBER` and validates on null indicators alone silently accepts orders
against inactive accounts — hence `SAC_STATUS`/`MAC_STATUS` in the select list above, and
the COBOL keeps both branches:

```cobol
           EVALUATE TRUE
               WHEN WS-IND-BUYER-SAC < 0
      *             'Buyer Security Account Not Found' path
               WHEN WS-BUYER-SAC-STATUS NOT = 'A'
      *             'Buyer Security Account Not active' path
           END-EVALUATE
```

**The account joins can multiply rows.** `X2TRDSAC` is
`(SAC_CUSTOMER_ID, SAC_CURRENCY, SAC_NUMBER)` and `X1TRDMAC` is
`(MAC_CURRENCY, MAC_NUMBER)` — neither makes `(customer, currency)` unique, so a customer
with two accounts in one currency yields two cursor rows for one buy order and the trade
is booked twice. Today that same data produces `SQLCODE = -811` on the singleton
`SELECT ... INTO`, which falls into the `WHEN OTHER` branch and rejects the order. Either
confirm with the DBA team that `(SAC_CUSTOMER_ID, SAC_CURRENCY)` is unique in practice
and enforce it with a unique index, or do not do this item — dedup in COBOL reintroduces
the per-row work the join was meant to remove.

Two caveats that make this MEASURE, not SAFE. First, the exception *order* within one
order changes if the COBOL evaluates the fetched fields in a different sequence than the
current program issues its `SELECT`s — keep the same sequence and `TBTRDEXC` rows land in
the same order. Second, `TRDPB000` must be verified not to depend on reading
`TBTRDSAC`/`TBTRDMAC` *after* an earlier update in the same order; from the source it does
not, but confirm before committing. Do this one after 1.1, and only with a post-run
`TBTRDEXC` dump as fixture.

### 1.3 Static `CALL` instead of `CALL identifier` — **SAFE**

All four call sites use a data-name whose `VALUE` is a literal, which forces dynamic
resolution:

Before — `TRDPB000:31` and `:624`:

```cobol
       05 WS-CUSTOMER-CHECK      PIC X(8) VALUE 'MSTPB001'.
      ...
           CALL WS-CUSTOMER-CHECK
                USING LS-CUSTOMER-IO
           END-CALL
```

After:

```cobol
           CALL 'MSTPB001'
                USING LS-CUSTOMER-IO
           END-CALL
```

Same in `TRDPB001:372,400` for `'TRDPB002'` / `'TRDPB003'`. At ~3 calls per order in
acceptance and 2 per trade in settlement, this removes ~50,000 dynamic-resolution
lookups per run.

Trade-off, and the reason this is a deliberate decision rather than an obvious win:
static calls are resolved at link-edit, so changing `MSTPB001` then requires relinking
`TRDPB000` instead of just replacing one load module. If the shop's release process
relies on replacing subprogram load modules independently, leave the dynamic calls and
take the resolution cost. Note also that a static `CALL 'TRDPB003'` would have failed to
link while that file still declared `PROGRAM-ID. TRDPB002` (see `05-gotchas.md`) — the
dynamic call is what hid that bug.

---

## 2. Bind-time settings (not in the repository)

No BIND JCL or bind cards are in the repo — `db2/mainframe-db2-setup/SETUP` contains
DDL and a `DSNTEP2` run only. Every program runs under one plan, `CLFRPLAN`, per the
control cards. Request the bind cards from the DBA team; these three options are usually
worth more than any source change here.

### 2.1 Split the plan: reports vs. state-changing jobs — **BEHAVIOUR**

`TRDPB006` is read-only and currently shares a plan with acceptance and settlement. Bind
its package into its own plan with uncommitted read:

```text
BIND PACKAGE(CLFRRPT) MEMBER(TRDPB006) ISOLATION(UR) CURRENTDATA(NO) -
     EXPLAIN(YES) RELEASE(DEALLOCATE)
BIND PLAN(CLFRRPTP) PKLIST(CLFRRPT.*) ACQUIRE(USE) RELEASE(DEALLOCATE)
```

and change `controlcard/TRADERPT` accordingly:

```text
  DSN SYSTEM (DBCG)
  RUN PROGRAM(TRDPB006) -
  PLAN   (CLFRRPTP)
  END
```

This removes report/settlement lock contention entirely. It also means the report can
read uncommitted settlement work, so it is a business call — for an end-of-day report run
in a quiet window the exposure is nil, for an intraday run it is not. Note `TRDPB004`
already has `WITH UR` written and commented out at line 209, and `TRDPB000`'s singleton
lookups use `WITH UR` inline, so the shop's appetite for UR is evidently non-zero.

`TRDPB004` must stay out of this plan, and it is worth being explicit about why, because
its name and its three reports make it look read-only: it is not. After printing, it
purges the tables it just reported on:

```sql
         DELETE FROM TBTRDSTQ      <== TRDPB004:792
         DELETE FROM TBTRDLOG      <== TRDPB004:796
         DELETE FROM TBTRDSUM      <== TRDPB004:800
         DELETE FROM TBTRDEXC      <== TRDPB004:804
```

UR is wrong for a program that deletes, and it needs its package in a plan with the
state-changing programs. Two consequences beyond the bind: the `PKLIST` above must not
be the only place `TRDPB004` is bound, and — more importantly operationally — `EXECRPT`
is a destructive job. It must not be rerun after a successful run, and it must not run
concurrently with acceptance or settlement writing those same tables. Neither constraint
is expressed anywhere in the JCL (see 9.9).

### 2.2 `RELEASE(DEALLOCATE)` on the settlement plan — **MEASURE**

Settlement commits every `LK-CHKP-FREQUENCY` trades (`0100` per the cards). With
`RELEASE(COMMIT)` every commit releases and re-acquires table-space locks and discards
prepared statement resources — 100 times per 10,000 trades, per currency.
`RELEASE(DEALLOCATE)` holds them for the life of the thread.

Cost: the thread holds locks until it ends, which blocks utilities (`REORG`, `LOAD`) and
DDL for the whole run. Fine for a batch window, not for a long-running thread in a 24×7
shop.

### 2.3 `REOPT(NONE)` and `DEGREE(1)` — **MEASURE**

Worth confirming rather than changing: all cursors are driven by host variables with
stable selectivity (currency, status), so `REOPT(ALWAYS)` would re-prepare on every OPEN
for no benefit. Ask what the plan is bound with today.

---

## 3. `TRDPB002` / `TRDPB003` — bookkeeping

These two are structurally identical (securities positions and money accounts) and are
the hottest path in the application: both are called once per trade, so 4 SQL calls each
× 2 programs × 2 sides.

### 3.1 Replace open/fetch/update/close with one atomic `UPDATE` — **BEHAVIOUR**

Today each booking is four SQL calls and a read-modify-write in COBOL.

Before — `TRDPB002:37,91,111,122,165` (and identically `TRDPB003:37,82,102,113,151`):

```cobol
           DECLARE POS_BOOKING  CURSOR FOR
           SELECT  POS_BALANCE
             FROM TBTRDPOS
             WHERE POS_CURRENCY   = :POS-CURRENCY
               AND POS_SAC_NUMBER = :POS-SAC-NUMBER
               AND POS_FIGI       = :POS-FIGI
             FOR UPDATE OF POS_BALANCE
      ...
           EXEC SQL OPEN  POS_BOOKING END-EXEC
      ...
           EXEC SQL FETCH POS_BOOKING INTO :POS-BALANCE END-EXEC
           IF SQLCODE = 0 THEN
              IF DEBIT-SELLER
                 COMPUTE POS-BALANCE = POS-BALANCE - TRD-ORDER-QTY
              ELSE
                 COMPUTE POS-BALANCE = POS-BALANCE + TRD-ORDER-QTY
              END-IF
              EXEC SQL
                   UPDATE TBTRDPOS
                     SET POS_BALANCE    = :POS-BALANCE
                   WHERE POS_CURRENCY   = :POS-CURRENCY
                     AND POS_SAC_NUMBER = :POS-SAC-NUMBER
                     AND POS_FIGI       = :POS-FIGI
              END-EXEC
      ...
           EXEC SQL CLOSE POS_BOOKING END-EXEC
```

After — one searched update that does the arithmetic in DB2, no cursor at all:

```cobol
           IF DEBIT-SELLER
              COMPUTE WS-POS-DELTA = 0 - TRD-ORDER-QTY
           ELSE
              MOVE TRD-ORDER-QTY TO WS-POS-DELTA
           END-IF

           EXEC SQL
                UPDATE TBTRDPOS
                   SET POS_BALANCE    = POS_BALANCE + :WS-POS-DELTA
                 WHERE POS_CURRENCY   = :POS-CURRENCY
                   AND POS_SAC_NUMBER = :POS-SAC-NUMBER
                   AND POS_FIGI       = :POS-FIGI
           END-EXEC

           EVALUATE SQLCODE
               WHEN 0
                    SET TRD-SAC-BOOKING-DONE TO TRUE
               WHEN 100
      *             position row absent - same path as today's FETCH +100
                    SET TRD-SAC-BOOKING-FAILED TO TRUE
                    SET DATA-EXCEPTION TO TRUE
      *             identical STRING / 9000-REPORT-EXCEPTION as today
               WHEN OTHER
                    SET TRD-SAC-BOOKING-FAILED TO TRUE
                    MOVE SQLCODE TO WS-SQLCODE
      *             identical STRING / 9000-REPORT-EXCEPTION as today
           END-EVALUATE
```

4 SQL calls → 1, i.e. ~60,000 calls removed from a 10,000-trade settlement run across the
two programs and two sides. It also removes a lost-update window: the current code reads
a balance into COBOL and writes back an absolute value.

Why BEHAVIOUR and not SAFE, precisely:

- the `FOR UPDATE OF` cursor takes an update lock at `FETCH` and holds it across the
  COBOL arithmetic; the searched update takes an X lock for an instant instead. That is
  *better* for concurrency but it is a different lock profile, and the currency
  partitioning means two currencies never touch the same row anyway — so verify with the
  DBA that no other application relies on the longer hold.
- `SQLCODE = 100` now means "no row updated", where today it means "no row fetched". For
  this table they coincide, because the `WHERE` clauses are identical.
- if `POS_BALANCE` is nullable the arithmetic yields null rather than failing; the DDL
  should be checked to confirm `NOT NULL`.

If that risk is unwanted, the strictly-SAFE half of this item is to use the cursor as
declared and change the update to positioned — the code even carries the intent as a
comment at `TRDPB002:128` and `TRDPB003:118`:

```cobol
              EXEC SQL
                   UPDATE TBTRDPOS
                      SET POS_BALANCE = :POS-BALANCE
                    WHERE CURRENT OF POS_BOOKING
              END-EXEC
```

That saves the index probe on the update but keeps all four calls. Prefer the single
searched update if the DBA signs off.

### 3.2 Remove or gate the diagnostic `DISPLAY`s — **SAFE**

Both programs `DISPLAY` on normal paths. Every `DISPLAY` is a QSAM write to `SYSOUT`
through the runtime — on a per-trade path that is real CPU and an unbounded spool
dataset. Either delete them or gate them:

```cobol
      * WORKING-STORAGE
       01  WS-TRACE-SW               PIC X VALUE 'N'.
           88  TRACE-ON              VALUE 'Y'.
      ...
           IF TRACE-ON
              DISPLAY 'TRDPB002 : POS-BALANCE = ' POS-BALANCE
           END-IF
```

with `WS-TRACE-SW` set from the `PARM` so it can be turned on for one run without a
recompile.

---

## 4. `TRDPB000` — acceptance

### 4.1 Index the driving cursor's predicates — **MEASURE**

The cursor at `TRDPB000:118` filters on `(ORD_CURRENCY, ORD_TRADING_XCHNG,
ORD_BUY_SELL_IND, ORD_STATUS)`. The two existing indexes are:

```sql
CREATE UNIQUE INDEX TRADE.X1TRDORD
     ( ORD_CURRENCY, ORD_TRADING_XCHNG, ORD_TRADEID, ORD_FIGI, ORD_BUY_SELL_IND );
CREATE INDEX TRADE.X2TRDORD
     ( ORD_CURRENCY, ORD_STATUS, ORD_AMOUNT );
```

`X1TRDORD` matches 2 columns then screens; `X2TRDORD` matches 2 and does not carry
`ORD_TRADING_XCHNG` or `ORD_BUY_SELL_IND`. A 4-column matching index:

```sql
CREATE INDEX TRADE.X3TRDORD
       ON TRADE.TBTRDORD
     ( ORD_CURRENCY       ASC
      ,ORD_STATUS         ASC
      ,ORD_BUY_SELL_IND   ASC
      ,ORD_TRADING_XCHNG  ASC
      ,ORD_TRADEID        ASC )
       USING STOGROUP CLFRSTG
       PARTITIONED
       BUFFERPOOL BP0
       CLOSE YES;
```

`EXPLAIN` before and after — on a partitioned table a third index is paid for on every
insert and on `REORG`, and at 10,000 rows per partition the current plan may already be
acceptable.

### 4.2 The duplicated priming `FETCH` — **SAFE**

`TRDPB000:362` and `TRDPB000:451` are the same 9-line `FETCH` written twice, the classic
read-ahead duplication. Any column added to the cursor must be added in both places or
the loop silently processes stale data.

Before:

```cobol
           EXEC SQL FETCH BUY_SIDE_ORDERS INTO ... END-EXEC     *> line 362
           IF SQLCODE = 100 ... END-IF
           PERFORM UNTIL NO-MORE-ORDERS
              ...
              EXEC SQL FETCH BUY_SIDE_ORDERS INTO ... END-EXEC  *> line 451
           END-PERFORM
```

After — one paragraph, performed twice:

```cobol
           PERFORM 5100-FETCH-ORDER THRU 5100-EXIT
           PERFORM UNTIL NO-MORE-ORDERS
              ...
              PERFORM 5100-FETCH-ORDER THRU 5100-EXIT
           END-PERFORM
           ...
       5100-FETCH-ORDER.
           EXEC SQL
               FETCH BUY_SIDE_ORDERS
                INTO :ORD-TRADEID
                    ,:ORD-BUY-SELL-IND
                    ,:ORD-CUSTOMER-ID
                    ,:ORD-FIGI
                    ,:ORD-QUANTITY
                    ,:ORD-CURRENCY
                    ,:ORD-AMOUNT
           END-EXEC
           IF SQLCODE = 100
              SET NO-MORE-ORDERS TO TRUE
           END-IF
           .
       5100-EXIT.
           EXIT.
```

Note the "no rows at all" case at line 362 also raises a `DATA-EXCEPTION` with the text
`'No BUY_SIDE_ORDERS to Settle '`, which the loop-bottom fetch does not — preserve that
by keeping the first `PERFORM` guarded, or the empty-input run will stop logging it.

This is a prerequisite for 1.1: the rowset conversion is much harder with two copies.

### 4.3 The currency → exchange `EVALUATE` is reference data in code — **SAFE**

`TRDPB000:317-338` hard-codes the mapping, and there is no `WHEN OTHER`:

```cobol
           EVALUATE ORD-CURRENCY
               WHEN 'EUR'  MOVE 'DAX'  TO ORD-TRADING-XCHNG
               WHEN 'USD'  MOVE 'NYSE' TO ORD-TRADING-XCHNG
      *        ... 8 more ...
           END-EVALUATE
```

Adding an eleventh currency to the `88` validation list without adding it here leaves
`ORD-TRADING-XCHNG` as spaces, the cursor returns zero rows, and the job ends RC 0 having
accepted nothing — a silent no-op. Unreachable today because the `88` list and the
`EVALUATE` happen to agree, which is exactly the kind of agreement that decays.

Minimum fix, no data model change:

```cobol
           EVALUATE ORD-CURRENCY
      *        ... unchanged ...
               WHEN OTHER
                    SET APPL-EXCEPTION TO TRUE
                    MOVE SPACES TO WS-EXCEPTION
                    STRING 'No exchange mapped for currency '
                           ORD-CURRENCY
                      DELIMITED BY SIZE INTO WS-EXCEPTION
                    END-STRING
                    PERFORM 9000-REPORT-EXCEPTION THRU 9000-EXIT
           END-EVALUATE
```

Proper fix: a `TBTRDXCH (XCH_CURRENCY, XCH_EXCHANGE)` reference table, or at minimum a
shared copybook table with `SEARCH ALL`, so the currency list lives in one place instead
of being duplicated across `TRDPB000` and `TRDPB001`. In the Java port this is one
`ExchangeCatalog` bean.

### 4.4 Keep the existing multi-row insert — **no change**

`TRDPB000:1277-1287` already batches the settlement queue 100 rows at a time with
`FOR :WS-STQ-INDEX ROWS NOT ATOMIC CONTINUE ON SQLEXCEPTION`. Recorded here so nobody
"optimizes" it again. The one thing worth checking is that `NOT ATOMIC CONTINUE ON
SQLEXCEPTION` means individual row failures are *not* surfaced unless `SQLERRD`/the
diagnostics area is inspected — confirm the program checks per-row status, otherwise a
dropped settlement-queue row is invisible.

---

## 5. `TRDPB001` — settlement

### 5.1 Consume the queue with a positioned delete — **MEASURE**

Before — `TRDPB001:429`, one `FETCH` then a searched `DELETE` re-probing the same row:

```cobol
           EXEC SQL
               FETCH SETTLEMENT_QUEUE
                INTO :STQ-ID, :STQ-TRADE-DATA
           END-EXEC
           EVALUATE SQLCODE
               WHEN 0
                    MOVE STQ-TRADE-DATA TO TRD-ORDER-PAIR
                    EXEC SQL
                       DELETE FROM TBTRDSTQ
                        WHERE STQ_CURRENCY = :STQ-CURRENCY
                          AND STQ_ID       = :STQ-ID
                    END-EXEC
```

After — declare the cursor `FOR UPDATE` and delete where current:

```cobol
           DECLARE SETTLEMENT_QUEUE CURSOR WITH HOLD FOR
           SELECT STQ_ID, STQ_TRADE_DATA
             FROM TBTRDSTQ
            WHERE STQ_CURRENCY = :STQ-CURRENCY
            ORDER BY STQ_CURRENCY ASC, STQ_ID ASC
              FOR UPDATE
      ...
                    EXEC SQL
                       DELETE FROM TBTRDSTQ
                        WHERE CURRENT OF SETTLEMENT_QUEUE
                    END-EXEC
```

Saves one index probe per trade. Caution: a `FOR UPDATE` cursor with `ORDER BY` may force
DB2 to materialise the result, which would *lose* the `WITH HOLD` restart property — the
existing index `(STQ_CURRENCY, STQ_ID)` should let it avoid the sort, but confirm with
`EXPLAIN` that no work file appears. If one does, keep the searched delete.

An alternative worth considering instead: drain the queue in rowsets (1.1) and delete in
batches keyed on the highest `STQ_ID` consumed. That changes restart granularity — a
crash mid-batch would re-settle already-booked trades — so it needs the checkpoint design
revisited, not just the SQL.

### 5.2 Bound the `-911` / `-913` retry — **DEFECT**

`TRDPB001:488`:

```cobol
           SET DO-SQL TO TRUE
           PERFORM UNTIL SQL-DONE
              MOVE 0 TO SQLCODE
              EXEC SQL
                  UPDATE TBTRDORD
                     SET ORD_STATUS = :ORD-STATUS
                   WHERE ...
              END-EXEC
              IF SQLCODE = -911 OR -913 THEN
                 SET RETRY-SQL TO TRUE
              ELSE
                 SET SQL-DONE  TO TRUE
              END-IF
           END-PERFORM
```

Two problems. There is no attempt limit, so a genuine deadlock cycle spins forever
holding the unit of work open; and there is no pause between attempts, so it retries at
CPU speed against a lock that is by definition held by someone else. Also `-911` means
DB2 has already rolled back the unit of work — retrying just the `UPDATE` after a `-911`
re-applies one statement on top of a *rolled-back* transaction, so the preceding queue
delete and both bookings for that trade are gone but the retry proceeds as if they
happened.

```cobol
      * WORKING-STORAGE
       01  WS-RETRY-COUNT            PIC S9(4) COMP VALUE 0.
       01  WS-RETRY-MAX              PIC S9(4) COMP VALUE 3.
      ...
           MOVE 0 TO WS-RETRY-COUNT
           SET DO-SQL TO TRUE
           PERFORM UNTIL SQL-DONE
              EXEC SQL
                  UPDATE TBTRDORD ...
              END-EXEC
              EVALUATE TRUE
                  WHEN SQLCODE = -913 AND WS-RETRY-COUNT < WS-RETRY-MAX
                       ADD 1 TO WS-RETRY-COUNT
                       CALL 'CEE3DLY' USING WS-RETRY-COUNT
                  WHEN SQLCODE = -911
      *                unit of work already rolled back - do not retry here
                       SET SQL-DONE TO TRUE
                       SET APPL-EXCEPTION TO TRUE
                       MOVE SPACES TO WS-EXCEPTION
                       STRING 'Deadlock (-911) - unit of work rolled back'
                         DELIMITED BY SIZE INTO WS-EXCEPTION
                       END-STRING
                       PERFORM 9000-REPORT-EXCEPTION THRU 9000-EXIT
                  WHEN OTHER
                       SET SQL-DONE TO TRUE
              END-EVALUATE
           END-PERFORM
```

`CEE3DLY` gives a whole-second sleep, which is coarse; if sub-second backoff matters use
a short `STIMER`-based wait module. Restarting the whole trade after `-911` (rather than
just logging) is the correct fix but changes the unit-of-work structure — treat it as a
design item for the Spring Batch port, where a `RetryTemplate` around the chunk gives it
for free.

Also note `MOVE 0 TO SQLCODE` before the `EXEC SQL`: writing to `SQLCODE` by hand is
legal but pointless — the precompiler sets it — and it masks the case where the statement
is not executed at all.

### 5.3 Checkpoint frequency is a parameter but has never been tuned — **MEASURE**

Every card passes `PARM('xxx 0100')`, so 100 trades per commit everywhere. Larger
commit scopes mean fewer log forces and fewer lock re-acquisitions, at the cost of longer
lock hold and more work to redo on restart. Run the same currency at 100 / 500 / 1000 and
pick from the curve — this is a card change only, no recompile:

```text
  RUN PROGRAM(TRDPB001) -
  PLAN   (CLFRPLAN) -
  PARM('USD 0500')
```

---

## 6. `TRDPB004` and `TRDPB006` — reporting

(`TRDPB004` reports *and then purges* `TBTRDSTQ`, `TBTRDLOG`, `TBTRDSUM`, `TBTRDEXC` —
see 2.1. Everything below applies to its read phase only.)

### 6.1 `WITH HOLD` on cursors that never commit while open — **SAFE**

`TRDPB006:187` declares `CLIENT_ORDERS ... WITH HOLD`; the only `COMMIT` is at
`TRDPB006:237`, after `CLOSE` at line 432. Same shape in all three `TRDPB004` cursors.
`WITH HOLD` therefore buys nothing and keeps resources pinned across the unit of work.

Before:

```sql
          DECLARE CLIENT_ORDERS CURSOR WITH HOLD FOR
```

After:

```sql
          DECLARE CLIENT_ORDERS CURSOR
                  WITH ROWSET POSITIONING FOR
      ...
          ORDER BY ...
          FOR FETCH ONLY
          OPTIMIZE FOR 10000 ROWS
```

`FOR FETCH ONLY` makes the read-only intent unambiguous so DB2 can use block fetch;
`OPTIMIZE FOR n ROWS` tells the optimizer the whole answer set is consumed.

### 6.2 Explicit joins in `CLIENT_ORDERS` — **SAFE**

`TRDPB006:187` uses a four-way comma join. The self-join to `TBTRDORD B` is legitimate —
it fetches the counterparty's customer id, and its predicates match 4 of the 5 columns of
`X1TRDORD`, so it is an index probe. The join *style* is the risk: drop one predicate from
that `WHERE` and you get a silent cartesian product.

Before:

```sql
       FROM TBTRDORD A, TBTRDCUS, TBTRDSEC, TBTRDORD B
      WHERE A.ORD_CUSTOMER_ID = CUS_CUSTOMER_ID
        AND A.ORD_FIGI        = SEC_FIGI
        AND A.ORD_CURRENCY     = B.ORD_CURRENCY
        AND A.ORD_TRADING_XCHNG= B.ORD_TRADING_XCHNG
        AND A.ORD_TRADEID      = B.ORD_TRADEID
        AND A.ORD_FIGI         = B.ORD_FIGI
        AND A.ORD_BUY_SELL_IND <> B.ORD_BUY_SELL_IND
```

After — identical result set, join conditions inseparable from their table:

```sql
       FROM TBTRDORD A
       INNER JOIN TBTRDCUS
               ON A.ORD_CUSTOMER_ID    = CUS_CUSTOMER_ID
       INNER JOIN TBTRDSEC
               ON A.ORD_FIGI           = SEC_FIGI
       INNER JOIN TBTRDORD B
               ON A.ORD_CURRENCY       = B.ORD_CURRENCY
              AND A.ORD_TRADING_XCHNG  = B.ORD_TRADING_XCHNG
              AND A.ORD_TRADEID        = B.ORD_TRADEID
              AND A.ORD_FIGI           = B.ORD_FIGI
              AND A.ORD_BUY_SELL_IND  <> B.ORD_BUY_SELL_IND
```

### 6.3 The report `ORDER BY` always sorts — **MEASURE**

`ORDER BY A.ORD_CUSTOMER_ID, A.ORD_BUY_SELL_IND, A.ORD_CURRENCY, A.ORD_STATUS,
A.ORD_TRADEID` leads on `ORD_CUSTOMER_ID`, which no index leads on, so DB2 sorts the
whole answer set. Irrelevant at 10,000 rows, dominant at 10 million.

```sql
CREATE INDEX TRADE.X4TRDORD
       ON TRADE.TBTRDORD
     ( ORD_CUSTOMER_ID    ASC
      ,ORD_BUY_SELL_IND   ASC
      ,ORD_CURRENCY       ASC
      ,ORD_STATUS         ASC
      ,ORD_TRADEID        ASC )
       USING STOGROUP CLFRSTG
       BUFFERPOOL BP0
       CLOSE YES;
```

A non-partitioned index leading on customer id on a currency-partitioned table is a real
maintenance cost — `EXPLAIN` first, and only add it if the sort actually shows up as
`SORTN_ORDERBY`/`SORTC_ORDERBY = Y` and the volume justifies it.

### 6.4 `TRDPB004`: three copies of the same report engine — **SAFE**

Lines 290–448 (exceptions), 459–607 (runlog) and the summary section are the same
open / header / prime-fetch / loop / trailer / close skeleton written three times, each
with its own duplicated priming `FETCH` — 822 lines that are structurally ~200. The
mechanical fix is the same read-ahead consolidation as 4.2 applied three times; the real
fix is one driver paragraph parameterised by a report-control record:

```cobol
       01  WS-RPT-CONTROL.
           05  WS-RPT-ID              PIC X(8).
           05  WS-RPT-CURSOR-SW       PIC X.
               88  RPT-EXCPTION       VALUE 'E'.
               88  RPT-RUNLOG         VALUE 'R'.
               88  RPT-SUMMARY        VALUE 'S'.
```

Worth doing only if `TRDPB004` has to be maintained in COBOL for a while. If it is going
to Java in the next slice, skip it — in the port the three reports are three
`ItemReader`/`ItemWriter` pairs sharing one job configuration, and the duplication
disappears for free.

### 6.5 The status-code `EVALUATE` is duplicated across `TRDPB004` and `TRDPB006` — **SAFE**

Same literal descriptions for `ORD_STATUS` in two programs. Reference data in two places
drifts. Extract to a copybook now:

```cobol
      * STATCAT.cpy
       01  WS-STATUS-CATALOG.
           05  FILLER PIC X(34) VALUE '0100Accepted                     '.
           05  FILLER PIC X(34) VALUE '0200Matched                      '.
      *    ... one line per status ...
       01  FILLER REDEFINES WS-STATUS-CATALOG.
           05  WS-STATUS-ENTRY OCCURS 12 TIMES
                               ASCENDING KEY IS WS-SC-CODE
                               INDEXED BY WS-SC-IX.
               10  WS-SC-CODE  PIC X(4).
               10  WS-SC-DESC  PIC X(30).
```

and in both programs:

```cobol
           SEARCH ALL WS-STATUS-ENTRY
              AT END      MOVE 'Unknown Status' TO WS-DET-STATUS
              WHEN WS-SC-CODE(WS-SC-IX) = ORD-STATUS
                          MOVE WS-SC-DESC(WS-SC-IX) TO WS-DET-STATUS
           END-SEARCH
```

The `AT END` text must match whatever the current `WHEN OTHER` produces, byte for byte,
or the golden comparison fails.

### 6.6 Report output blocking — **SAFE**

`BLKSIZE=0` in the JCL already asks the system to pick a near-half-track block size, so
the datasets are well blocked. No change needed; recorded so it is not "fixed".

---

## 7. `MSTPB001` / `MSTPB002` — master lookups

### 7.1 Cache the customer and security lookups — **MEASURE**

`MSTPB001:65` is a singleton `SELECT` on `TBTRDCUS` by primary key, called twice per order
(buyer and seller); `MSTPB002` likewise for `TBTRDSEC` by FIGI. Both tables are small and
stable for the duration of a batch run, and the same customers and instruments recur
across thousands of orders.

If 1.2 (folding the lookups into the driving cursor) is adopted, this item disappears —
do that instead. If 1.2 is judged too invasive, a one-entry MRU cache in the caller costs
nothing and kills the repeated-customer case:

```cobol
      * WORKING-STORAGE in MSTPB001 - survives across CALLs
       01  WS-CACHE.
           05  WS-CACHE-ID           PIC X(10) VALUE SPACES.
           05  WS-CACHE-CURRENCY     PIC X(3).
           05  WS-CACHE-DESCRIPTION  PIC X(50).
           05  WS-CACHE-STATUS       PIC X(1).
      ...
       1000-GET-CUSTOMER.
           IF LS-CUSTOMER-ID = WS-CACHE-ID
              MOVE WS-CACHE-CURRENCY    TO LS-CUSTOMER-CURRENCY
              MOVE WS-CACHE-DESCRIPTION TO LS-CUSTOMER-DESCRIPTION
              IF WS-CACHE-STATUS = 'A'
                 SET 88-CUSTOMER-ACTIVE TO TRUE
              ELSE
                 SET 88-CUSTOMER-INACTIVE TO TRUE
                 MOVE 'Customer is Inactive' TO LS-CUSTOMER-ERROR-MSG
              END-IF
              GO TO 1000-EXIT
           END-IF
      *    ... existing SELECT, then populate the cache on SQLCODE 0 ...
```

Two hard constraints. The program must **not** be compiled `RECURSIVE` or with
`INITIAL`, or working-storage is reinitialised on every `CALL` and the cache never hits.
And caching is only correct because nothing in the batch window updates `TBTRDCUS` or
`TBTRDSEC` — if a concurrent job can change customer status mid-run, a stale cache
changes which orders are rejected. State that assumption explicitly before adopting.

Do not cache the negative (not-found) case unless the same assumption is confirmed for
inserts.

### 7.2 `MSTPB001`'s lookup has no isolation clause — **BEHAVIOUR**

`TRDPB000`'s own singleton lookups are written `WITH UR` (e.g. `TRDPB000:534`), but the
`SELECT` in `MSTPB001` is not. Inconsistent, and the master-data reads are the ones most
safely read uncommitted. Aligning them is a one-line change:

```sql
          FROM TBTRDCUS
          WHERE CUS_CUSTOMER_ID = :CUS-CUSTOMER-ID
          WITH UR
```

Classified BEHAVIOUR because it is a consistency change, however small: an in-flight
customer status update becomes visible.

---

## 8. `TRDPBEXC` — exception handler

### 8.1 The `-803` retry loop can never terminate — **DEFECT**

`TRDPBEXC:57-71`:

```cobol
        WHEN -803
* Retry Insert if it failed with SQLCODE -803 (Duplicate)
            PERFORM UNTIL SQLCODE = 0
*              EXEC SQL
*                  SET :EXC-TIMESTAMP  = CURRENT_TIMESTAMP
*              END-EXEC
               EXEC SQL
                  INSERT INTO TBTRDEXC
                        ( EXC_TYPE, EXC_DESCRIPTION)
                  VALUES(:EXC-TYPE, :EXC-DESCRIPTION)
               END-EXEC
            END-PERFORM
```

The statement that was supposed to make the retry succeed — re-stamping the timestamp so
the key differs — is commented out, together with the `EXC_TIMESTAMP` column itself
(`TRDPBEXC:42`). The loop therefore re-issues a byte-identical `INSERT` forever. An
exception handler that hangs the job is worse than one that fails it.

Reachability, precisely: `TBTRDEXC` currently has exactly one unique index,
`X1TRDEXC (EXC_ID)` on a `GENERATED ALWAYS AS IDENTITY` column, so `-803` cannot occur
today and the loop is unreachable. It becomes an infinite loop the moment anyone adds a
unique constraint on `(EXC_TYPE, EXC_DESCRIPTION)` — which is exactly what a DBA
de-duplicating this table would do. Delete the dead branch rather than leave the trap:

```cobol
        WHEN OTHER
           MOVE SQLCODE TO WS-SQLCODE
           DISPLAY 'Error Logging Exception.. Sqlcode = ' WS-SQLCODE
           PERFORM 9999-ABEND-DUMP THRU 9999-EXIT
```

i.e. drop `WHEN -803` entirely and let it fall into `WHEN OTHER`. If duplicate suppression
is actually wanted, it belongs in the DDL plus an explicit tolerate:

```cobol
        WHEN -803
           CONTINUE
```

### 8.2 One `INSERT` + `COMMIT` per exception — **MEASURE**

Each non-data exception writes one row and commits. Data exceptions (`EXCEPTION-DATA`)
write a row and do *not* commit — they ride on the caller's next commit, which is correct.
On a bad input file where most orders raise a data exception, `TBTRDEXC` receives one
insert per order. That is acceptable for a genuine error path; it is only worth batching
if data exceptions are routine in production, which the `TBTRDEXC` row counts from a real
run would show. Get that count before optimizing.

---

## 9. JCL, PROC and control cards

### 9.1 `IKJEFT01` can mask an abend — use `IKJEFT1B` — **BEHAVIOUR**

`proc/TRDPROC.proc` runs the DSN command processor under `PGM=IKJEFT01`. With `IKJEFT01`
the step return code is the TMP's, so a failing `RUN PROGRAM(...)` can leave the step
ending normally; `IKJEFT1B` propagates the abend/return code of the invoked program to the
step. This is the documented difference between the two entry points and is why `IKJEFT1B`
is the usual choice for DB2 batch.

Before — `proc/TRDPROC.proc`:

```jcl
//STEP01   EXEC PGM=IKJEFT01,DYNAMNBR=20
```

After:

```jcl
//STEP01   EXEC PGM=IKJEFT1B,DYNAMNBR=20,REGION=0M
```

This matters here more than usual because of 9.2. Classified BEHAVIOUR: jobs that
currently end RC 0 on failure will start ending non-zero, and the scheduler's dependency
rules will start firing. That is the point, but it must be a scheduled change, not a
quiet one. Confirm the exact semantics with the systems programmer against the installed
z/OS level before changing it.

### 9.2 Nothing sets a return code, so `COND=(8,LT)` is inoperative — **DEFECT**

`RETURN-CODE` appears in exactly two programs in the whole repository:

```text
cobol/TRDPB004:255   MOVE 0  TO RETURN-CODE
cobol/TRDPB004:817   MOVE 16 TO RETURN-CODE
cobol/TRDPB006:458   MOVE 16 TO RETURN-CODE
```

`TRDPB000`, `TRDPB001`, `TRDPB002`, `TRDPB003`, `MSTPB001`, `MSTPB002` and `TRDPBEXC`
never set one. Their only failure signal is the `CALL 'ILBOABN0'` user abend 255 raised
by `TRDPBEXC:101`, and that fires *only* for non-data exceptions. Every data exception —
"Customer Not Found", "Seller Side Order Status Invalid", "No BUY_SIDE_ORDERS to Settle"
— is logged and tolerated, and the job ends RC 0.

So `COND=(8,LT)`, coded on all 22 jobs, can only ever be triggered by an abend, which
under `IKJEFT01` (9.1) may not reach the step either. A settlement run that rejected every
single trade looks identical to a clean run from the scheduler's point of view.

The fix is in COBOL, not JCL — set a warning return code on the tolerated paths:

```cobol
      * in 9000-REPORT-EXCEPTION, before the CALL to TRDPBEXC
           IF DATA-EXCEPTION AND RETURN-CODE < 4
              MOVE 4 TO RETURN-CODE
           END-IF
```

and then make the JCL act on it, replacing the deprecated job-level `COND` with modern
conditional execution:

```jcl
//SETLUSD  EXEC TRDPROC,RUNPARM='SETLUSD'
//*
//         IF (SETLUSD.STEP01.RC >= 4) THEN
//FAILNOTE EXEC PGM=IDCAMS
//SYSPRINT DD SYSOUT=*
//SYSIN    DD *
  SET MAXCC = 4
/*
//         ENDIF
```

Both details matter: the test must be `>= 4` (or `> 0`) or the RC 4 the COBOL now sets
never fires it, and the step inside the `IF` must itself end non-zero — `IEFBR14` returns
0, so the job would still end RC 0 and the scheduler would still see success. `IDCAMS`
with `SET MAXCC` is the usual way to force a chosen code; substitute whatever the shop's
notification/alerting step is.

Classified DEFECT because today the batch cannot signal partial failure at all.

### 9.3 Unqualified DD overrides attach to the wrong step if the PROC changes — **SAFE**

`jcl/TRADERPT.jcl:15-21` and all of `jcl/EXECRPT.jcl`'s run step add DD statements after
`EXEC TRDPROC` without a procstep qualifier. Unqualified DDs are applied to the *first*
step of the procedure, which happens to be `STEP01` today. Add a step to `TRDPROC` ahead
of `STEP01` — a `DELETE` via IDCAMS, say — and every one of those overrides silently
moves to the new step, and the report DD vanishes from the program that writes it.

Before:

```jcl
//TRADERPT EXEC TRDPROC,RUNPARM='TRADERPT'
//REPORDER DD DISP=(MOD,CATLG,DELETE),
//         DSN=CLOUDFRM.TRADING.BATCHDB2.REPORDER.REPORT.MF,
...
//SYSTSIN  DD DISP=SHR,DSN=CLOUDFRM.TRADING.BATCHDB2.CARD(TRADERPT)
```

After:

```jcl
//TRADERPT EXEC TRDPROC,RUNPARM='TRADERPT'
//STEP01.REPORDER DD DISP=(MOD,CATLG,DELETE),
//         DSN=CLOUDFRM.TRADING.BATCHDB2.REPORDER.REPORT.MF,
...
```

Note the `SYSTSIN` override can go entirely: `TRDPROC` already codes
`//SYSTSIN DD DISP=SHR,DSN=...CARD(&RUNPARM)`, and `RUNPARM='TRADERPT'` resolves to
exactly the same dataset. The same redundant override appears in all 22 jobs.

### 9.4 Twenty near-identical members for ten currencies — **SAFE**

`jcl/ACCPUSD.jcl` and `jcl/SETLUSD.jcl` differ from their nine siblings only in the job
name and the four-character currency. Likewise the 20 control cards differ only in the
program name and the `PARM` currency.

`jcl/ACCPUSD.jcl` in full today:

```jcl
//ACCPUSD  JOB (QA),'QA',CLASS=D,MSGCLASS=X,
//         COND=(8,LT)
//PROCLIB  JCLLIB ORDER=CLOUDFRM.TRADING.BATCHDB2.RUN.PROC
//ACCPUSD  EXEC TRDPROC,RUNPARM='ACCPUSD'
//SYSTSIN  DD DISP=SHR,DSN=CLOUDFRM.TRADING.BATCHDB2.CARD(ACCPUSD)
```

The JCL side collapses to one member plus a `SET`, with the scheduler supplying the
currency:

```jcl
//ACCP&CCY JOB (QA),'QA',CLASS=D,MSGCLASS=X
//         SET CCY=USD                <== scheduler overrides this line
//PROCLIB  JCLLIB ORDER=CLOUDFRM.TRADING.BATCHDB2.RUN.PROC
//ACCEPT   EXEC TRDPROC,RUNPARM=ACCP&CCY
```

The control cards collapse the same way once the currency reaches the program as a PARM
rather than being baked into a member — but note the card is read from
`...CARD(&RUNPARM)` by the PROC, so eliminating the 20 card members requires passing the
PARM through `SYSTSIN` instead, e.g. an in-stream card:

```jcl
//STEP01.SYSTSIN DD *
  DSN SYSTEM (DBCG)
  RUN PROGRAM(TRDPB000) -
  PLAN   (CLFRPLAN) -
  PARM('&CCY 0100')
  END
/*
```

Symbol substitution does happen in in-stream data when `SYMBOLS=` is coded on the `DD *`
— check the installation default before relying on it, and if it is not enabled, keep the
card members and collapse only the JCL. This is maintainability, not performance: today a
change to the acceptance runbook is 20 edits.

### 9.5 `EXECRPT` duplicates 24 lines of DD definitions and carries a dead step — **SAFE**

`jcl/EXECRPT.jcl` codes the three report DDs twice, once with `DISP=(MOD,DELETE,DELETE)`
in the `DELETE` step and once with `DISP=(MOD,CATLG,DELETE)` in the run step, identical in
every other attribute. It also begins with:

```jcl
//STOP    EXEC PGM=IEFBR14
```

which does nothing — presumably a leftover "stop here" marker. Delete it.

For the duplication, use symbols and an `INCLUDE` member:

```jcl
//*  member CLOUDFRM.TRADING.BATCHDB2.RUN.PROC(RPTDDS)
//RUNLOG   DD DISP=(&DISPO),
//         DSN=CLOUDFRM.TRADING.BATCHDB2.RUNLOG.REPORT.MF,
//         UNIT=SYSDA,VOL=SER=CLFR03,
//         DCB=(LRECL=90,BLKSIZE=0,RECFM=FB,DSORG=PS),
//         SPACE=(TRK,(1,1),RLSE)
//SUMMARY  DD DISP=(&DISPO),
...
```

```jcl
//DELETE   EXEC PGM=IEFBR14
//         SET DISPO='MOD,DELETE,DELETE'
//         INCLUDE MEMBER=RPTDDS
//*
//EXECRPT  EXEC TRDPROC,RUNPARM='EXECRPT'
//         SET DISPO='MOD,CATLG,DELETE'
//STEP01.  INCLUDE MEMBER=RPTDDS
```

### 9.6 `SPACE=(CYL,(100,100),RLSE)` for a 1.9 MB report — **SAFE**

`jcl/TRADERPT.jcl` allocates 100 cylinders primary and 100 secondary for `REPORDER`. The
golden report is 11,816 records × 161 bytes ≈ 1.9 MB ≈ 3 cylinders of 3390. `RLSE` gives
the unused primary back at close, but the primary extent must still be *found* at
allocation time, so a 100-cylinder request can fail on a fragmented volume for a dataset
that needs three.

Before:

```jcl
//         SPACE=(CYL,(100,100),RLSE)
```

After — sized with headroom for 10× growth, secondary allowed to do the work:

```jcl
//         SPACE=(CYL,(30,30),RLSE)
```

`EXCPTION`/`SUMMARY` in `EXECRPT` at `(CYL,(10,10))` are likewise generous for report
volumes in the tens of rows, though far less extreme.

### 9.7 Hard-coded `UNIT=SYSDA,VOL=SER=CLFR03` — **BEHAVIOUR**

Every report DD in every job names one volume. That pins all output to one pack, prevents
multi-volume extension, and makes the whole reporting batch fail if `CLFR03` is
unavailable or full. Under SMS, drop both and let the ACS routines place the dataset:

```jcl
//REPORDER DD DISP=(MOD,CATLG,DELETE),
//         DSN=CLOUDFRM.TRADING.BATCHDB2.REPORDER.REPORT.MF,
//         STORCLAS=SCSTD,
//         DCB=(LRECL=161,BLKSIZE=0,RECFM=FBA,DSORG=PS),
//         SPACE=(CYL,(30,30),RLSE)
```

Needs the storage administrator to confirm the storage class name and that the dataset
pattern is SMS-managed; classified BEHAVIOUR because placement and therefore any
volume-based recovery procedure changes.

### 9.8 Reports are overwritten every run — use a GDG — **BEHAVIOUR**

The `IEFBR14` + `DISP=(MOD,DELETE,DELETE)` prologue exists purely to make the next run's
`MOD` allocation start empty. The consequence is that yesterday's report is gone, so a
disputed number cannot be checked against what was actually produced. A generation data
group removes the delete step *and* gives free retention:

```text
DEFINE GDG (NAME(CLOUDFRM.TRADING.BATCHDB2.REPORDER.REPORT) -
            LIMIT(30) SCRATCH NOEMPTY)
```

```jcl
//TRADERPT EXEC TRDPROC,RUNPARM='TRADERPT'
//STEP01.REPORDER DD DISP=(NEW,CATLG,DELETE),
//         DSN=CLOUDFRM.TRADING.BATCHDB2.REPORDER.REPORT(+1),
//         STORCLAS=SCSTD,
//         DCB=(LRECL=161,BLKSIZE=0,RECFM=FBA,DSORG=PS),
//         SPACE=(CYL,(30,30),RLSE)
```

The whole `//DELETE EXEC PGM=IEFBR14` step then disappears. Downstream consumers that
reference the flat DSN must move to `(0)`, which is why this is BEHAVIOUR — find them
first.

Worth noting for the migration: this also gives the equivalence harness a retention
window of real mainframe outputs to diff against, which is the single biggest gap in
`03-equivalence-harness.md`.

### 9.9 The ten currencies can run concurrently — confirm they do — **MEASURE**

`TBTRDORD`, `TBTRDSTQ` and the position/account tables are partitioned by currency, and
each `ACCP*`/`SETL*` job filters on exactly one currency, so no two currency jobs touch
the same partition. Nothing in the JCL expresses this — the dependency graph lives in the
scheduler, which is not in the repository.

One table breaks the partitioning and must be resolved first: `TBTRDSUM` is keyed by
`SUM_CUSTOMER_ID` alone (`X1TRDSUM` is unique on that single column), and `SUMMARY.cpy`
— included by both `TRDPB000` and `TRDPB001` — reads the row, accumulates in
working storage and writes it back:

```cobol
              UPDATE TBTRDSUM
                 SET ...
               WHERE SUM_CUSTOMER_ID = :SUM-CUSTOMER-ID
```

A customer trading in USD and EUR therefore has one shared summary row. Run the two
currencies concurrently and the read-modify-write windows interleave: one job's totals
overwrite the other's, silently, with no `SQLCODE` to notice. Three ways out, in order of
preference: make the accumulation atomic in SQL
(`SET SUM_TRADE_COUNT = SUM_TRADE_COUNT + 1, SUM_AMOUNT = SUM_AMOUNT + :DELTA`), which
also fixes item 3.1's pattern; or add `SUM_CURRENCY` to the key and aggregate at read
time in `TRDPB004`; or serialise only the summary update. Until one of them is done, the
ten currencies are *not* safely concurrent, whatever the partitioning says.

If the ten pairs run serially today, the batch window is ~10× longer than it needs to be,
and this is the largest single elapsed-time item in the whole review. What the JCL *does*
need before concurrency is safe is 9.2, because ten jobs that cannot signal failure are
ten jobs nobody notices failing.

The ordering constraint that must be preserved: `ACCP{ccy}` before `SETL{ccy}` for the
same currency; `EXECRPT` and `TRADERPT` after all twenty. Ask the operations team for the
current Control-M/scheduler definition and confirm.

### 9.10 `TRDPROC` has no `REGION` — **SAFE**

```jcl
//STEP01   EXEC PGM=IKJEFT1B,DYNAMNBR=20,REGION=0M
```

DB2 batch with rowset fetch (1.1) allocates larger host-variable areas and a bigger
thread storage footprint. Relying on the installation default region is how a working job
starts S878-ing after an unrelated tuning change. Also consider `MEMLIMIT` if 64-bit
storage is used by the DB2 attach at your level.

---

## 10. Suggested order of work

The sequence matters: some items are prerequisites for others, and the cheap
defect fixes should not wait behind the tuning work.

1. **9.2** (return codes) and **8.1** (`-803` loop) — defects, small, no performance risk.
2. **4.2** (duplicated fetch), **6.1**/**6.2** (cursor clauses, explicit joins), **9.3**, **9.5**, **9.6**, **9.10** — SAFE cleanups that make everything after them easier to verify.
3. **2.1**/**2.2** (bind options) — biggest ratio of effect to source change, but needs the DBA.
4. **1.1** (rowset fetch) on `TRDPB006` first, because it is read-only and has a byte-exact golden to prove it.
5. **3.1** (atomic booking update) — biggest call-count reduction on the settlement path.
6. **9.9** (currency parallelism) — biggest elapsed-time reduction, gated on 9.2.
7. **1.2** (fold lookups into the cursor) and **5.2** (`-911` handling) — design-level, best done as part of the Java port rather than twice.
8. **6.3**/**4.1** (new indexes) — last, after `EXPLAIN` on the changed SQL, because the earlier items change what the access paths need to be.

## 11. What not to change

Every item below is observable in `output/CLOUDFRM.TRADING.BATCHDB2.REPORDER.REPORT.MF`
and is reproduced deliberately by the Spring Batch port. Changing any of them breaks the
only machine-checkable proof that the port is correct.

- The report layout, column positions, `JUST RIGHT` fields and carriage control.
- `WS-ORDER-COUNT > WS-MAX-ORDERS-PER-PAGE` at `TRDPB006:419`, which yields 61 detail rows
  per page rather than 60. Almost certainly not intended; it is the behaviour.
- The header/blank-line sequence and `AFTER ADVANCING PAGE`.
- The `ORDER BY` column list on `CLIENT_ORDERS` (the *index* under it may change, 6.3 —
  the clause may not).
- The exact exception message text written to `TBTRDEXC`, including trailing spaces from
  `STRING ... DELIMITED BY SIZE`.
- The status-code descriptions (6.5 moves them, must not reword them).

Two latent defects in `TRDPB006` that are **not** optimizations and are carried here for
completeness — both are analysed in the `TRDPB006` review and neither is caught by the
current golden, because the fixture never exercises them:

- `WS-DET-QUANTITY` / `WS-DET-AMOUNT` at `TRDPB006:150,154` are `PIC -,---,---.00` —
  floating sign, so 6 integer digits, maximum `999,999.99`. The columns are
  `DECIMAL(9,2)`, maximum `9,999,999.99`. A trade of a million or more loses its
  high-order digit, silently, because a COBOL `MOVE` truncates without `SIZE ERROR`. Fix:
  `PIC --,---,---.00`, which changes the report width and therefore needs a new fixture.
- `WS-PAGENUM PIC 9(3)` at `TRDPB006:31` wraps past page 999 and never resets per
  customer. The golden run produced 202 pages.
