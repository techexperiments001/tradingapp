# Data dictionary

DB2 column types come from `db2/mainframe-db2-setup/ddl/`, COBOL host-variable
types from the DCLGENs recovered into `copybook/`. The "target" column is the
type to use in a Java/Kotlin or Python port; using anything other than an exact
decimal type for the money and quantity columns will change results.

## Type mapping rules

| DB2 | COBOL (DCLGEN) | Java | Python | Note |
|---|---|---|---|---|
| `CHAR(n)` | `PIC X(n)` | `String` | `str` | **space padded to n**; comparisons and report columns depend on the padding |
| `INTEGER` | `PIC S9(9) USAGE COMP` | `int` | `int` | big-endian binary on the wire |
| `DECIMAL(9,2)` | `PIC S9(7)V9(2) COMP-3` | `BigDecimal` | `Decimal` | packed decimal, 2 dp |
| `DECIMAL(12,2)` | `PIC S9(10)V9(2) COMP-3` | `BigDecimal` | `Decimal` | packed decimal, 2 dp |
| `VARCHAR(1000)` | `49 …-LEN PIC S9(4) COMP` + `49 …-TEXT PIC X(1000)` | `String` | `str` | length-prefixed pair |
| identity column | not in DCLGEN insert list | generated | generated | `TBTRDEXC.EXC_ID`, `TBTRDSTQ.STQ_ID` |

## Tables

### `TBTRDORD` — orders (partitioned by currency, 10 partitions)
| Column | Type | Meaning |
|---|---|---|
| `ORD_TRADING_XCHNG` | `CHAR(10)` | exchange derived from currency |
| `ORD_TRADEID` | `CHAR(12)` | trade id, shared by the buy and sell leg |
| `ORD_BUY_SELL_IND` | `CHAR(1)` | `B` / `S` |
| `ORD_CUSTOMER_ID` | `CHAR(12)` | owner of this leg |
| `ORD_FIGI` | `CHAR(12)` | security identifier |
| `ORD_QUANTITY` | `DECIMAL(9,2)` | |
| `ORD_CURRENCY` | `CHAR(3)` | partitioning key |
| `ORD_AMOUNT` | `DECIMAL(9,2)` | |
| `ORD_STATUS` | `CHAR(3)` | state machine, see `01-call-graph.md` |

Unique index `X1TRDORD` on (currency, exchange, trade id, FIGI, buy/sell) —
the buy and sell legs of a trade are two rows differing only in the indicator.

### `TBTRDCUS` — customers
`CUS_CUSTOMER_ID CHAR(12)`, `CUS_CURRENCY CHAR(3)`, `CUS_DESCRIPTION CHAR(40)`,
`CUS_STATUS CHAR(1)` (`A` active / `I` inactive; anything else is "not found"
to `MSTPB001`).

### `TBTRDSEC` — securities master (171,289 rows)
`SEC_FIGI CHAR(12)`, `SEC_CURRENCY CHAR(3)`, `SEC_DESCRIPTION CHAR(40)`,
`SEC_SYMBOL CHAR(20)`, `SEC_SHARE_CLASS_FIGI CHAR(12)`, `SEC_TYPE CHAR(20)`.

### `TBTRDSAC` — securities accounts
`SAC_CURRENCY CHAR(3)`, `SAC_NUMBER INTEGER`, `SAC_CUSTOMER_ID CHAR(12)`,
`SAC_STATUS CHAR(1)`.

### `TBTRDPOS` — securities positions
`POS_CURRENCY CHAR(3)`, `POS_SAC_NUMBER INTEGER`, `POS_FIGI CHAR(12)`,
`POS_BALANCE DECIMAL(12,2)`. Updated by `TRDPB002`.

### `TBTRDMAC` — money accounts
`MAC_CURRENCY CHAR(3)`, `MAC_NUMBER INTEGER`, `MAC_CUSTOMER_ID CHAR(12)`,
`MAC_BALANCE DECIMAL(12,2)`, `MAC_STATUS CHAR(1)`. Updated by `TRDPB003`.

### `TBTRDSTQ` — settlement queue
`STQ_CURRENCY CHAR(3)`, `STQ_ID INT IDENTITY`, `STQ_TRADE_DATA CHAR(88)`.

`STQ_TRADE_DATA` is **not text**: it is the `TRDORDER` copybook record
(`TRD-ORDER-PAIR`) moved into an 88-byte character column, so it contains
`COMP-3` and `COMP` binary fields inside a `CHAR` column:

| Field | PIC | Bytes |
|---|---|---|
| `TRD-EXCHANGE` | `X(10)` | 10 |
| `TRD-BUYER-ID` | `X(12)` | 12 |
| `TRD-SELLER-ID` | `X(12)` | 12 |
| `TRD-ORDER-ID` | `X(12)` | 12 |
| `TRD-FIGI` | `X(12)` | 12 |
| `TRD-ORDER-QTY` | `S9(7)V9(2) COMP-3` | 5 |
| `TRD-CURRENCY` | `X(03)` | 3 |
| `TRD-ORDER-AMOUNT` | `S9(7)V9(2) COMP-3` | 5 |
| `TRD-BUYER-SEC-ACC-NUM` | `S9(9) COMP` | 4 |
| `TRD-BUYER-MONEY-ACC-NUM` | `S9(9) COMP` | 4 |
| `TRD-SELLER-SEC-ACC-NUM` | `S9(9) COMP` | 4 |
| `TRD-SELLER-MONEY-ACC-NUM` | `S9(9) COMP` | 4 |
| `TRD-STATUS` | `X` | 1 |
| | **total** | **88** |

This is the highest-risk field in the application for a migration: it is an
EBCDIC-encoded binary blob in a character column, so a naive
EBCDIC→UTF-8 conversion of the table corrupts it. Either keep it as `BYTEA`/
`byte[]` or normalise it into real columns as part of the port.

### `TBTRDSUM` — per-customer summary
`SUM_CUSTOMER_ID CHAR(12)`, `SUM_OVERDUE/SUM_REJECTED/SUM_SETTLED INTEGER`,
`SUM_CURRENCY CHAR(3)`, `SUM_OPEN_BALANCE`, `SUM_TOTAL_DEBIT`,
`SUM_TOTAL_CREDIT`, `SUM_CLOSE_BALANCE` all `DECIMAL(12,2)`.

### `TBTRDLOG` — run log
`LOG_TRANSACTION CHAR(10)` (`ACCEPTANCE`/`SETTLEMENT`), `LOG_CURRENCY CHAR(3)`,
`LOG_START_TS CHAR(26)`, `LOG_END_TS CHAR(26)` — timestamps stored as
**character**, formatted in COBOL from `ACCEPT FROM DATE/TIME`, not as DB2
`TIMESTAMP`.

### `TBTRDEXC` — exceptions
`EXC_ID INT IDENTITY`, `EXC_TYPE CHAR(20)` (`SYSTEM`/`APPLICATION`/`DATA`),
`EXC_DESCRIPTION VARCHAR(1000)`.

## Report record layouts

| Report | DD | LRECL | RECFM |
|---|---|---|---|
| Trade orders (`TRDPB006`) | `REPORDER` | 161 (record 160 + CC) | `FBA`, allocated in `TRADERPT.jcl` |
| Exceptions (`TRDPB004`) | `EXCPTION-REPORT` | record 1100 | `FBA` |
| Run log (`TRDPB004`) | `RUNLOG-REPORT` | record 90 | `FBA` |
| Customer summary (`TRDPB004`) | `SUMMARY-REPORT` | record 140 | `FBA` |

Column 1 of every report record is the carriage-control character
(`1` = new page, `0` = double space, ` ` = single space). It is part of the
byte-exact comparison against `output/*.MF`.
