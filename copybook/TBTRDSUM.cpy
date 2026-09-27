      ******************************************************************
      * DCLGEN TABLE(TRADE.TBTRDSUM)                                   *
      *        LIBRARY(CLOUDFRM.TRADING.BATCHDB2.DCLGEN(TBTRDSUM))     *
      *        ACTION(REPLACE)                                         *
      *        LANGUAGE(COBOL)                                         *
      *        QUOTE                                                   *
      *        INDVAR(YES)                                             *
      * ... IS THE DCLGEN COMMAND THAT MADE THE FOLLOWING STATEMENTS   *
      ******************************************************************
      *****EXEC SQL DECLARE TRADE.TBTRDSUM TABLE
      *****( SUM_CUSTOMER_ID                CHAR(12) NOT NULL,
      *****  SUM_OVERDUE                    INTEGER NOT NULL,
      *****  SUM_REJECTED                   INTEGER NOT NULL,
      *****  SUM_SETTLED                    INTEGER NOT NULL,
      *****  SUM_CURRENCY                   CHAR(3) NOT NULL,
      *****  SUM_OPEN_BALANCE               DECIMAL(12, 2) NOT NULL,
      *****  SUM_TOTAL_DEBIT                DECIMAL(12, 2) NOT NULL,
      *****  SUM_TOTAL_CREDIT               DECIMAL(12, 2) NOT NULL,
      *****  SUM_CLOSE_BALANCE              DECIMAL(12, 2) NOT NULL
      *****) END-EXEC.
      ******************************************************************
      * COBOL DECLARATION FOR TABLE TRADE.TBTRDSUM                     *
      ******************************************************************
       01  DCLTBTRDSUM.
           10 SUM-CUSTOMER-ID      PIC X(12).
           10 SUM-OVERDUE          PIC S9(9) USAGE COMP.
           10 SUM-REJECTED         PIC S9(9) USAGE COMP.
           10 SUM-SETTLED          PIC S9(9) USAGE COMP.
           10 SUM-CURRENCY         PIC X(3).
           10 SUM-OPEN-BALANCE     PIC S9(10)V9(2) USAGE COMP-3.
           10 SUM-TOTAL-DEBIT      PIC S9(10)V9(2) USAGE COMP-3.
           10 SUM-TOTAL-CREDIT     PIC S9(10)V9(2) USAGE COMP-3.
           10 SUM-CLOSE-BALANCE    PIC S9(10)V9(2) USAGE COMP-3.
      ******************************************************************
      * INDICATOR VARIABLE STRUCTURE                                   *
      ******************************************************************
       01  ITBTRDSUM.
           10 INDSTRUC           PIC S9(4) USAGE COMP OCCURS 9 TIMES.
      ******************************************************************
      * THE NUMBER OF COLUMNS DESCRIBED BY THIS DECLARATION IS 9       *
      ******************************************************************
