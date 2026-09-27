       8001-LOG-SUMMARY.
      *
      * CHECK IF CUSTOMER SUMMARY ROW EXITS
      *
           MOVE WS-SUMMARY-CUSTOMER-ID TO SUM-CUSTOMER-ID
           EXEC SQL
                OPEN SUMMARY_CSR
           END-EXEC
           IF SQLCODE NOT = 0 THEN
              MOVE SQLCODE TO WS-SQLCODE
              SET APPL-EXCEPTION TO TRUE
              MOVE SPACES TO WS-EXCEPTION
              STRING
                 'Summary Cursor OPEN Failed : SQLCODE = '
                 WS-SQLCODE
                 DELIMITED BY SIZE
                INTO WS-EXCEPTION
              END-STRING
              PERFORM 9000-REPORT-EXCEPTION
                 THRU 9000-EXIT
           END-IF

           EXEC SQL
                FETCH SUMMARY_CSR
                 INTO :SUM-CUSTOMER-ID
                     ,:SUM-OVERDUE
                     ,:SUM-REJECTED
                     ,:SUM-SETTLED
                     ,:SUM-CURRENCY
                     ,:SUM-OPEN-BALANCE
                     ,:SUM-TOTAL-DEBIT
                     ,:SUM-TOTAL-CREDIT
                     ,:SUM-CLOSE-BALANCE
           END-EXEC
           IF SQLCODE = 0 OR 100 THEN
              CONTINUE
           ELSE
              MOVE SQLCODE TO WS-SQLCODE
              SET APPL-EXCEPTION TO TRUE
              MOVE SPACES TO WS-EXCEPTION
              STRING
                 'Summary Cursor OPEN Failed : SQLCODE = '
                 WS-SQLCODE
                 DELIMITED BY SIZE
                INTO WS-EXCEPTION
              END-STRING
              PERFORM 9000-REPORT-EXCEPTION
                 THRU 9000-EXIT
           END-IF
           IF SQLCODE = 100 THEN
              SET 88-CUSTOMER-SUMMARY-WRITE TO TRUE
              MOVE ZERO TO SUM-OVERDUE
                           SUM-REJECTED
                           SUM-SETTLED
                           SUM-CURRENCY
                           SUM-OPEN-BALANCE
                           SUM-TOTAL-DEBIT
                           SUM-TOTAL-CREDIT
                           SUM-CLOSE-BALANCE
           ELSE
              SET 88-CUSTOMER-SUMMARY-REWRITE TO TRUE
              MOVE DCLTBTRDSUM    TO WS-CUSTOMER-SUMMARY-REC
           END-IF
      *
           IF (88-SUMMARY-DEBIT OR 88-SUMMARY-CREDIT) AND
              SUM-OPEN-BALANCE = 0 THEN
              MOVE TRD-CURRENCY             TO MAC-CURRENCY
              IF TRD-BUYER-ID = SUM-CUSTOMER-ID
                 MOVE TRD-BUYER-MONEY-ACC-NUM  TO MAC-NUMBER
              ELSE
                 MOVE TRD-SELLER-MONEY-ACC-NUM TO MAC-NUMBER
              END-IF
              EXEC SQL
                 SELECT  MAC_BALANCE
                   INTO :MAC-BALANCE
                   FROM TBTRDMAC
                   WHERE
                        MAC_CURRENCY   = :MAC-CURRENCY
                    AND MAC_NUMBER     = :MAC-NUMBER
                    WITH UR
              END-EXEC
              IF SQLCODE = 0 THEN
                 IF TRD-BUYER-ID = SUM-CUSTOMER-ID
                    COMPUTE SUM-OPEN-BALANCE =
                        MAC-BALANCE + TRD-ORDER-AMOUNT
                 ELSE
                    COMPUTE SUM-OPEN-BALANCE =
                        MAC-BALANCE - TRD-ORDER-AMOUNT
                 END-IF
                 MOVE SUM-OPEN-BALANCE
                   TO SUM-CLOSE-BALANCE
              END-IF
           END-IF
           EVALUATE TRUE
              WHEN  OVERDUE
                    ADD 1 TO  SUM-OVERDUE
              WHEN  REJECTED
                    ADD 1 TO  SUM-REJECTED
              WHEN  SETTLED
                    ADD 1 TO  SUM-SETTLED
           END-EVALUATE
           EVALUATE TRUE
              WHEN  88-SUMMARY-DEBIT
                    MOVE TRD-CURRENCY    TO SUM-CURRENCY
                    ADD TRD-ORDER-AMOUNT TO SUM-TOTAL-DEBIT
                    SUBTRACT TRD-ORDER-AMOUNT FROM
                             SUM-CLOSE-BALANCE
              WHEN  88-SUMMARY-CREDIT
                    MOVE TRD-CURRENCY    TO SUM-CURRENCY
                    ADD TRD-ORDER-AMOUNT TO SUM-TOTAL-CREDIT
                    ADD      TRD-ORDER-AMOUNT TO
                             SUM-CLOSE-BALANCE
              WHEN  88-SUMMARY-NO-BOOKING
                    CONTINUE
           END-EVALUATE
           IF 88-CUSTOMER-SUMMARY-WRITE
      * INSERT   CUSTOMER SUMMARY
              MOVE WS-CUSTOMER-SUMMARY-REC TO DCLTBTRDSUM
              EXEC SQL
                 INSERT
                   INTO TBTRDSUM
                   VALUES (
                     :SUM-CUSTOMER-ID
                    ,:SUM-OVERDUE
                    ,:SUM-REJECTED
                    ,:SUM-SETTLED
                    ,:SUM-CURRENCY
                    ,:SUM-OPEN-BALANCE
                    ,:SUM-TOTAL-DEBIT
                    ,:SUM-TOTAL-CREDIT
                    ,:SUM-CLOSE-BALANCE
                   )
              END-EXEC
           ELSE
              EXEC SQL
                   UPDATE TBTRDSUM
                      SET
                         SUM_OVERDUE       = :SUM-OVERDUE
                        ,SUM_REJECTED      = :SUM-REJECTED
                        ,SUM_SETTLED       = :SUM-SETTLED
                        ,SUM_CURRENCY      = :SUM-CURRENCY
                        ,SUM_OPEN_BALANCE  = :SUM-OPEN-BALANCE
                        ,SUM_TOTAL_DEBIT   = :SUM-TOTAL-DEBIT
                        ,SUM_TOTAL_CREDIT  = :SUM-TOTAL-CREDIT
                        ,SUM_CLOSE_BALANCE = :SUM-CLOSE-BALANCE
                   WHERE
                      SUM_CUSTOMER_ID = :SUM-CUSTOMER-ID
              END-EXEC
           END-IF
      *            WHERE CURRENT OF SUMMARY_CSR
           IF SQLCODE = 0 THEN
              CONTINUE
           ELSE
              MOVE SQLCODE TO WS-SQLCODE
              SET APPL-EXCEPTION TO TRUE
              MOVE SPACES TO WS-EXCEPTION
              STRING
                 'Summary Insert/Update Failed : SQLCODE = '
                 WS-SQLCODE
                 DELIMITED BY SIZE
                INTO WS-EXCEPTION
              END-STRING
              PERFORM 9000-REPORT-EXCEPTION
                 THRU 9000-EXIT
           END-IF
      *
           EXEC SQL
                CLOSE SUMMARY_CSR
           END-EXEC
           IF SQLCODE NOT = 0 THEN
              MOVE SQLCODE TO WS-SQLCODE
              SET APPL-EXCEPTION TO TRUE
              MOVE SPACES TO WS-EXCEPTION
              STRING
                 'Summary Cursor CLOSE Failed : SQLCODE = '
                 WS-SQLCODE
                 DELIMITED BY SIZE
                INTO WS-EXCEPTION
              END-STRING
              PERFORM 9000-REPORT-EXCEPTION
                 THRU 9000-EXIT
           END-IF

           .
      *
       8001-EXIT.
      *
           EXIT.
      *
