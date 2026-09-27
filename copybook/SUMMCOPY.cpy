       01  WS-SUMMARY-PROC-SWITCHES.
           05  WS-CUSTOMER-SUMMARY-WRITE-SW PIC X.
               88 88-CUSTOMER-SUMMARY-WRITE VALUE 'W'.
               88 88-CUSTOMER-SUMMARY-REWRITE VALUE 'R'.
           05  WS-SUMMARY-DEBIT-CREDIT-SW PIC X.
               88 88-SUMMARY-DEBIT        VALUE 'D'.
               88 88-SUMMARY-CREDIT       VALUE 'C'.
               88 88-SUMMARY-NO-BOOKING   VALUE 'N'.
       01  WS-CUSTOMER-SUMMARY-REC-LEN  PIC S9(4) COMP.
       01  WS-CUSTOMER-SUMMARY-REC.
           05 WS-SUMMARY-CUSTOMER-ID    PIC X(12).
           05 WS-SUMMARY-OVERDUE        PIC S9(9) COMP.
           05 WS-SUMMARY-REJECTED       PIC S9(9) COMP.
           05 WS-SUMMARY-SETTLED        PIC S9(9) COMP.
           05 WS-SUMMARY-CURRENCY       PIC X(03).
           05 WS-SUMMARY-OPEN-BALANCE   PIC S9(10)V99 COMP-3.
           05 WS-SUMMARY-TOTAL-DEBIT    PIC S9(10)V99 COMP-3.
           05 WS-SUMMARY-TOTAL-CREDIT   PIC S9(10)V99 COMP-3.
           05 WS-SUMMARY-CLOSE-BALANCE  PIC S9(10)V99 COMP-3.
      *
      *****EXEC SQL
      *****   DECLARE SUMMARY_CSR CURSOR FOR
      *****       SELECT
      *****          SUM_CUSTOMER_ID
      *****         ,SUM_OVERDUE
      *****         ,SUM_REJECTED
      *****         ,SUM_SETTLED
      *****         ,SUM_CURRENCY
      *****         ,SUM_OPEN_BALANCE
      *****         ,SUM_TOTAL_DEBIT
      *****         ,SUM_TOTAL_CREDIT
      *****         ,SUM_CLOSE_BALANCE
      *****       FROM TBTRDSUM
      *****       WHERE SUM_CUSTOMER_ID = :SUM-CUSTOMER-ID
      *****       FOR UPDATE OF
      *****          SUM_OVERDUE
      *****         ,SUM_REJECTED
      *****         ,SUM_SETTLED
      *****         ,SUM_CURRENCY
      *****         ,SUM_OPEN_BALANCE
      *****         ,SUM_TOTAL_DEBIT
      *****         ,SUM_TOTAL_CREDIT
      *****         ,SUM_CLOSE_BALANCE
      *****END-EXEC.
