/******************************************************************************
 * Wrap030 Video Generator Logic
 * techav
 * 2022-12-16
 ******************************************************************************
 * 2022-12-26 changed vram address calculation to an address counter to reduce
 *            macrocell utilization.
 * 2022-12-27 added logic to deassert nCpuDSACK when the CPU deasserts either
 *            nCpuDS or nCpuCE, to reduce the risk of interfering with the
 *            CPU's next bus transaction, as recommended in Section 7 of the
 *            68030 manual.
 * 2022-12-29 rework vram sequencer to improve efficiency because fitter fails
 *            after setting pin assignments to match schematic
 * 2022-12-31 fixed logic bugs in the vram address counter which prevented the
 *            entire frame from being drawn, and prevented modes 1 & 3 from 
 *            properly displaying the full vertical resolution.
 *            fixed logic bug preventing CPU accesses during blanking periods.
 *****************************************************************************/

module vidGen (
    input   wire                nReset,     // primary system reset         1
    input   wire                pixClk,     // primary video pixel clock    83
    input   wire                nCpuCE,     // cpu bus chip enable signal   84
    output  wire                nVramWr,    // vram bus write strobe        12
    output  wire [14:0]         vramAddr,   // vram bus address signals
    input   wire                nCpuDS,     // cpu bus data strobe          6
    inout   wire                nCpuDSACK,  // cpu data strobe acknowledge  5
    output  wire                nVramRd,    // vram bus read strobe         22
    inout   wire [7:0]          vramData,   // vram bus data signals
    output  wire                nVramCE0,   // vram bus chip 0 enable       29
    output  wire                nVramCE1,   // vram bus chip 1 enable       44
    input   wire                cpuRnW,     // cpu bus read/write signal    41
    output  wire [3:0]          vidOut,     // video RGBI output            45,49,51,46
    output  wire                vidV,       // video VSync output           48
    output  wire                vidH,       // video HSync output           50
    inout   wire [7:0]          cpuData,    // cpu bus data signals
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

wire vidActive;
assign vidActive = (hCount < H_VIS+2) & (hCount >= 2) & (vCount < V_VIS);

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
        end else if(hCount == H_VIS && !vCount[0] && !rVidMode[0]) begin
            // in modes 0 & 2, subtract 160 from video read address at the end
            // of odd lines to repeat that line
            vReadAddr <= vReadAddr - 16'd160;
        end else if(vCount >= V_VIS) begin
            // reset video read address during V Blanking period
            // if second video buffer is enabled in a mode that supports it,
            // the video read address will be reset to the second buffer
            //vReadAddr <= 0;
            if(rBufSel && !rVidMode[1]) begin
                vReadAddr <= 16'h8000;
            end else begin
                vReadAddr <= 16'h0000;
            end
        end
    end
end

// memory sequencer
parameter
    sIDL    =   0,  // Idle state
    sVRD    =   1,  // Video data read
    sCRD    =   2,  // CPU Read VRAM
    sCWR    =   3,  // CPU Write VRAM
    sRRD    =   4,  // CPU Read Registers
    sRWR    =   5,  // CPU Write Registers
    sCAK    =   6;  // CPU cycle acknowledge
reg [2:0] timingState;

always @(negedge pixClk or negedge nReset) begin
    if(!nReset) begin
        timingState <= sIDL;
    end else begin
        case(timingState)
            sIDL: begin
                // Idle state
                if(vidActive && hCount[1:0] == 2'h0) timingState <= sVRD;
                else if(!nCpuCE && !nCpuDS) begin
                    if(cpuAddr == 16'hFFFF) begin
                        if(cpuRnW) timingState <= sRRD;
                        else timingState <= sRWR;
                    end else if(hCount[1:0] < 2) begin
                        if(cpuRnW) timingState <= sCRD;
                        else timingState <= sCWR;
                    end else begin
                        timingState <= sIDL;
                    end
                end else timingState <= sIDL;
            end
            sVRD: begin
                // Video data read
                if(!nCpuCE && !nCpuDS) begin
                    if(cpuAddr == 16'hFFFF) begin
                        if(cpuRnW) timingState <= sRRD;
                        else timingState <= sRWR;
                    end else begin
                        if(cpuRnW) timingState <= sCRD;
                        else timingState <= sCWR;
                    end
                end else timingState <= sIDL;
            end
            sCRD: begin
                // CPU Read VRAM
                timingState <= sCAK;
            end
            sCWR: begin
                // CPU Write VRAM
                timingState <= sCAK;
            end
            sRRD: begin
                // CPU Read Registers
                if(vidActive && hCount[1:0] == 2'h0) timingState <= sVRD;
                else timingState <= sIDL;
            end
            sRWR: begin
                // CPU Write Registers
                if(vidActive && hCount[1:0] == 2'h0) timingState <= sVRD;
                else timingState <= sIDL;
            end
            sCAK: begin
                // CPU Cycle Acknowledge
                if(vidActive && hCount[1:0] == 2'h0) timingState <= sVRD;
                else timingState <= sIDL;
            end
            default: begin
                // how did we end up here?
                if(vidActive && hCount[1:0] == 2'h0) timingState <= sVRD;
                else timingState <= sIDL;
            end
        endcase
    end
end

wire cpuAck;
always @(timingState) begin
    case(timingState)
        sIDL: begin
            // Idle state
            nVramRd <= 1;
            nVramWr <= 1;
            cpuAck <= 0;
        end
        sVRD: begin
            // Video data read
            nVramRd <= 0;
            nVramWr <= 1;
            cpuAck <= 0;
        end
        sCRD: begin
            // CPU Read VRAM
            nVramRd <= 0;
            nVramWr <= 1;
            cpuAck <= 0;
        end
        sCWR: begin
            // CPU Write VRAM
            nVramRd <= 1;
            nVramWr <= 0;
            cpuAck <= 0;
        end
        sRRD: begin
            // CPU Read Registers
            nVramRd <= 1;
            nVramWr <= 1;
            cpuAck <= 1;
        end
        sRWR: begin
            // CPU Write Registers
            nVramRd <= 1;
            nVramWr <= 1;
            cpuAck <= 1;
        end
        sCAK: begin
            // CPU Cycle Acknowledge
            nVramRd <= 1;
            nVramWr <= 1;
            cpuAck <= 1;
        end
        default: begin
            // how did we end up here?
            nVramRd <= 1;
            nVramWr <= 1;
            cpuAck <= 0;
        end
    endcase
end

always_comb begin
    case(timingState)
        sVRD: begin
            if(vReadAddr[15]) begin
                nVramCE0 <= 1;
                nVramCE1 <= 0;
            end else begin
                nVramCE0 <= 0;
                nVramCE1 <= 1;
            end
        end
        sCRD, sCWR, sCAK: begin
            if(cpuAddr[15]) begin
                nVramCE0 <= 1;
                nVramCE1 <= 0;
            end else begin
                nVramCE0 <= 0;
                nVramCE1 <= 1;
            end
        end
        default: begin
            nVramCE0 <= 1;
            nVramCE1 <= 1;
        end
    endcase
end

// CPU DSACK should only be asserted for as long as the CPU continues to assert
// nCpuCE & nCpuDS
always_comb begin
    if(cpuAck && !nCpuCE && !nCpuDS) begin
        nCpuDSACK <= 0;
    end else begin
        nCpuDSACK <= 1'bZ;
    end
end

// CPU Data bus should only be asserted for as long as the CPU continues to 
// assert nCpuCE & nCpuDS
always_comb begin
    if((timingState == sCRD || (timingState == sCAK && cpuRnW))
            && !nCpuCE && !nCpuDS) begin
        cpuData <= vramData;
    end else if(timingState == sRRD && !nCpuCE && !nCpuDS) begin
        cpuData[0] <= rVidBlank;
        cpuData[1] <= rBufSel;
        cpuData[3:2] <= rVidMode;
        cpuData[4] <= ((hCount > 2) & (hCount < H_VIS+2) & (vCount < V_VIS));
        cpuData[5] <= (vCount < V_VIS);
        cpuData[7:6] <= 2'b11;
    end else begin
        cpuData <= 8'bZZZZZZZZ;
    end
end

// VRAM data bus should only be asserted during sCWR
always_comb begin
    if(timingState == sCWR) begin
        vramData <= cpuData;
    end else begin
        vramData <= 8'bZZZZZZZZ;
    end
end

// VRAM Address bus should default to vReadAddr except for sCRD, sCWR, sCAK
always_comb begin
    if(timingState == sCRD || timingState == sCWR || timingState == sCAK) begin
        vramAddr <= cpuAddr[14:0];
    end else begin
        vramAddr <= vReadAddr[14:0];
    end
end

// latch the new register data during CPU writes to address 0xFFFF
always @(negedge pixClk or negedge nReset) begin
    if(!nReset) begin
        rVidBlank <= 0;
        rBufSel <= 0;
        rVidMode <= 0;
    end else begin
        if(!nCpuCE && !nCpuDS && !cpuRnW && cpuAddr == 16'hFFFF) begin
            rVidBlank <= cpuData[0];
            rBufSel <= cpuData[1];
            rVidMode <= cpuData[3:2];
        end
    end
end

// latch the video data read from VRAM
always @(negedge pixClk or negedge nReset) begin
    if(!nReset) begin
        vReadData <= 0;
    end else if(timingState == sVRD) begin
        vReadData <= vramData;
    end
end

// this is where we'll actually output the video data we've fetched from VRAM
always @(posedge pixClk or negedge nReset) begin
    if(!nReset) begin
        vidOut <= 4'h0;
    end else if(hCount >= 2 && hCount < (H_VIS+2) && vCount < V_VIS && !rVidBlank) begin
        // this is the normal video period, which extends 2 clocks past the
        // H_VIS counter to account for VRAM data fetch.
        // what we actually output depends on what video mode we're using.
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
    end else begin
        // this is blanking period
        vidOut <= 4'h0;
    end
end


endmodule