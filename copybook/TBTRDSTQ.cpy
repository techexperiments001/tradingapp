      ******************************************************************
      * DCLGEN TABLE(TRADE.TBTRDSTQ)                                   *
      *        LIBRARY(CLOUDFRM.TRADING.BATCHDB2.DCLGEN(TBTRDSTQ))     *
      *        ACTION(REPLACE)                                         *
      *        LANGUAGE(COBOL)                                         *
      *        QUOTE                                                   *
      *        INDVAR(YES)                                             *
      * ... IS THE DCLGEN COMMAND THAT MADE THE FOLLOWING STATEMENTS   *
      ******************************************************************
      *****EXEC SQL DECLARE TRADE.TBTRDSTQ TABLE
      *****( STQ_CURRENCY                   CHAR(3) NOT NULL,
      *****  STQ_ID                         INTEGER NOT NULL,
      *****  STQ_TRADE_DATA                 CHAR(88) NOT NULL
      *****) END-EXEC.
      ******************************************************************
      * COBOL DECLARATION FOR TABLE TRADE.TBTRDSTQ                     *
      ******************************************************************
       01  DCLTBTRDSTQ.
           10 STQ-CURRENCY         PIC X(3).
           10 STQ-ID               PIC S9(9) USAGE COMP.
           10 STQ-TRADE-DATA       PIC X(88).
      ******************************************************************
      * INDICATOR VARIABLE STRUCTURE                                   *
      ******************************************************************
       01  ITBTRDSTQ.
           10 INDSTRUC           PIC S9(4) USAGE COMP OCCURS 3 TIMES.
      ******************************************************************
      * THE NUMBER OF COLUMNS DESCRIBED BY THIS DECLARATION IS 3       *
      ******************************************************************
