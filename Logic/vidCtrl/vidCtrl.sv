module vidCtrl (
    input   wire                nReset,     // primary system reset         1
    input   wire                pixClk,     // primary video pixel clock    83
    input   wire                nCpuCE,     // cpu bus chip enable signal   84
    output  reg                 nVramWr,    // vram bus write strobe        12
    output  reg  [14:0]         vramAddr,   // vram bus address signals
    input   wire                nCpuDS,     // cpu bus data strobe          6
    output  reg                 nCpuDSACK,  // cpu data strobe acknowledge  5
    output  reg                 nVramRd,    // vram bus read strobe         22
    inout   wire [7:0]          vramData,   // vram bus data signals
    output  reg                 nVramCE0,   // vram bus chip 0 enable       29
    output  reg                 nVramCE1,   // vram bus chip 1 enable       44
    input   wire                cpuRnW,     // cpu bus read/write signal    41
    output  reg  [3:0]          vidOut,     // video RGBI output            45,49,51,46
    output  reg                 vidV,       // video VSync output           48
    output  reg                 vidH,       // video HSync output           50
    inout   wire [7:0]          cpuData,    // cpu bus data signals
    input   wire [15:0]         cpuAddr     // cpu bus address signals
);

// outputting 640x480@60Hz frame from 25.175MHx pixel clock
// displaying 256x240 video at 4bpp
parameter H_TOTAL   =   800;
parameter H_VIS     =   512;
parameter H_BLACK0  =    64;
parameter H_FRONT   =    16;
parameter H_SYNC    =    96;
parameter H_BACK    =    46;
parameter H_BLACK1  =    64;

parameter V_TOTAL   =   525;
parameter V_VIS     =   480;
parameter V_FRONT   =    10;
parameter V_SYNC    =     2;
parameter V_BACK    =    33;

// set up H/V sync counters
reg [9:0] hCount;
reg [9:0] vCount;
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
                vCount <= vCount + 10'h1;
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
        if(hCount >= (H_VIS+H_BLACK0+H_FRONT+2) 
            && hCount < (H_VIS+H_BLACK0+H_FRONT+H_SYNC+2)) begin
                vidH <= 0;
        end else begin
            vidH <= 1;
        end
    end
end
// v sync pulse (neg)
always @(posedge pixClk or negedge nReset) begin
    if(!nReset) begin
        vidV <= 1;
    end else begin
        if(vCount >= (V_VIS+V_FRONT) && vCount < (V_VIS+V_FRONT+V_SYNC)) begin
            vidV <= 0;
        end else begin
            vidV <= 1;
        end
    end
end

wire vidActive, cpuTime;
assign vidActive = (hCount < H_VIS) & (vCount < V_VIS);
assign cpuTime = ((vidActive && hCount[1]) || !vidActive);

// VRAM address bus
always @(posedge pixClk) begin
    if(vidActive && hCount[1:0] == 0) begin
        // time for a video data fetch
        vramAddr[14:7] = vCount[8:1];
        vramAddr[6:0] = hCount[8:2];
    end else if(cpuTime && cpuRequest) begin
        // we have space here for a CPU cycle if needed
        vramAddr = cpuAddr[14:0];
    end else begin
        // nothing needs the VRAM bus, so we don't care what the VRAM address is
        vramAddr = vramAddr;
    end
end

// VRAM data bus
always @(posedge pixClk) begin
    if(cpuTime && cpuState == cWR1) begin
        vramData <= cpuDataReg;
    end else begin
        vramData <= 8'bZZZZZZZZ;
    end
end

// VRAM chip enable signals
always @(posedge pixClk, negedge nReset) begin
    if(!nReset) begin
        nVramCE0 <= 1;
        nVramCE1 <= 1;
    end else begin
        if(vidActive && hCount[1:0] == 0) begin
            nVramCE0 <= vidBufSel;
            nVramCE1 <= ~vidBufSel;
        end else if(cpuTime && cpuRequest) begin
            nVramCE0 <= cpuAddr[15];
            nVramCE1 <= ~cpuAddr[15];
        end else begin
            nVramCE0 <= 1;
            nVramCE1 <= 1;
        end
    end
end

// VRAM read strobe
always @(posedge pixClk, negedge nReset) begin
    if(!nReset) begin
        nVramRd <= 1;
    end else begin
        if(vidActive && hCount[1:0] == 0) begin
            nVramRd <= 0;
        end else if(cpuTime && cpuState == cRD0) begin
            nVramRd <= 0;
        end else begin
            nVramRd <= 1;
        end
    end
end

// VRAM write strobe
always @(posedge pixClk, negedge nReset) begin
    if(!nReset) begin
        nVramWr <= 1;
    end else begin
        if(cpuTime && cpuState == cWR1) begin
            nVramWr <= 0;
        end else begin
            nVramWr <= 1;
        end
    end
end

// video data latch
reg [7:0] vidDataReg;
always @(posedge pixClk, negedge nReset) begin
    if(!nReset) begin
        vidDataReg <= 0;
    end else begin
        if(vidActive && hCount[1:0] == 1) begin
            vidDataReg <= vramData;
        end
    end
end

// video output
always @(negedge pixClk, negedge nReset) begin
    if(!nReset) begin
        vidOut <= 0;
    end else begin
        if(vidActive && (hCount[1] ^ hCount[0])) begin
            vidOut <= vidDataReg[7:4];
        end else if(vidActive && ~(hCount[1] ^ hCount[0])) begin
            vidOut <= vidDataReg[3:0];
        end else begin
            vidOut <= 0;
        end
    end
end

// CPU cycle service


wire cpuRequest, cpuAck;
assign cpuRequest = (cpuState == cWR1 || cpuState == cRD0);
assign cpuAck = cpuRequest & cpuTime;

// CPU cycle state machine
parameter
    cIDL    =   0,
    cWR0    =   1,
    cWR1    =   2,
    cRD0    =   3,
    cRD1    =   4,
    cRGW    =   5,  // register write
    cRGR    =   6;  // register read
reg [2:0] cpuState;
wire [2:0] cpuNextState;

always @(posedge pixClk, negedge nReset) begin
    if(!nReset) begin
        cpuState <= cIDL;
    end else begin
        cpuState <= cpuNextState;
    end
end

always_comb begin
    cpuNextState = cpuState;
    case(cpuState)
        cIDL: begin
            // idle, wait for CPU bus cycle to begin
            if(!nCpuCE & cpuRnW) begin
                // cpu read cycle
                if(cpuAddr == 16'hFFFF) begin
                    cpuNextState = cRGR;
                end else begin
                    cpuNextState = cRD0;
                end
            end else if(!nCpuCE & !cpuRnW) begin
                // cpu write cycle
                if(cpuAddr == 16'hFFFF) begin
                    cpuNextState = cRGW;
                end else begin
                    cpuNextState = cWR0;
                end
            end else begin
                // still idle
                cpuNextState = cpuState;
            end
        end
        cWR0: begin
            // cpu requesting a write cycle. latch data & move on
            if(nCpuDS) begin
                // wait here until write data is valid
                cpuNextState = cpuState;
            end else begin
                cpuNextState = cWR1;
            end
        end
        cWR1: begin
            // waiting for VRAM to complete write cycle
            if(cpuAck) cpuNextState = cIDL;
            else cpuNextState = cpuState;
        end
        cRD0: begin
            // cpu requesting a read cycle, wait for VRAM to complete read cycle
            if(cpuAck) cpuNextState = cRD1;
            else cpuNextState = cpuState;
        end
        cRD1: begin
            // wait for CPU to complete read cycle
            if(nCpuCE) begin
                // cycle complete
                cpuNextState = cIDL;
            end else begin
                cpuNextState = cpuState;
            end
        end
        cRGW, cRGR: begin
            // CPU register cycle
            if(nCpuCE) begin
                cpuNextState = cIDL;
            end else begin
                cpuNextState = cpuState;
            end
        end
        default: begin
            cpuNextState = cIDL;
        end
    endcase
end

// cpu data bus
always @(posedge pixClk, negedge nReset) begin
    if(!nReset) begin
        cpuData <= 8'bZZZZZZZZ;
    end else begin
        if(cpuNextState == cRD1) begin
            cpuData <= cpuDataReg;
        end else if(cpuNextState == cRGR) begin
            cpuData[0] <= vidBufSel;            // video buffer select register
            cpuData[1] <= vidH;                 // Hoz Sync status
            cpuData[2] <= vidV;                 // Vert Sync status
            cpuData[3] <= hCount >= H_VIS;      // Hoz blanking
            cpuData[4] <= vCount >= V_VIS;      // Vert blanking
            cpuData[7:5] <= 0;
        end else begin
            cpuData <= 8'bZZZZZZZZ;
        end
    end
end

// cpu ack
always @(posedge pixClk, negedge nReset) begin
    if(!nReset) begin
        nCpuDSACK <= 1;
    end else begin
        if(cpuNextState == cRD1 || cpuNextState == cWR1) begin
            nCpuDSACK <= 0;
        end else begin
            nCpuDSACK <= 1;
        end
    end
end

// video buffer select register -- changes take effect during vblank only
reg vidBufSel, vidBufSelNext;
always @(negedge pixClk, negedge nReset) begin
    if(!nReset) begin
        vidBufSelNext <= 0;
    end else begin
        if(cpuState == cRGW) begin
            vidBufSelNext <= cpuData[0];
        end
    end
end
always @(posedge pixClk, negedge nReset) begin
    if(!nReset) begin
        vidBufSel <= 0;
    end else begin
        if(vCount > V_VIS) begin
            vidBufSel <= vidBufSelNext;
        end else begin
            vidBufSel <= vidBufSel;
        end
    end
end


// cpu data register
reg [7:0] cpuDataReg;
always @(posedge pixClk, negedge nReset) begin
    if(!nReset) begin
        cpuDataReg <= 0;
    end else begin
        if(cpuNextState == cWR1) begin
            cpuDataReg <= cpuData;
        end else if(cpuNextState == cRD1) begin
            cpuDataReg <= vramData;
        end
    end
end

endmodule