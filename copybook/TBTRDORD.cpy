      ******************************************************************
      * DCLGEN TABLE(TRADE.TBTRDORD)                                   *
      *        LIBRARY(CLOUDFRM.TRADING.BATCHDB2.DCLGEN(TBTRDORD))     *
      *        ACTION(REPLACE)                                         *
      *        LANGUAGE(COBOL)                                         *
      *        QUOTE                                                   *
      *        INDVAR(YES)                                             *
      * ... IS THE DCLGEN COMMAND THAT MADE THE FOLLOWING STATEMENTS   *
      ******************************************************************
      *****EXEC SQL DECLARE TRADE.TBTRDORD TABLE
      *****( ORD_TRADING_XCHNG              CHAR(10) NOT NULL,
      *****  ORD_TRADEID                    CHAR(12) NOT NULL,
      *****  ORD_BUY_SELL_IND               CHAR(1) NOT NULL,
      *****  ORD_CUSTOMER_ID                CHAR(12) NOT NULL,
      *****  ORD_FIGI                       CHAR(12) NOT NULL,
      *****  ORD_QUANTITY                   DECIMAL(9, 2) NOT NULL,
      *****  ORD_CURRENCY                   CHAR(3) NOT NULL,
      *****  ORD_AMOUNT                     DECIMAL(9, 2) NOT NULL,
      *****  ORD_STATUS                     CHAR(3) NOT NULL
      *****) END-EXEC.
      ******************************************************************
      * COBOL DECLARATION FOR TABLE TRADE.TBTRDORD                     *
      ******************************************************************
       01  DCLTBTRDORD.
           10 ORD-TRADING-XCHNG    PIC X(10).
           10 ORD-TRADEID          PIC X(12).
           10 ORD-BUY-SELL-IND     PIC X(1).
           10 ORD-CUSTOMER-ID      PIC X(12).
           10 ORD-FIGI             PIC X(12).
           10 ORD-QUANTITY         PIC S9(7)V9(2) USAGE COMP-3.
           10 ORD-CURRENCY         PIC X(3).
           10 ORD-AMOUNT           PIC S9(7)V9(2) USAGE COMP-3.
           10 ORD-STATUS           PIC X(3).
      ******************************************************************
      * INDICATOR VARIABLE STRUCTURE                                   *
      ******************************************************************
       01  ITBTRDORD.
           10 INDSTRUC           PIC S9(4) USAGE COMP OCCURS 9 TIMES.
      ******************************************************************
      * THE NUMBER OF COLUMNS DESCRIBED BY THIS DECLARATION IS 9       *
      ******************************************************************
