; ELF header offsets
eIdent:     equ $00
eType:      equ $10
eMachine:   equ $12
eVersion:   equ $14
eEntry:     equ $18
ePhoff:     equ $1C
eShoff:     equ $20
eFlag:      equ $24
eEhSize:    equ $28
ePhentSize: equ $2A
ePhNum:     equ $2C
eShentSize: equ $2E
eShNum:     equ $30
eShstrndx:  equ $32

elfMag:     equ $7f454c46

; ELF Section header offsets
shName:         equ $00
shType:         equ $04
shFlag:         equ $08
shAddr:         equ $0C
shOffset:       equ $10
shSize:         equ $14
shLink:         equ $18
shInfo:         equ $1C
shAddrAlign:    equ $20
shEntSize:      equ $24

; ELF Program header offsets
pType:      equ $00
pOffset:    equ $04
pVaddr:     equ $08
pPaddr:     equ $0C
pFileSz:    equ $10
pMemSz:     equ $14
pFlag:      equ $18
pAlign:     equ $1C

; ELF Program header types
ptNull:     equ $0
ptLoad:     equ $1
ptDynamic:  equ $2
ptInterp:   equ $3
ptNote:     equ $4
ptShlib:    equ $5
ptPhdr:     equ $6
ptTls:      equ $7
