| These are some constants to help with reading & parsing FAT file system data

|File system table entry offsets
    .equ ofsBPS, 0x0B     | bytes per sector
    .equ ofsSPC, 0x0D     | sectors per cluster
    .equ ofsRSV, 0x0E     | reserved sector count
    .equ ofsFAT, 0x10     | number of FATs
    .equ ofsDIR, 0x11     | max number of root directory entries
    .equ ofsMED, 0x15     | media descriptor
    .equ ofsSPF, 0x16     | sectors per FAT
    .equ ofsSPT, 0x18     | sectors per Track
    .equ ofsHDS, 0x1A     | number of heads
    .equ ofsHID, 0x1C     | hidden sector count
    .equ ofsSIP, 0x20     | sectors in partition
    .equ ofsVNM, 0x2B     | volume name
    .equ ofsFST, 0x36     | file system type
    .equ ofsBTS, 0x3E     | bootstrap code
    .equ ofsKEY, 0x1FE    | magic number 0xAA55

|File system table entries
|fsKEY	DS.W	1	|magic number to identify table has been read
|fsBPS	DS.W	1	|Bytes per Sector
|fsRSV	DS.W	1	|Reserved Sectors
|fsDIR	DS.W	1	|Max root directory entries
|fsSPF	DS.W	1	|Sectors per FAT
|fsSPT	DS.W	1	|Sectors per Track
|fsHDS	DS.W	1	|Number of Heads
|fsHID	DS.L	1	|Hidden Sectors
|fsSIP	DS.L	1	|Sectors in partition
|fsVNM	DS.B	12	|Volume Name
|fsSPC	DS.B	1	|Sectors Per Cluster
|fsFAT	DS.B	1	|Copes of FAT
|fsMED	DS.B	1	|MEDia desriptor
|	DS.B	1	|alignment...
|fsFATptr	DS.L	1	|LBA pointer to first FAT
|fsDIRptr	DS.L	1	|LBA pointer to root directory
|fsDATptr	DS.L	1	|LBA pointer to data area start
