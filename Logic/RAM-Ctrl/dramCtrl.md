# Wrap030-ATX DRAM Controller
DRAM Controller handles CPU access cycles to DRAM, including 68030 cache burst cycles. 

On reset, the controller will hold for 200 microseconds and then perform 8 refresh cycles as required by most DRAM chips. During this initialization period, the DRAM controller is unavailable for servicing any CPU cycles. Attempting to access main memory before initialization is complete is likely to result in a bus error when the bus controller times out waiting for a device to acknowledge the bus transaction. 

## DRAM Controller State Machine
```Mermaid
---
DRAM Controller State Machine
---
stateDiagram-v2
    state "Init" as s10
    state "Idle" as s0
    state "Cycle RAS 0" as s1
    state "Cycle CAS 0" as s2
    state "Cycle CAS 1" as s3
    state "Cycle Burst" as s4
    state "Cycle Burst End" as s5
    state "Refresh CAS 0" as s6
    state "Refresh RAS 0" as s7
    state "Refresh RAS 1" as s8
    state "Refresh RAS 2" as s9
    state "Write Register" as s11
    state "CPU Access Cycle" as CPU
    state "Refresh Cycle" as RFSH

    state initComplete <<choice>>
    state idleFork <<choice>>
    state endFork <<fork>>

    [*] --> s10: sysRESETn = 0

    s10 --> initComplete
    initComplete --> s10: initCount < 5000
    initComplete --> s0: initCount >= 5000

    s0 --> idleFork

    idleFork --> CPU: ramCEn = 0
    idleFork --> RFSH: refreshCall = 1
    idleFork --> s11: regCall = 1
    idleFork --> s0: (else)

    CPU --> endFork
    RFSH --> endFork
    endFork --> s0

    state CPU {
        [*] --> s1
        s1 --> s2
        s2 --> s3: cpuCBREQn = 0
        s3 --> s4: cpuCBREQn = 0
        s3 --> [*]: cpuCBREQn = 1
        s4 --> s5: cpuCBREQn = 1
        s4 --> s3: cpuCBREQn = 0
        s5 --> [*]
    }

    state RFSH{
        [*] --> s6
        s6 --> s7
        s7 --> s8
        s8 --> s9
        s9 --> [*]: initRfshCount = 7
        s9 --> s6: initRfshCount != 7
    }

    s11 --> s0
```