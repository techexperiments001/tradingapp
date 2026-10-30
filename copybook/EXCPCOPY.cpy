       9000-REPORT-EXCEPTION.
      *
      *    EXEC SQL
      *        SET :EXCEPTION-TIMESTAMP = CURRENT_TIMESTAMP
      *    END-EXEC
           MOVE WS-EXCEPTION  TO EXCEPTION-DESC
           MOVE LENGTH OF WS-EXCEPTION
             TO EXCEPTION-RECORD-LEN
           EVALUATE TRUE
              WHEN SYSTEM-EXCEPTION
                   MOVE 'SYSTEM'             TO EXCEPTION-TYPE
              WHEN APPL-EXCEPTION
                   MOVE 'APPLICATION'        TO EXCEPTION-TYPE
              WHEN DATA-EXCEPTION
                   MOVE 'DATA'               TO EXCEPTION-TYPE
           END-EVALUATE
           ADD 46 TO EXCEPTION-RECORD-LEN
      *
           CALL WS-EXCEPTION-HANDLER
                USING EXCEPTION-RECORD-LEN
                    , EXCEPTION-RECORD
      *
           CONTINUE.
      *
       9000-EXIT.
      *
           EXIT.
