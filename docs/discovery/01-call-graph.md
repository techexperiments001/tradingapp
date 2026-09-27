# Call graph and business logic

```
ACCP<CCY>  ──▶ TRDPB000 (acceptance/matching)
                 ├─▶ MSTPB001  customer master lookup      (TBTRDCUS)
                 ├─▶ MSTPB002  security master lookup      (TBTRDSEC)
                 └─▶ TRDPBEXC  exception logger            (TBTRDEXC)

SETL<CCY>  ──▶ TRDPB001 (settlement driver)
                 ├─▶ TRDPB002  securities book-keeping     (TBTRDPOS)
                 │     └─▶ TRDPBEXC
                 ├─▶ TRDPB003  money book-keeping          (TBTRDMAC)
                 │     └─▶ TRDPBEXC
                 └─▶ TRDPBEXC

EXECRPT    ──▶ TRDPB004  exception + run-log + summary reports
TRADERPT   ──▶ TRDPB006  customer-wise trade report

(orphan)       TRDPB007  MQPUT to TRADING.QUEUE — no job references it
```

All inter-program calls are dynamic `CALL <identifier>` against an 8-byte
working-storage field, so the target name is a data value, not a literal:
`TRDPB000` holds `MSTPB001`/`MSTPB002`, `TRDPB001` holds `TRDPB002`/`TRDPB003`,
and every program holds `'TRDPBEXC'` in `WS-EXCEPTION-HANDLER` (copybook
`EXCPTION`). A static call-graph tool that only looks for `CALL 'LITERAL'` will
miss the entire graph.

## Order status lifecycle

`TBTRDORD.ORD_STATUS` is the state machine the whole application turns on:

| Code | Condition | Set by |
|---|---|---|
| `101` | Accepted, awaiting match | loaded input state |
| `201` | Matched, queued for settlement | `TRDPB000` |
| `301` | Overdue — buyer id invalid | `TRDPB000` |
| `302` | Overdue — seller id invalid | `TRDPB000` |
| `303` | Overdue — security invalid | `TRDPB000` |
| `304` | Overdue — buyer account invalid | `TRDPB000` |
| `305` | Overdue — seller account invalid | `TRDPB000` |
| `306` | Overdue — buyer order status invalid | `TRDPB000` |
| `307` | Overdue — seller order status invalid | `TRDPB000` |
| `308` | Overdue — no matching sell order | `TRDPB000` |
| `401` | Rejected (settlement failed) | `TRDPB001` |
| `601` | Settled | `TRDPB001` |

## TRDPB000 — acceptance / matching

1. Validate `LK-CURRENCY` against the 10 allowed values; default
   `LK-CHKP-FREQUENCY` to 100 when below 100.
2. Insert an `ACCEPTANCE` row into `TBTRDLOG` with a start timestamp built from
   `ACCEPT FROM DATE/TIME` (the DB2 `CURRENT_TIMESTAMP` version is commented out).
3. Derive the exchange from the currency:
   EUR→DAX, USD→NYSE, CAD→TSX, CNY→SSE, INR→BSE, CHF→SWX, JPY→TSE, MXN→BMV,
   KRW→KRX, GBX→FTSE.
4. Open cursor `BUY_SIDE_ORDERS` — `TBTRDORD` rows for this currency/exchange
   with `ORD_BUY_SELL_IND = 'B'` and `ORD_STATUS = '101'` — and for each buy
   order:
   - `5000-GET-SELL-SIDE-ORDER`: find the matching `'S'` row (same trade id,
     FIGI, exchange, currency); missing ⇒ status `308`.
   - `5001-VALIDATE-CUSTOMERS`: `CALL MSTPB001` for buyer and seller; not found
     or not active ⇒ `301`/`302`.
   - `5002-VALIDATE-SECURITY`: `CALL MSTPB002`; invalid ⇒ `303`.
   - `5003`/`5004`: buyer and seller securities accounts from `TBTRDSAC` ⇒
     `304`/`305`.
   - `5005`/`5006`: buyer and seller money accounts from `TBTRDMAC`.
   - On success: `5007-UPDATE-ORDER-MATCHED` sets both legs to `201` and
     `5008/5009` insert an 88-byte `TRD-ORDER-PAIR` record into `TBTRDSTQ`
     (the settlement queue).
   - Any failure path calls `TRDPBEXC` through the `EXCPCOPY`
     `9000-REPORT-EXCEPTION` paragraph and marks the order overdue.
5. `COMMIT` every `LK-CHKP-FREQUENCY` orders; write the `TBTRDLOG` end
   timestamp (`-803` ⇒ update instead of insert).

## TRDPB001 — settlement

1. Log a `SETTLEMENT` start row, open cursor `SETTLEMENT_QUEUE` over
   `TBTRDSTQ` for the currency, ordered by `STQ_ID`.
2. Per queued trade (`TRD-ORDER-PAIR` redefined over `STQ_TRADE_DATA`):
   - `CALL TRDPB002` — securities leg: debit seller / credit buyer position in
     `TBTRDPOS`. Sets `TRD-SAC-BOOKING-DONE` or `…-FAILED`.
   - If the securities leg succeeded, `CALL TRDPB003` — money leg: debit buyer /
     credit seller balance in `TBTRDMAC`.
   - Both legs done ⇒ `601` settled, otherwise ⇒ `401` rejected; both the buy
     and the sell leg of `TBTRDORD` are updated.
   - `SUMMCOPY`/`SUMMARY` maintain the per-customer `TBTRDSUM` row
     (counts of overdue/rejected/settled and opening/debit/credit/closing
     balances).
3. `COMMIT` every `LK-CHKP-FREQUENCY` trades; write the run-log end timestamp.

The securities leg is committed together with the money leg only at the next
checkpoint, so a failure between the two legs leaves the trade rejected but the
securities position already moved *within the uncommitted unit of work* — the
unit of work, not each booking, is the atomicity boundary. Any target design has
to keep the same transaction boundaries or balances will diverge.

## TRDPB004 / TRDPB006 — reports

Report programs are pure readers writing ANSI-carriage-control print files:

- `TRDPB004` (`EXCPTION`, `RUNLOG`, `SUMMARY` reports): cursors
  `EXCPTION_CURSOR` (`TBTRDEXC` ordered by type+description),
  `RUNLOG_CURSOR` (`TBTRDLOG`), `SUMMARY_CURSOR` (`TBTRDSUM`).
- `TRDPB006` (`REPORDER` report): cursor `CLIENT_ORDERS`, a four-way join of
  `TBTRDORD` (self-join buy leg ↔ sell leg) with `TBTRDCUS` and `TBTRDSEC`,
  ordered by customer, buy/sell indicator, currency, status, trade id, with
  page/section breaks on those keys.

## TRDPBEXC — exception handler

Called with `(EXCEPTION-RECORD-LEN, EXCEPTION-RECORD)`. Data exceptions are
tolerated; non-data exceptions `ROLLBACK` first. The exception row is inserted
into `TBTRDEXC`, `-803` duplicates are retried, and a fatal path calls
`ILBOABN0` with abend code 255 — i.e. the process abends rather than returning
a return code, which is what the `COND=(8,LT)` on every job reacts to.
