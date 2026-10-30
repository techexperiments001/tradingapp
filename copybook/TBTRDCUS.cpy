      ******************************************************************
      * DCLGEN TABLE(TRADE.TBTRDCUS)                                   *
      *        LIBRARY(CLOUDFRM.TRADING.BATCHDB2.DCLGEN(TBTRDCUS))     *
      *        ACTION(REPLACE)                                         *
      *        LANGUAGE(COBOL)                                         *
      *        QUOTE                                                   *
      *        INDVAR(YES)                                             *
      * ... IS THE DCLGEN COMMAND THAT MADE THE FOLLOWING STATEMENTS   *
      ******************************************************************
      *****EXEC SQL DECLARE TRADE.TBTRDCUS TABLE
      *****( CUS_CUSTOMER_ID                CHAR(12) NOT NULL,
      *****  CUS_CURRENCY                   CHAR(3) NOT NULL,
      *****  CUS_DESCRIPTION                CHAR(40) NOT NULL,
      *****  CUS_STATUS                     CHAR(1) NOT NULL
      *****) END-EXEC.
      ******************************************************************
      * COBOL DECLARATION FOR TABLE TRADE.TBTRDCUS                     *
      ******************************************************************
       01  DCLTBTRDCUS.
           10 CUS-CUSTOMER-ID      PIC X(12).
           10 CUS-CURRENCY         PIC X(3).
           10 CUS-DESCRIPTION      PIC X(40).
           10 CUS-STATUS           PIC X(1).
      ******************************************************************
      * INDICATOR VARIABLE STRUCTURE                                   *
      ******************************************************************
       01  ITBTRDCUS.
           10 INDSTRUC           PIC S9(4) USAGE COMP OCCURS 4 TIMES.
      ******************************************************************
      * THE NUMBER OF COLUMNS DESCRIBED BY THIS DECLARATION IS 4       *
      ******************************************************************
