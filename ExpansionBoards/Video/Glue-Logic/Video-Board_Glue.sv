/******************************************************************************
 * Wrap030 Video Generator Logic
 * techav
 * 2022-12-16
 ******************************************************************************
 * 2022-12-26 changed vram address calculation to an address counter to reduce
 *            macrocell utilization
 *****************************************************************************/

module vidGen (
    input   wire                nReset,     // primary system reset         1
    input   wire                pixClk,     // primary video pixel clock    83
    input   wire                nCpuCE,     // cpu bus chip enable signal   84
    output  reg                 nVramWr,    // vram bus write strobe        12
    output  wire [14:0]         vramAddr,   // vram bus address signals
    input   wire                nCpuDS,     // cpu bus data strobe          6
    inout   reg                 nCpuDSACK,  // cpu data strobe acknowledge  5
    output  reg                 nVramRd,    // vram bus read strobe         22
    inout   reg [7:0]           vramData,   // vram bus data signals
    output  reg                 nVramCE0,   // vram bus chip 0 enable       29
    output  reg                 nVramCE1,   // vram bus chip 1 enable       44
    input   wire                cpuRnW,     // cpu bus read/write signal    41
    output  reg  [3:0]          vidOut,     // video RGBI output            45,49,51,46
    output  reg                 vidV,       // video VSync output           48
    output  reg                 vidH,       // video HSync output           50
    inout   reg [7:0]           cpuData,    // cpu bus data signals
    input   wire [15:0]         cpuAddr     // cpu bus address signals
);

// we're going with 640x400@70Hz, from 25.175MHz pixel clock
parameter H_TOTAL = 800;
parameter H_VIS = 640;
parameter H_FRONT = 16;
parameter H_SYNC = 96;
parameter H_BACK = 48;

parameter V_TOTAL = 449;
parameter V_VIS = 400;
parameter V_FRONT = 12;
parameter V_SYNC = 2;
parameter V_BACK = 35;

// these are our configuration registers
reg [1:0]   rVidMode    = 0;    // select from the 4 different video modes
reg         rBufSel     = 0;    // video modes 0 & 2 can be double-buffered
reg         rVidBlank   = 0;    // 0: video enabled; 1: video blanked

// set up our h/v sync counters
reg [9:0] hCount;
reg [8:0] vCount;
always @(negedge pixClk or negedge nReset) begin
    if(!nReset) begin
        hCount <= 0;
        vCount <= 0;
    end else begin
        if(hCount == H_TOTAL-1) begin
            hCount <= 0;
            if(vCount == V_TOTAL-1) begin
                vCount <= 0;
            end else begin
                vCount <= vCount + 9'h1;
            end
        end else begin
            hCount <= hCount + 10'h1;
        end
    end
end
// h sync pulse (neg)
always @(posedge pixClk or negedge nReset) begin
    if(!nReset) begin
        vidH <= 1;
    end else begin
        if(hCount >= (H_VIS+H_FRONT+2) && hCount < (H_VIS+H_FRONT+H_SYNC+2)) begin
            // hSync pulse is offset by 2 clocks to account for the offset
            // introduced through loading data from VRAM
            vidH <= 0;
        end else begin
            vidH <= 1;
        end
    end
end
// v sync pulse (pos)
always @(posedge pixClk or negedge nReset) begin
    if(!nReset) begin
        vidV <= 0;
    end else begin
        if(vCount >= (V_VIS+V_FRONT) && vCount < (V_VIS+V_FRONT+V_SYNC)) begin
            vidV <= 1;
        end else begin
            vidV <= 0;
        end
    end
end

// primary VRAM sequencer
// during active video, read one byte from VRAM every 4 clock cycles
// we'll use the lower two bits of hCount as a cycle counter
//      0: set up VRAM bus for video data read
//      1: latch video data from VRAM
// CPU requests can be serviced during cycles 1,2,3.
// CPU VRAM Read requests require 2 cycles, so they can only be serviced
// on cycles 1 & 2 during active video periods
// CPU VRAM Write requests and all CPU Register requests can be serviced
// in only 1 cycle, so they can be serviced on cycles 1,2,3 during active
// video periods, or any time during blanking periods 
reg [7:0] vReadData;    // store video data read from VRAM
reg cpuReadInProgress;  // keep track of when we're actively servicing a CPU read request
reg [15:0] vReadAddr;   // VRAM video address counter

// video address counter
always @(negedge pixClk or negedge nReset) begin
    if(!nReset) begin
        vReadAddr <= 0;
    end else begin
        // handle incrementing the VRAM read address
        if(hCount < H_VIS && vCount < V_VIS && hCount[1:0] == 2'h3) begin
            // increment address every video read cycle during active video
            vReadAddr <= vReadAddr + 16'h0001;
        end else if(hCount == H_VIS && !hCount[0]) begin
            // in modes 0 & 2, subtract 160 from video read address to repeat lines
            vReadAddr <= vReadAddr - 160;
        end else if(vCount >= V_VIS) begin
            // reset video read address during V Blanking period
            vReadAddr <= 0;
        end
    end
end

// video address pass-through
always @(negedge pixClk) begin
    // To keep things simple, the address output to VRAM will default to the 
    // address from the CPU except when fetching video from VRAM.
    // This is probably a bad idea, but it's easy.
    if(hCount < H_VIS && vCount < V_VIS && hCount[1:0] == 2'h0) begin
        vramAddr <= vReadAddr[14:0];
    end else begin
        vramAddr <= cpuAddr[14:0];
    end
end

// VRAM sequencer
always @(negedge pixClk or negedge nReset) begin
    if(!nReset) begin
        // System reset, deassert all CPU & VRAM bus signals
        cpuReadInProgress <= 0;
        nVramCE0 <= 1;
        nVramCE1 <= 1;
        nVramRd <= 1;
        nVramWr <= 1;
        vramData <= 8'bZZZZZZZZ;
        cpuData <= 8'bZZZZZZZZ;
        nCpuDSACK <= 1'bZ;
    end else begin
        
        // handle fetching video data from VRAM
        if(hCount < H_VIS && vCount < V_VIS && hCount[1:0] == 2'h0) begin
            // state 0 - set up VRAM bus for video data read
            // this is the beginning of an active video VRAM fetch.
            // deassert all CPU bus signals
            cpuData <= 8'bZZZZZZZZ;
            nCpuDSACK <= 1'bZ;
            // assert VRAM read strobe
            nVramRd <= 0;
            // set VRAM data bus to high-Z for reading
            vramData <= 8'bZZZZZZZZ;
            // assert VRAM address and chip enable signals
            if(rVidMode[0]) begin
                // only one frame buffer if rVidMode[0] is set
                // no line doubling if rVidMode[0] is set
                if(vReadAddr[15]) begin
                    nVramCE0 <= 1;
                    nVramCE1 <= 0;
                end else begin
                    nVramCE0 <= 0;
                    nVramCE1 <= 1;
                end
            end else begin
                // two frame buffers if rVidMode[0] is clear
                // select active frame buffer with rBufSel
                // read & display each line twice if rVidMode[0] is clear
                if(rBufSel) begin
                    nVramCE0 <= 1;
                    nVramCE1 <= 0;
                end else begin
                    nVramCE0 <= 0;
                    nVramCE1 <= 1;
                end
            end
        end else if (hCount < H_VIS && vCount < V_VIS && hCount[1:0] == 2'h1) begin
            // state 1 - latch data from VRAM
            // this is the end of an active video VRAM fetch.
            vReadData <= vramData;
            // we won't actually do anything else here, because all other cases
            // will be covered by the CPU request logic below
        end

        // service CPU requests during blanking periods or on off cycles during active video
        if(hCount >= H_VIS || vCount >= V_VIS || hCount[1:0] != 2'h0) begin
            // first check if we have a CPU VRAM Read cycle in progress already
            if(cpuReadInProgress == 1) begin
                // we already have a CPU VRAM read cycle in progress, finish it.
                cpuData <= vramData;
                nCpuDSACK <= 1'b0;
                // we're done with VRAM, so deassert its signals
                nVramCE0 <= 1;
                nVramCE1 <= 1;
                nVramRd <= 1;
                nVramWr <= 1;
                vramData <= 8'bZZZZZZZZ;
                // and don't forget to end the cpu read cycle
                cpuReadInProgress <= 0;
            end else if(!nCpuCE && !nCpuDS) begin
                // cpu is requesting service
                if(cpuAddr == 16'hFFFF) begin
                    // cpu register cycle, handle immediately
                    cpuReadInProgress <= 0;
                    // VRAM not needed, so deassert its signals
                    nVramCE0 <= 1;
                    nVramCE1 <= 1;
                    nVramRd <= 1;
                    nVramWr <= 1;
                    vramData <= 8'bZZZZZZZZ;
                    if(!cpuRnW) begin
                        // CPU register write cycle
                        cpuData <= 8'bZZZZZZZZ;
                        rVidBlank <= cpuData[0];
                        rBufSel <= cpuData[1];
                        rVidMode <= cpuData[3:2];
                        // ignore all other CPU data bits
                    end else begin
                        // CPU register read cycle
                        cpuData[0] <= rVidBlank;
                        cpuData[1] <= rBufSel;
                        cpuData[3:2] <= rVidMode;
                        // check if we're in active video or blanking period
                        if(hCount < H_VIS) begin
                            // we're in Horizontal Active period
                            cpuData[4] <= 1'b0;
                        end else begin
                            // we're in Horizontal Blanking period
                            cpuData[4] <= 1'b1;
                        end
                        if(vCount < V_VIS) begin
                            // we're in Vertical Active period
                            cpuData[5] <= 1'b0;
                        end else begin
                            // we're in Vertical Blanking period
                            cpuData[5] <= 1'b1;
                        end
                        // set remaining cpu data bits high
                        cpuData[7:6] <= 2'b11;
                    end
                    // and finally, let the CPU know we're done with this cycle
                    nCpuDSACK <= 1'b0;
                end else begin
                    // cpu VRAM cycle
                    if(!cpuRnW) begin
                        // cpu VRAM write cycle, handle immediatly
                        cpuReadInProgress <= 0;
                        // tell VRAM we're writing
                        nVramWr <= 0;
                        nVramRd <= 1;
                        // activate the appropriate VRAM chip
                        if(cpuAddr[15]) begin
                            nVramCE0 <= 1;
                            nVramCE1 <= 0;
                        end else begin
                            nVramCE0 <= 0;
                            nVramCE1 <= 1;
                        end
                        // feed the CPU data & address to VRAM
                        cpuData <= 8'bZZZZZZZZ;
                        vramData <= cpuData;
                        // and finally, let the CPU know we're done with this cycle
                        nCpuDSACK <= 1'b0;
                    end else begin
                        // cpu VRAM read cycle, check if we have time
                        //if(hCount == 2'h1 || hCount == 2'h2) begin
                        if((hCount < H_VIS && vCount < V_VIS && (hCount[1:0] == 2'h1 || hCount[1:0] == 2'h2)) 
                            || (hCount < H_TOTAL-2) ) begin
                            // we have time, start the CPU VRAM read cycle
                            cpuReadInProgress <= 1;
                            // tell VRAM we're reading
                            nVramWr <= 1;
                            nVramRd <= 0;
                            // activate the appropriate VRAM chip
                            if(cpuAddr[15]) begin
                                nVramCE0 <= 1;
                                nVramCE1 <= 0;
                            end else begin
                                nVramCE0 <= 0;
                                nVramCE1 <= 1;
                            end
                            // feed the CPU address to VRAM
                            vramData <= 8'bZZZZZZZZ;
                            cpuData <= 8'bZZZZZZZZ;
                            // and finally, let the CPU know we're not done yet
                            nCpuDSACK <= 1'bZ;
                        end else begin
                            // we don't have time for a read cycle, wait until we have time
                            cpuReadInProgress <= 0;
                            // deassert all VRAM & CPU bus signals
                            nVramCE0 <= 1;
                            nVramCE1 <= 1;
                            nVramRd <= 1;
                            nVramWr <= 1;
                            vramData <= 8'bZZZZZZZZ;
                            cpuData <= 8'bZZZZZZZZ;
                            nCpuDSACK <= 1'bZ;
                        end
                    end
                end
            end else begin
                // no cpu cycle requested. deassert all VRAM & CPU bus signals
                nVramCE0 <= 1;
                nVramCE1 <= 1;
                nVramRd <= 1;
                nVramWr <= 1;
                vramData <= 8'bZZZZZZZZ;
                cpuData <= 8'bZZZZZZZZ;
                nCpuDSACK <= 1'bZ;
            end
        end
    end
end


// this is where we'll actually output the video data we've fetched from VRAM
always @(posedge pixClk or negedge nReset) begin
    if(!nReset) begin
        vidOut <= 4'h0;
    end else if(hCount < 2 && vCount < V_VIS) begin
        // this is an edge case at the beginning of each line where we are
        // still fetching data from VRAM, but we're not ready to output it yet
        vidOut <= 4'h0;
    end else if(hCount < (H_VIS+2) && vCount < V_VIS) begin
        // this is the normal video period, which extends 2 clocks past the
        // H_VIS counter to account for VRAM data fetch.
        // what we actually output depends on what video mode we're using.
        if(rVidBlank) begin
            vidOut <= 4'h0;
        end else begin
            if(rVidMode[1]) begin
                // modes 2 & 3 are 2bpp grayscale with no column doubling
                // there's probably a cleaner way to do this but it should work
                case(hCount[1:0])
                    2'h2 : begin
                        // output bits [7:6]
                        vidOut[3] <= vReadData[7];
                        vidOut[2] <= vReadData[7];
                        vidOut[1] <= vReadData[7];
                        vidOut[0] <= vReadData[6];
                    end
                    2'h3 : begin
                        // output bits [5:4]
                        vidOut[3] <= vReadData[5];
                        vidOut[2] <= vReadData[5];
                        vidOut[1] <= vReadData[5];
                        vidOut[0] <= vReadData[4];
                    end
                    2'h0 : begin
                        // output bits [3:2]
                        vidOut[3] <= vReadData[3];
                        vidOut[2] <= vReadData[3];
                        vidOut[1] <= vReadData[3];
                        vidOut[0] <= vReadData[2];
                    end
                    2'h1 : begin
                        // output bits [1:0]
                        vidOut[3] <= vReadData[1];
                        vidOut[2] <= vReadData[1];
                        vidOut[1] <= vReadData[1];
                        vidOut[0] <= vReadData[0];
                    end
                endcase
            end else begin
                // modes 1 & 0 are 4bpp RGBI with column doubling
                if(hCount[1]) begin
                    // output bits [7:4]
                    vidOut <= vReadData[7:4];
                end else begin
                    // output bits [3:0]
                    vidOut <= vReadData[3:0];
                end
            end
        end
    end else begin
        // this is blanking period
        vidOut <= 4'h0;
    end
end


endmodule