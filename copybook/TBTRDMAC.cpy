      ******************************************************************
      * DCLGEN TABLE(TRADE.TBTRDMAC)                                   *
      *        LIBRARY(CLOUDFRM.TRADING.BATCHDB2.DCLGEN(TBTRDMAC))     *
      *        ACTION(REPLACE)                                         *
      *        LANGUAGE(COBOL)                                         *
      *        QUOTE                                                   *
      *        INDVAR(YES)                                             *
      * ... IS THE DCLGEN COMMAND THAT MADE THE FOLLOWING STATEMENTS   *
      ******************************************************************
      *****EXEC SQL DECLARE TRADE.TBTRDMAC TABLE
      *****( MAC_CURRENCY                   CHAR(3) NOT NULL,
      *****  MAC_NUMBER                     INTEGER NOT NULL,
      *****  MAC_CUSTOMER_ID                CHAR(12) NOT NULL,
      *****  MAC_BALANCE                    DECIMAL(12, 2) NOT NULL,
      *****  MAC_STATUS                     CHAR(1) NOT NULL
      *****) END-EXEC.
      ******************************************************************
      * COBOL DECLARATION FOR TABLE TRADE.TBTRDMAC                     *
      ******************************************************************
       01  DCLTBTRDMAC.
           10 MAC-CURRENCY         PIC X(3).
           10 MAC-NUMBER           PIC S9(9) USAGE COMP.
           10 MAC-CUSTOMER-ID      PIC X(12).
           10 MAC-BALANCE          PIC S9(10)V9(2) USAGE COMP-3.
           10 MAC-STATUS           PIC X(1).
      ******************************************************************
      * INDICATOR VARIABLE STRUCTURE                                   *
      ******************************************************************
       01  ITBTRDMAC.
           10 INDSTRUC           PIC S9(4) USAGE COMP OCCURS 5 TIMES.
      ******************************************************************
      * THE NUMBER OF COLUMNS DESCRIBED BY THIS DECLARATION IS 5       *
      ******************************************************************
