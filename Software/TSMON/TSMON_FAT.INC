; These are some constants to help with reading & parsing FAT file system data

;File system table entry offsets
ofsBPS	EQU	$0B     ; bytes per sector
ofsSPC	EQU	$0D     ; sectors per cluster
ofsRSV	EQU	$0E     ; reserved sector count
ofsFAT	EQU	$10     ; number of FATs
ofsDIR	EQU	$11     ; max number of root directory entries
ofsMED	EQU	$15     ; media descriptor
ofsSPF	EQU	$16     ; sectors per FAT
ofsSPT	EQU	$18     ; sectors per Track
ofsHDS	EQU	$1A     ; number of heads
ofsHID	EQU	$1C     ; hidden sector count
ofsSIP	EQU	$20     ; sectors in partition
ofsVNM	EQU	$2B     ; volume name
ofsFST  EQU $36     ; file system type
ofsBTS  EQU $3E     ; bootstrap code
ofsKEY	EQU	$1FE    ; magic number 0xAA55

;File system table entries
;fsKEY	DS.W	1	;magic number to identify table has been read
;fsBPS	DS.W	1	;Bytes per Sector
;fsRSV	DS.W	1	;Reserved Sectors
;fsDIR	DS.W	1	;Max root directory entries
;fsSPF	DS.W	1	;Sectors per FAT
;fsSPT	DS.W	1	;Sectors per Track
;fsHDS	DS.W	1	;Number of Heads
;fsHID	DS.L	1	;Hidden Sectors
;fsSIP	DS.L	1	;Sectors in partition
;fsVNM	DS.B	12	;Volume Name
;fsSPC	DS.B	1	;Sectors Per Cluster
;fsFAT	DS.B	1	;Copes of FAT
;fsMED	DS.B	1	;MEDia desriptor
;	DS.B	1	;alignment...
;fsFATptr	DS.L	1	;LBA pointer to first FAT
;fsDIRptr	DS.L	1	;LBA pointer to root directory
;fsDATptr	DS.L	1	;LBA pointer to data area start