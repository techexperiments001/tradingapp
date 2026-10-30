       01 TRD-ORDER-PAIR.
          05 TRD-EXCHANGE              PIC X(10).
          05 TRD-BUYER-ID              PIC X(12).
          05 TRD-SELLER-ID             PIC X(12).
          05 TRD-ORDER-ID              PIC X(12).
          05 TRD-FIGI                  PIC X(12).
          05 TRD-ORDER-QTY             PIC S9(7)V9(2) USAGE COMP-3.
          05 TRD-CURRENCY              PIC X(03).
          05 TRD-ORDER-AMOUNT          PIC S9(7)V9(2) USAGE COMP-3.
          05 TRD-BUYER-SEC-ACC-NUM     PIC S9(9) USAGE COMP.
          05 TRD-BUYER-MONEY-ACC-NUM   PIC S9(9) USAGE COMP.
          05 TRD-SELLER-SEC-ACC-NUM    PIC S9(9) USAGE COMP.
          05 TRD-SELLER-MONEY-ACC-NUM  PIC S9(9) USAGE COMP.
          05 TRD-STATUS                PIC X.
             88 TRD-ACCEPTED           VALUE 'A'.
             88 TRD-SAC-BOOKING-DONE   VALUE 'S'.
             88 TRD-SAC-BOOKING-FAILED VALUE 'F'.
             88 TRD-MAC-BOOKING-DONE   VALUE 'M'.
             88 TRD-MAC-BOOKING-FAILED VALUE 'N'.
