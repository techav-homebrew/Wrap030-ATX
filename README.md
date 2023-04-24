# Wrap030
Homebrew mATX form-factor 68030 computer

# Memory Map

## Normal Operation
This is the space allocated to each device (even if the device will not use the entire address space allocated, such as the PS/2 keyboard controller which uses no address lines). 

| Device            | Start         | End           | Size                      |
| ----------------- | ------------- | ------------- | ------------------------- |
| Main Memory       | `$0000,0000`  | `$7fff,ffff`  | 2048MB (256MB available)  |
| Unused (BERR)     | `$8000,0000`  | `$cfff,ffff`  | 1280MB    |
| Video             | `$d000,0000`  | `$d0ff,ffff`  |   16MB    |
| Unused (BERR)     | `$d100,0000`  | `$d1ff,ffff`  |   16MB    |
| ISA Memory        | `$d200,0000`  | `$d2ff,ffff`  |   16MB    |
| ISA I/O           | `$d300,0000`  | `$d3ff,ffff`  |   16MB    |
| Unused (BERR)     | `$d400,0000`  | `$dbff,ffff`  |  128MB    |
| S/P I/O           | `$dc00,0000`  | `$dcff,ffff`  |   16MB    |
| Reserved (BERR)   | `$dd00,0000`  | `$ddff,ffff`  |   16MB    |
| Keyboard          | `$de00,0000`  | `$deff,ffff`  |   16MB    |
| Reserved (BERR)   | `$df00,0000`  | `$dfff,ffff`  |   16MB    |
| Bus Ctrl Reg      | `$e000,0000`  | `$e0ff,ffff`  |   16MB    |
| DRAM Ctrl Reg     | `$e100,0000`  | `$e1ff,ffff`  |   16MB    |
| IRQ Ctrl Reg      | `$e200,0000`  | `$e2ff,ffff`  |   16MB    |
| Unused (BERR)     | `$e300,0000`  | `$efff,ffff`  |  208MB    |
| ROM               | `$f000,0000`  | `$ffff,ffff`  |  256MB    |

## Reset Overlay
The reset overlay allows ROM to be read from the first 256MB of the CPU address space so the CPU can load the proper startup vectors. While the reset overlay is enabled, DRAM is write-only through the first 256MB (the entire DRAM space available on the Wrap030-ATX board). ROM will continue to be readable in its normal address space. This allows the reset vector to point to ROM at its normal address.

The reset overlay is enabled by default on power on. It is disabled by setting the overlay bit on the bus controller register. 

| Device            | Start         | End           | Notes                       |
| ----------------- | ------------- | ------------- | --------------------------- |
| ROM Overlay       | `$0000,0000`  | `$0fff,ffff`  | Read-only 256MB ROM space   |
| DRAM Overlay      | `$0000,0000`  | `$0fff,ffff`  | Write-Only 256MB DRAM space |
| DRAM              | `$1000,0000`  | `$7fff,ffff`  | Read/Write DRAM space       |
| ROM               | `$f000,0000`  | `$ffff,ffff`  | Read/Write ROM space        |

