# Wrap030-ATX Bus Controller

## Bus Controller Feature Description

The bus controller handles decoding the CPU Function Codes and Address bus to activate system memory and peripherals. For devices which do not produce their own bus cycle acknowledge signals, it handles timing & wait state generation and produces the appropriate cycle termination signals. It also receives incoming cycle termination signals from other bus devices and reproduces them for the CPU, meeting setup timing requirements. The bus controller generates a bus error for invalid accesses, missing FPU, and bus cycles which time out with no other external device providing an appropriate termination. It will also assert the CPU's cache inhibit signal for peripheral accesses which should not be cached. 

On initial power on, the bus controller will pull the power supply's power on signal low and hold it until the soft power bit in the bus controller register is cleared. 

The bus controller has an internal register accessible at address `$e000,0000` which holds the startup overlay enable bit, soft power control bit, and a general-purpose output for driving an LED.

## Bus Controller Cycles

- DRAM
  - Asserts the RAM chip enable signal and waits for the memory controller to assert its cycle ackowledge signal. 
- ROM
  - Asserts the ROM chip enable signal and the appropriate memory read or write strobe. Inserts wait states for a 70ns ROM and terminates bus cycle.
- Video Controller
  - Asserts the video chip enable signal and waits for the video generator to assert its cycle acknowledge signal.
- ISA
  - Asserts the ISA chip enable signal and waits for the ISA bus controlelr to assert the appropriate 8-bit or 16-bit cycle acknowledge signal.
- Serial/Parallel I/O
  - Asserts the SPIO chip enable signal and the appropriate memory read or write strobe. Inserts wait states for WD16C552 and terminates bus cycle.
- Keyboard Controller
  - Asserts the keyboard controller chip enable signal and waits for the keyboard controller to assert its cycle acknowledge signal.
- DRAM Controller
  - If startup overlay bit is clear:
    - Asserts the DRAM controller chip enable signal and waits for the DRAM controller to assert its cycle acknowledge signal.
  - If startup overlay bit is set:
    - Generates a bus error.
- Bus Controller
  - Reads or writes the bus controller register as appropriate and terminates the bus cycle.
- Interrupt Controller
  - Asserts the interrupt controller chip enable signal and waits for the interrupt controller to assert its cycle acknowledge signal.

## Bus Controller Settings Register
0. Startup Overlay
   - **SET**: Disable startup overlay
   - **CLEAR**: Enable startup overlay
1. Soft Power
   - **SET**: Power down
   - **CLEAR**: Normal operation
2. GPO LED
   - **SET**: LED on
   - **CLEAR**: LED off
3. (future use)
4. (future use)
5. (future use)
6. (future use)
7. (future use)

## Bus Controller State Machine

```mermaid
---
Bus Controller State Machine
---
stateDiagram-v2
    state "Idle" as sIDL
    state idleChoice <<fork>>
    state endFork <<fork>>
    state memChoice <<choice>>

    state "ROM 0" as sROM0
    state "ROM 1" as sROM1
    state "ROM 2" as sROM2
    state "ROM 3" as sROM3
    state "ROM Cycle" as sROM

    state "S/P I/O 0" as sSPIO0
    state "S/P I/O 1" as sSPIO1
    state "S/P I/O 2" as sSPIO2
    state "S/P I/O 3" as sSPIO3
    state "S/P I/O 4" as sSPIO4
    state "S/P I/O 5" as sSPIO5
    state "S/P I/O 6" as sSPIO6
    state "S/P I/O Cycle" as sSPIO

    state "DRAM Hold" as sDRAM0
    state "DRAM Access Cycle" as sDRAM

    state "FPU Start" as sFPU0
    state "FPU Term" as sFPU1
    state "FPU Access Cycle" as sFPU

    state "VidGen Start" as sVID0
    state "VidGen Term" as sVID1
    state "VidGen Access Cycle" as sVID

    state "Keyboard Start" as sKBD0
    state "Keyboard Term" as sKBD1
    state "Keyboard Access Cycle" as sKBD

    state "ISA Start" as sISA0
    state "ISA Term" as sISA1
    state "ISA Access Cycle" as sISA

    state "busCtrl Register Read" as sREGR
    state "busCtrl Register Write" as sREGW
    state regChoice <<choice>>
    state "busCtrl Register Cycle" as sREG
    
    state "IRQ Autovector" as sAVEC

    [*] --> sIDL: sysRESETn = 0
    sIDL --> idleChoice
    idleChoice --> sSPIO
    idleChoice --> sFPU
    idleChoice --> sVID
    idleChoice --> sKBD
    idleChoice --> sISA
    idleChoice --> memChoice
    idleChoice --> sREG
    idleChoice --> sAVEC

    sAVEC --> endFork

    state sREG {
        [*] --> regChoice
        regChoice --> sREGR: cpuRWn = 1
        regChoice --> sREGW: cpuRWn = 0
        sREGR --> [*]
        sREGW --> [*]
    }
    sREG --> endFork

    memChoice --> sDRAM: (overlay = 1 & cpuAddrHi = $00)
    memChoice --> sROM: ((overlay = 0 & cpuAddrHi = $00) | (overlay = 1 & cpuAddrHi = $f0))

    state sISA {
        [*] --> sISA0
        sISA0 --> sISA0: isaACK8n = 1 & isaACK16n = 1
        sISA0 --> sISA1
        sISA1 --> [*]
    }
    sISA --> endFork

    state sKBD {
        [*] --> sKBD0
        sKBD0 --> sKBD0: kbdACKn = 1
        sKBD0 --> sKBD1: kbdACKn = 0
        sKBD1 --> [*]
    }
    sKBD --> endFork

    state sVID {
        [*] --> sVID0
        sVID0 --> sVID0: vidACKn = 1
        sVID0 --> sVID1: vidACKn = 0
        sVID1 --> [*]
    }
    sVID --> endFork
    
    state sDRAM {
        [*] --> sDRAM0
        sDRAM0 --> sDRAM0: ramACKn = 1
        sDRAM0 --> [*]: ramACKn = 0
    }
    sDRAM --> endFork

    state sFPU {
        [*] --> sFPU0
        sFPU0 --> sFPU0: busACKn[0] = 1 & busACKn[1] = 1
        sFPU0 --> sFPU1
        sFPU1 --> [*]
    }
    sFPU --> endFork

    state sROM {
        [*] --> sROM0
        sROM0 --> sROM1
        sROM1 --> sROM2
        sROM2 --> sROM3
        sROM3 --> [*]
    }
    sROM --> endFork

    state sSPIO {
        [*] --> sSPIO0
        sSPIO0 --> sSPIO1
        sSPIO1 --> sSPIO2
        sSPIO2 --> sSPIO3
        sSPIO3 --> sSPIO4
        sSPIO4 --> sSPIO5
        sSPIO5 --> sSPIO6
        sSPIO6 --> [*]
    }
    sSPIO --> endFork
```