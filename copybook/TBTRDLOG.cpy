      ******************************************************************
      * DCLGEN TABLE(TRADE.TBTRDLOG)                                   *
      *        LIBRARY(CLOUDFRM.TRADING.BATCHDB2.DCLGEN(TBTRDLOG))     *
      *        ACTION(REPLACE)                                         *
      *        LANGUAGE(COBOL)                                         *
      *        QUOTE                                                   *
      *        INDVAR(YES)                                             *
      * ... IS THE DCLGEN COMMAND THAT MADE THE FOLLOWING STATEMENTS   *
      ******************************************************************
      *****EXEC SQL DECLARE TRADE.TBTRDLOG TABLE
      *****( LOG_TRANSACTION                CHAR(10) NOT NULL,
      *****  LOG_CURRENCY                   CHAR(3) NOT NULL,
      *****  LOG_START_TS                   CHAR(26) NOT NULL,
      *****  LOG_END_TS                     CHAR(26) NOT NULL
      *****) END-EXEC.
      ******************************************************************
      * COBOL DECLARATION FOR TABLE TRADE.TBTRDLOG                     *
      ******************************************************************
       01  DCLTBTRDLOG.
           10 LOG-TRANSACTION      PIC X(10).
           10 LOG-CURRENCY         PIC X(3).
           10 LOG-START-TS         PIC X(26).
           10 LOG-END-TS           PIC X(26).
      ******************************************************************
      * INDICATOR VARIABLE STRUCTURE                                   *
      ******************************************************************
       01  ITBTRDLOG.
           10 INDSTRUC           PIC S9(4) USAGE COMP OCCURS 4 TIMES.
      ******************************************************************
      * THE NUMBER OF COLUMNS DESCRIBED BY THIS DECLARATION IS 4       *
      ******************************************************************
