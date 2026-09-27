      ******************************************************************
      * DCLGEN TABLE(TRADE.TBTRDEXC)                                   *
      *        LIBRARY(CLOUDFRM.TRADING.BATCHDB2.DCLGEN(TBTRDEXC))     *
      *        ACTION(REPLACE)                                         *
      *        LANGUAGE(COBOL)                                         *
      *        QUOTE                                                   *
      *        INDVAR(YES)                                             *
      * ... IS THE DCLGEN COMMAND THAT MADE THE FOLLOWING STATEMENTS   *
      ******************************************************************
      *****EXEC SQL DECLARE TRADE.TBTRDEXC TABLE
      *****( EXC_ID                         INTEGER NOT NULL,
      *****  EXC_TYPE                       CHAR(20) NOT NULL,
      *****  EXC_DESCRIPTION                VARCHAR(1000) NOT NULL
      *****) END-EXEC.
      ******************************************************************
      * COBOL DECLARATION FOR TABLE TRADE.TBTRDEXC                     *
      ******************************************************************
       01  DCLTBTRDEXC.
           10 EXC-ID               PIC S9(9) USAGE COMP.
           10 EXC-TYPE             PIC X(20).
           10 EXC-DESCRIPTION.
              49 EXC-DESCRIPTION-LEN
                 PIC S9(4) USAGE COMP.
              49 EXC-DESCRIPTION-TEXT
                 PIC X(1000).
      ******************************************************************
      * INDICATOR VARIABLE STRUCTURE                                   *
      ******************************************************************
       01  ITBTRDEXC.
           10 INDSTRUC           PIC S9(4) USAGE COMP OCCURS 3 TIMES.
      ******************************************************************
      * THE NUMBER OF COLUMNS DESCRIBED BY THIS DECLARATION IS 3       *
      ******************************************************************
