      ******************************************************************
      * DCLGEN TABLE(TRADE.TBTRDPOS)                                   *
      *        LIBRARY(CLOUDFRM.TRADING.BATCHDB2.DCLGEN(TBTRDPOS))     *
      *        ACTION(REPLACE)                                         *
      *        LANGUAGE(COBOL)                                         *
      *        QUOTE                                                   *
      *        INDVAR(YES)                                             *
      * ... IS THE DCLGEN COMMAND THAT MADE THE FOLLOWING STATEMENTS   *
      ******************************************************************
      *****EXEC SQL DECLARE TRADE.TBTRDPOS TABLE
      *****( POS_CURRENCY                   CHAR(3) NOT NULL,
      *****  POS_SAC_NUMBER                 INTEGER NOT NULL,
      *****  POS_FIGI                       CHAR(12) NOT NULL,
      *****  POS_BALANCE                    DECIMAL(12, 2) NOT NULL
      *****) END-EXEC.
      ******************************************************************
      * COBOL DECLARATION FOR TABLE TRADE.TBTRDPOS                     *
      ******************************************************************
       01  DCLTBTRDPOS.
           10 POS-CURRENCY         PIC X(3).
           10 POS-SAC-NUMBER       PIC S9(9) USAGE COMP.
           10 POS-FIGI             PIC X(12).
           10 POS-BALANCE          PIC S9(10)V9(2) USAGE COMP-3.
      ******************************************************************
      * INDICATOR VARIABLE STRUCTURE                                   *
      ******************************************************************
       01  ITBTRDPOS.
           10 INDSTRUC           PIC S9(4) USAGE COMP OCCURS 4 TIMES.
      ******************************************************************
      * THE NUMBER OF COLUMNS DESCRIBED BY THIS DECLARATION IS 4       *
      ******************************************************************
