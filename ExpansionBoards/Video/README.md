# Video Board
The Video Board has a 128-macrocell CPLD on an 8-bit data bus, with 64kB of video memory on its own 8-bit data bus. Output is 4-bit RGBI to a basic resistor DAC. Video output can be configured to select from one of four video modes (all output as 640x400@70Hz, but with line or pixel doubling as necessary), with two modes supporting two independent frame buffers. The Video Board does not support interrupts, but can be polled to determine if the video generator is currently in a horizontal or vertical blanking period, to help support double-buffered video in modes that support two frame buffers. 

## Video Modes
The Video Board supports three video modes:

0. 320x200 4bpp RGBI, 
   - line & pixel doubled to 640x400
   - 2x 32kB frame buffers at 0x0000 & 0x8000
1. 320x400 4bpp RGBI
   - pixel doubled to 640x400
   - 1x 64kB frame buffer at 0x0000
2. 640x200 2bpp grayscale
   - line doubled to 640x400
   - 2x 32kB frame buffers at 0x0000 & 0x8000
3. 640x400 2bpp grayscale
   - no line or pixel doubling
   - 1x 64kB frame buffer at 0x0000

## Configuration
The Video Board has a single 8-bit configuration register at CPU address 0xffff:

| 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| X | X | VBlank | HBlank | Mode 1 | Mode 0 | Buffer | Blank |

- Blank:
  - Blanks the video output when set
  - 1: Output video is forced to black (0x0000)
  - 0: Normal video output is enabled
- Buffer:
  - Selects the active frame buffer in modes 0 & 2
  - 1: Active Frame Buffer starts at 0x8000 (VRAM Chip 1)
  - 0: Active Frame Buffer starts at 0x0000 (VRAM Chip 0)
- Mode:
  - Selects the current video mode
  - 00: 320x200 4bpp RGBI
  - 01: 320x400 4bpp RGBI
  - 10: 640x200 2bpp gray
  - 11: 640x400 2bpp gray
- HBlank [Read Only]:
  - Current state of the Horizonal Sync period
  - 1: Horizontal blanking period
  - 0: Horizontal active video period
- VBlank [Read Only]:
  - Current state of the Vertical Sync period
  - 1: Vertical blanking period
  - 0: Vertical active video period
