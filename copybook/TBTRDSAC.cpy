      ******************************************************************
      * DCLGEN TABLE(TRADE.TBTRDSAC)                                   *
      *        LIBRARY(CLOUDFRM.TRADING.BATCHDB2.DCLGEN(TBTRDSAC))     *
      *        ACTION(REPLACE)                                         *
      *        LANGUAGE(COBOL)                                         *
      *        QUOTE                                                   *
      *        INDVAR(YES)                                             *
      * ... IS THE DCLGEN COMMAND THAT MADE THE FOLLOWING STATEMENTS   *
      ******************************************************************
      *****EXEC SQL DECLARE TRADE.TBTRDSAC TABLE
      *****( SAC_CURRENCY                   CHAR(3) NOT NULL,
      *****  SAC_NUMBER                     INTEGER NOT NULL,
      *****  SAC_CUSTOMER_ID                CHAR(12) NOT NULL,
      *****  SAC_STATUS                     CHAR(1) NOT NULL
      *****) END-EXEC.
      ******************************************************************
      * COBOL DECLARATION FOR TABLE TRADE.TBTRDSAC                     *
      ******************************************************************
       01  DCLTBTRDSAC.
           10 SAC-CURRENCY         PIC X(3).
           10 SAC-NUMBER           PIC S9(9) USAGE COMP.
           10 SAC-CUSTOMER-ID      PIC X(12).
           10 SAC-STATUS           PIC X(1).
      ******************************************************************
      * INDICATOR VARIABLE STRUCTURE                                   *
      ******************************************************************
       01  ITBTRDSAC.
           10 INDSTRUC           PIC S9(4) USAGE COMP OCCURS 4 TIMES.
      ******************************************************************
      * THE NUMBER OF COLUMNS DESCRIBED BY THIS DECLARATION IS 4       *
      ******************************************************************
