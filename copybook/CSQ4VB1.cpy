      *****************************************************************
      *   IBM MQ for z/OS                                             *
      *                                                               *
      *   NAME: CSQ4VB1                                               *
      *****************************************************************
      *   <copyright                                                  *
      *   notice="lm-source"                                          *
      *   pids="5655-W97"                                             *
      *   years="1993,2014"                                           *
      *   crc="1881164437" >                                          *
      *   Licensed Materials - Property of IBM                        *
      *                                                               *
      *   5655-W97                                                    *
      *                                                               *
      *   (C) Copyright IBM Corp. 1993, 2014 All Rights Reserved.     *
      *   </copyright>                                                *
      *                                                               *
      *****************************************************************
           10  CSQ4BIIM-MSG.
               15  CSQ4BIIM-MSGID          PIC X(8).
                   88 INITIAL-INQUIRY-MESSAGE VALUE 'CSQ4BIIM'.
               15  CSQ4BIIM-GROUP.
                   20  CSQ4BIIM-NAME           PIC X(20).
                   20  CSQ4BIIM-SOCSECNO1      PIC X(3).
                   20  CSQ4BIIM-SOCSECNO2      PIC X(2).
                   20  CSQ4BIIM-SOCSECNO3      PIC X(4).
                   20  CSQ4BIIM-BANKNAME       PIC X(30).
                   20  CSQ4BIIM-BANKACNAME     PIC X(30).
                   20  CSQ4BIIM-BANKACNUM      PIC X(10).
                   20  CSQ4BIIM-LOANREQ        PIC X(6).
