    ORG 0
    MOVEQ   #$3,D0
    MOVEQ   #$2,D1
    MOVE.l  D0,$2000
    MOVE.l  D1,$2004
    FMOVE.l D0,FP0
    FMOVE.l D1,FP1
    FADD    FP1,FP0
    FMOVE.l FP0,D0
    MOVE.l  D0,$2008
    RTS

    FMOVE.s #2.25,FP0
    FMOVE.s #3.75,FP1
    FMOVE.s FP0,$2000
    FMOVE.s FP1,$2004
    FADD    FP1,FP0
    FMOVE.s FP0,$2008
    RTS
