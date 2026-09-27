       01  LS-SECURITY-IO.
          05 LS-FIGI                   PIC X(12).
          05 LS-CURRENCY               PIC X(3).
          05 LS-DESCRIPTION            PIC X(40).
          05 LS-SYMBOL                 PIC X(20).
          05 LS-SHARE-CLASS-FIGI       PIC X(12).
          05 LS-TYPE                   PIC X(20).
          05 LS-SECURITY-ERROR-MSG     PIC X(200).
          05 LS-SECURITY-STATUS        PIC X(1).
             88 88-SECURITY-NOT-FOUND   VALUE 'N'.
             88 88-SECURITY-ACTIVE      VALUE 'A'.
             88 88-SECURITY-INACTIVE    VALUE 'I'.
             88 88-SECURITY-EXCEPTION   VALUE 'S'.
