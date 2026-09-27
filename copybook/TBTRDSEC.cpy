      ******************************************************************
      * DCLGEN TABLE(TRADE.TBTRDSEC)                                   *
      *        LIBRARY(CLOUDFRM.TRADING.BATCHDB2.DCLGEN(TBTRDSEC))     *
      *        ACTION(REPLACE)                                         *
      *        LANGUAGE(COBOL)                                         *
      *        QUOTE                                                   *
      *        INDVAR(YES)                                             *
      * ... IS THE DCLGEN COMMAND THAT MADE THE FOLLOWING STATEMENTS   *
      ******************************************************************
      *****EXEC SQL DECLARE TRADE.TBTRDSEC TABLE
      *****( SEC_FIGI                       CHAR(12) NOT NULL,
      *****  SEC_CURRENCY                   CHAR(3) NOT NULL,
      *****  SEC_DESCRIPTION                CHAR(40) NOT NULL,
      *****  SEC_SYMBOL                     CHAR(20) NOT NULL,
      *****  SEC_SHARE_CLASS_FIGI           CHAR(12) NOT NULL,
      *****  SEC_TYPE                       CHAR(20) NOT NULL
      *****) END-EXEC.
      ******************************************************************
      * COBOL DECLARATION FOR TABLE TRADE.TBTRDSEC                     *
      ******************************************************************
       01  DCLTBTRDSEC.
           10 SEC-FIGI             PIC X(12).
           10 SEC-CURRENCY         PIC X(3).
           10 SEC-DESCRIPTION      PIC X(40).
           10 SEC-SYMBOL           PIC X(20).
           10 SEC-SHARE-CLASS-FIGI
              PIC X(12).
           10 SEC-TYPE             PIC X(20).
      ******************************************************************
      * INDICATOR VARIABLE STRUCTURE                                   *
      ******************************************************************
       01  ITBTRDSEC.
           10 INDSTRUC           PIC S9(4) USAGE COMP OCCURS 6 TIMES.
      ******************************************************************
      * THE NUMBER OF COLUMNS DESCRIBED BY THIS DECLARATION IS 6       *
      ******************************************************************
