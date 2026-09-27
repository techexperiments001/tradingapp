       01  WS-EXCEPTION-HANDLER             PIC  X(16)
           VALUE 'TRDPBEXC'.
       01  WS-DATE-TIME-VARS.
           05 WS-CURRDATE          PIC X(10).
           05 WS-CURRTIME          PIC X(8).
      *
       01  WS-EXCP-TYPE                     PIC X.
           88 NO-EXCEPTIONS                 VALUE 'N'.
           88 SYSTEM-EXCEPTION              VALUE 'S'.
           88 APPL-EXCEPTION                VALUE 'A'.
           88 DATA-EXCEPTION                VALUE 'D'.
      *
       01 EXCEPTION-RECORD-LEN              PIC S9(4) COMP.
      *
       01 EXCEPTION-RECORD.
      *   05 EXCEPTION-TIMESTAMP            PIC X(26).
          05 EXCEPTION-TYPE                 PIC X(20).
           88 EXCEPTION-SYSTEM              VALUE 'SYSTEM'.
           88 EXCEPTION-APPLICATION         VALUE 'APPLICATION'.
           88 EXCEPTION-DATA                VALUE 'DATA'.
          05 EXCEPTION-DESC                 PIC X(1000).
