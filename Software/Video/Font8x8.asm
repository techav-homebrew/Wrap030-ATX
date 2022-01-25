
fontDataBase:   EQU $00250000

    ORG fontDataBase

fontData:

asciiNull:  dcb.b   8,0                                 ; 00 Null
asciiSOH:   dcb.b   8,0                                 ; 01 Start of Heading
asciiSTX:   dcb.B   8,0                                 ; 02 Start of Text
asciiETX:   dcb.B   8,0                                 ; 03 End of Text
asciiEOT:   dcb.B   8,0                                 ; 04 End of Transmission
asciiENQ:   dcb.B   8,0                                 ; 05 Enquiry
asciiACK:   dcb.B   8,0                                 ; 06 Acknowledge
asciiBEL:   dcb.B   8,0                                 ; 07 Bell
asciiBS:    dcb.B   8,0                                 ; 08 Backspace
asciiTAB:   dcb.B   8,0                                 ; 09 Horizontal Tab
asciiLFd:   dcb.B   8,0                                 ; 0A Line Feed
asciiVT:    dcb.B   8,0                                 ; 0B Vertical Tab
asciiFF:    dcb.B   8,0                                 ; 0C Form Feed
asciiCR:    dcb.B   8,0                                 ; 0D Carriage Return
asciiSO:    dcb.B   8,0                                 ; 0E Shift Out
asciiSI:    dcb.B   8,0                                 ; 0F Shift In
asciiDLE:   dcb.B   8,0                                 ; 10 Data Link Escape
asciiDC1:   dcb.B   8,0                                 ; 11 Device Control 1
asciiDC2:   dcb.B   8,0                                 ; 12 Device Control 2
asciiDC3:   dcb.B   8,0                                 ; 13 Device Control 3
asciiDC4:   dcb.B   8,0                                 ; 14 Device Control 4
asciiNAK:   dcb.B   8,0                                 ; 15 Negative Acknowledge
asciiSYN:   dcb.B   8,0                                 ; 16 Synchronous Idle
asciiETB:   dcb.B   8,0                                 ; 17 End of Trans. Block
asciiCAN:   dcb.B   8,0                                 ; 18 Cancel
asciiEM:    dcb.B   8,0                                 ; 19 End of Medium
asciiSUB:   dcb.B   8,0                                 ; 1A Substitute
asciiESC:   dcb.B   8,0                                 ; 1B Escape
asciiFS:    dcb.B   8,0                                 ; 1C File Separator
asciiGS:    dcb.B   8,0                                 ; 1D Group Separator
asciiRS:    dcb.B   8,0                                 ; 1E Record Separator
asciiUS:    dcb.B   8,0                                 ; 1F Unit Separator
asciiSpace: dcb.B   8,0                                 ; 20 Space
asciiExcl:  dc.b    $18,$3C,$3C,$18,$18,$00,$18,$00     ; 21 !
asciiDQuot: dc.B    $28,$28,$28,$00,$00,$00,$00,$00     ; 22 "
asciiPound: dc.B    $36,$36,$7f,$36,$7f,$36,$36,$00     ; 23 #
asciiDlr:   dc.B    $18,$3c,$60,$3c,$06,$3c,$18,$00     ; 24 $
asciiPcnt:  dc.B    $63,$66,$0c,$18,$33,$63,$00,$00     ; 25 %
asciiAnd:   dc.B    $1c,$36,$1c,$3b,$63,$66,$3b,$00     ; 26 &
asciiSQuot: dc.B    $10,$10,$10,$00,$00,$00,$00,$00     ; 27 '
asciiOParn: dc.B    $0c,$18,$30,$30,$30,$18,$0c,$00     ; 28 (
asciiCParn: dc.B    $30,$18,$0C,$0C,$0C,$18,$30,$00     ; 29 )
asciiStar:  dc.B    $00,$66,$3C,$7E,$3C,$66,$00,$00     ; 2A *
asciiPlus:  dc.B    $00,$18,$18,$7E,$18,$18,$00,$00     ; 2B +
asciiComma: dc.B    $00,$00,$00,$00,$00,$18,$08,$10     ; 2C ,
asciiDash:  dc.B    $00,$00,$00,$7e,$00,$00,$00,$00     ; 2D -
asciiPerod: dc.B    $00,$00,$00,$00,$00,$18,$18,$00     ; 2E .
asciiSlash: dc.B    $03,$06,$0C,$18,$30,$60,$C0,$00     ; 2F /
ascii0:     dc.B    $3c,$66,$6e,$76,$66,$66,$3c,$00     ; 30 0
ascii1:     dc.B    $18,$38,$18,$18,$18,$18,$3c,$00     ; 31 1
ascii2:     dc.B    $3c,$66,$0c,$18,$30,$60,$7e,$00     ; 32 2
ascii3:     dc.B    $7e,$0c,$18,$34,$06,$66,$3c,$00     ; 33 3
ascii4:     dc.B    $0e,$1e,$36,$66,$7f,$06,$06,$00     ; 34 4
ascii5:     dc.B    $7e,$60,$7c,$06,$06,$66,$3c,$00     ; 35 5
ascii6:     dc.B    $1c,$30,$60,$7c,$66,$66,$3c,$00     ; 36 6
ascii7:     dc.B    $7e,$06,$06,$0c,$18,$18,$18,$00     ; 37 7
ascii8:     dc.B    $3c,$66,$66,$3c,$66,$66,$3c,$00     ; 38 8
ascii9:     dc.B    $3c,$66,$66,$3e,$06,$0c,$38,$00     ; 39 9
asciiColon: dc.B    $00,$00,$18,$18,$00,$18,$18,$00     ; 3A :
asciiSCln:  dc.B    $00,$00,$18,$18,$00,$18,$08,$10     ; 3B ;
asciiLTn:   dc.B    $0c,$18,$30,$60,$30,$18,$0c,$00     ; 3C <
asciiEqual: dc.B    $00,$00,$7e,$00,$7e,$00,$00,$00     ; 3D =
asciiGTn:   dc.B    $30,$18,$0c,$06,$0c,$18,$30,$00     ; 3E >
asciiQstn:  dc.B    $3c,$66,$06,$0c,$18,$00,$18,$00     ; 3F ?
asciiAt:    dc.B    $3e,$63,$6f,$69,$6f,$60,$3e,$00     ; 40 @
asciiA:     dc.B    $18,$3c,$66,$66,$7e,$66,$66,$00     ; 41 A
asciiB:     dc.B    $7c,$66,$66,$7c,$66,$66,$7c,$00     ; 42 B
asciiC:     dc.B    $3c,$66,$60,$60,$60,$66,$3c,$00     ; 43 C
asciiD:     dc.B    $78,$6c,$66,$66,$66,$6c,$78,$00     ; 44 D
asciiE:     dc.B    $7e,$60,$60,$78,$60,$60,$7e,$00     ; 45 E
asciiF:     dc.B    $7e,$60,$60,$78,$60,$60,$60,$00     ; 46 F
asciiG:     dc.B    $3c,$66,$60,$6e,$66,$66,$3e,$00     ; 47 G
asciiH:     dc.B    $66,$66,$66,$7e,$66,$66,$66,$00     ; 48 H
asciiI:     dc.B    $7e,$18,$18,$18,$18,$18,$7e,$00     ; 49 I
asciiJ:     dc.B    $0e,$06,$06,$06,$06,$66,$3c,$00     ; 4A J
asciiK:     dc.B    $66,$66,$6c,$78,$6c,$66,$66,$00     ; 4B K
asciiL:     dc.B    $60,$60,$60,$60,$60,$60,$7e,$00     ; 4C L
asciiM:     dc.B    $63,$77,$7F,$6B,$63,$63,$63,$00     ; 4D M
asciiN:     dc.B    $63,$73,$7b,$6f,$67,$63,$63,$00     ; 4E N
asciiO:     dc.B    $3c,$66,$66,$66,$66,$66,$3c,$00     ; 4F O
asciiP:     dc.B    $7c,$66,$66,$7c,$60,$60,$60,$00     ; 50 P
asciiQ:     dc.B    $3c,$66,$66,$66,$66,$6c,$36,$00     ; 51 Q
asciiR:     dc.B    $7c,$66,$66,$7c,$6c,$66,$66,$00     ; 52 R
asciiS:     dc.B    $3c,$66,$60,$3c,$06,$66,$3c,$00     ; 53 S
asciiT:     dc.B    $7e,$18,$18,$18,$18,$18,$18,$00     ; 54 T
asciiU:     dc.B    $66,$66,$66,$66,$66,$66,$3c,$00     ; 55 U
asciiV:     dc.B    $66,$66,$66,$66,$66,$3C,$18,$00     ; 56 V
asciiW:     dc.B    $63,$63,$63,$6B,$7F,$77,$63,$00     ; 57 W
asciiX:     dc.B    $63,$63,$36,$1c,$36,$63,$63,$00     ; 58 X
asciiY:     dc.B    $66,$66,$66,$3c,$18,$18,$18,$00     ; 59 Y
asciiZ:     dc.B    $7e,$06,$0c,$18,$30,$60,$7e,$00     ; 5A Z
asciiOSqBk: dc.B    $3c,$30,$30,$30,$30,$30,$3c,$00     ; 5B [
asciiBSlsh: dc.B    $c0,$60,$30,$18,$0c,$06,$03,$00     ; 5C \
asciiCSqBk: dc.B    $3c,$0c,$0c,$0c,$0c,$0c,$3c,$00     ; 5D ]
asciiCaret: dc.B    $18,$3c,$66,$00,$00,$00,$00,$00     ; 5E ^
asciiUScr:  dc.B    $00,$00,$00,$00,$00,$00,$7E,$00     ; 5F _
asciiTick:  dc.B    $30,$18,$0c,$00,$00,$00,$00,$00     ; 60 `
asciiLA:    dc.B    $00,$00,$3c,$06,$3e,$66,$3e,$00     ; 61 a
asciiLB:    dc.b    $60,$60,$7c,$66,$66,$66,$7c,$00     ; 62 b
asciiLC:    dc.B    $00,$00,$3c,$60,$60,$60,$3c,$00     ; 63 c
asciiLD:    dc.B    $06,$06,$3e,$66,$66,$66,$3e,$00     ; 64 d
asciiLE:    dc.B    $00,$00,$3c,$66,$7e,$60,$3c,$00     ; 65 e
asciiLF:    dc.B    $1c,$30,$30,$7c,$30,$30,$30,$00     ; 66 f
asciiLG:    dc.B    $00,$00,$3c,$66,$66,$3e,$06,$7c     ; 67 g
asciiLH:    dc.B    $60,$60,$60,$7c,$66,$66,$66,$00     ; 68 h
asciiLI:    dc.B    $00,$18,$00,$38,$18,$18,$18,$00     ; 69 i
asciiLJ:    dc.B    $00,$18,$00,$38,$18,$18,$d8,$70     ; 6A j
asciiLK:    dc.B    $60,$60,$66,$6c,$78,$6c,$66,$00     ; 6B k
asciiLL:    dc.B    $38,$18,$18,$18,$18,$18,$1c,$00     ; 6C l
asciiLM:    dc.B    $00,$00,$76,$7f,$6b,$6b,$6b,$00     ; 6D m
asciiLN:    dc.B    $00,$00,$7c,$66,$66,$66,$66,$00     ; 6E n
asciiLO:    dc.B    $00,$00,$3c,$66,$66,$66,$3c,$00     ; 6F o
asciiLP:    dc.B    $00,$00,$7c,$66,$66,$66,$7c,$60     ; 70 p
asciiLQ:    dc.B    $00,$00,$3e,$66,$66,$66,$3e,$07     ; 71 q
asciiLR:    dc.B    $00,$00,$7c,$66,$60,$60,$60,$00     ; 72 r
asciiLS:    dc.B    $00,$00,$3e,$60,$3c,$06,$7c,$00     ; 73 s
asciiLT:    dc.B    $18,$18,$18,$3c,$18,$18,$0c,$00     ; 74 t
asciiLU:    dc.B    $00,$00,$66,$66,$66,$66,$3e,$00     ; 75 u
asciiLV:    dc.B    $00,$00,$66,$66,$66,$3c,$18,$00     ; 76 v
asciiLW:    dc.B    $00,$00,$63,$63,$6b,$7f,$36,$00     ; 77 w
asciiLX:    dc.B    $00,$00,$63,$36,$1c,$36,$63,$00     ; 78 x
asciiLY:    dc.B    $00,$00,$66,$66,$66,$3e,$06,$3C     ; 79 y
asciiLZ:    dc.B    $00,$00,$7e,$0c,$18,$30,$7e,$00     ; 7A z
asciiOCrlB: dc.B    $0c,$18,$18,$30,$18,$18,$0c,$00     ; 7B {
asciiPipe:  dc.B    $18,$18,$18,$00,$18,$18,$18,$00     ; 7C |
asciiCCrlB: dc.B    $30,$18,$18,$0c,$18,$18,$30,$00     ; 7D }
asciiTilde: dc.B    $00,$00,$3b,$6e,$00,$00,$00,$00     ; 7E ~
asciiDel:   dcb.b   8,0                                 ; 7F DEL
