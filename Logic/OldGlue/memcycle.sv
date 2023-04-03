/******************************************************************************
 * Memory Cycle
 * techav
 * 2021-12-25
 ******************************************************************************
 * Timing and control signals for memory devices (ROM/RAM)
 *****************************************************************************/

module memcycle (
    input   wire                sysClk,     // primary system clock
    input   wire                nReset,     // primary system reset
    input   wire                nAS,        // address strobe
    input   wire                addr31,     // address bit 31
    input   wire                RnW,        // Read/Write select
    input   logic [2:0]         addrSel,    // address select bits (21:19)
    input   logic [1:0]         addrSiz,    // address size bits
    input   logic [1:0]         siz,        // transfer size bits
    output  wire                nRomCE,     // rom chip select
    output  logic [1:0]         nDsack,     // DS acknowledge
    output  wire                nSterm,     // synchronous termination
    output  wire                nMemRd,     // memory Read strobe
    output  wire                nMemWr,     // memory Write strobe
    output  logic [3:0]         nRamCE,     // ram chip select
    output  wire                nBerr       // CPU bus error signal
);

// define state machine states
/*parameter
    S0  =   0,  // Idle state
    S1  =   1,  // Sync Active state
    S2  =   2,  // Sync Term state
    S3  =   3,  // Async Active state
    S4  =   4,  // Async Wait 1 state
    S5  =   5,  // Async Wait 2 state
    S6  =   6,  // Async Term state
    S7  =   7,  // Berr state
    S8  =   8,  // Mode Switch state
    S9  =   9,  // Vid Active state
    S10 =  10,  // Vid Wait 1 state
    S11 =  11,  // Vid Wait 2 state
    S12 =  12,  // Vid Wait 3 state
    S13 =  13,  // Vid Term state
    S15 =  15;  // Cycle End state*/
parameter 
    sIDLE   =    0, // Idle state
    sSACTV  =    1, // Sync active state
    sSWAT1  =    2, // Sync wait 1 state
    sSTERM  =    3, // Sync term state
    sAACTV  =    4, // Async active state
    sAWAT1  =    5, // Async wait 1 state
    sAWAT2  =    6, // Async wait 2 state
    sAWAT3  =    7, // Async wait 3 state
    sAWAT4  =    8, // Async wait 4 state
    sATERM  =    9, // Async term state
    sVACTV  =   10, // Video active state
    sVWAT1  =   11, // Video wait 1 state
    sVWAT2  =   12, // Video wait 2 state
    sVWAT3  =   13, // Video wait 3 state
    sVTERM  =   14, // Video term state
    sBERR   =   15, // Bus error state
    sMODE   =   16, // Mode switch state
    sEND    =   17; // Cycle end state
logic [4:0] timingState;

reg nRamCEinternal,
    nRomCEinternal,
    nMemRDinternal,
    nMemWRinternal,
    nDSACKinternal,
    nDSACK16internal,
    nSTERMinternal,
    nBERRinternal,
    memOverlay;     // 0 on reset; 1 enables read RAM page 0

wire    ramSel,
        romSel,
        berrSel,
        vidSel,
        modeSel;

assign nRomCE = nRomCEinternal;
assign nMemRd = nMemRDinternal;
assign nMemWr = nMemWRinternal;
assign nSterm = nSTERMinternal;
assign nBerr = nBERRinternal;

//assign nDsack[1] = 1;
assign nDsack[1] = nDSACK16internal;
assign nDsack[0] = nDSACKinternal;

// RAM chip enable signals
always_comb begin
    if(!nRamCEinternal) begin
        nRamCE[3] = ~(RnW | (~addrSiz[0] & ~addrSiz[1]));
        nRamCE[2] = ~(
            (~siz[0] & ~addrSiz[1]) |
            (~addrSiz[1] & addrSiz[0]) |
            (siz[1] & ~addrSiz[1]) |
            RnW
        );
        nRamCE[1] = ~(
            (~addrSiz[0] & addrSiz[1]) |
            (~addrSiz[1] & ~siz[0] & ~siz[1]) |
            RnW |
            (~addrSiz[1] & siz[0] & siz[1]) |
            (addrSiz[0] & ~addrSiz[1] & ~siz[0])
        );
        nRamCE[0] = ~(
            (addrSiz[0] & siz[0] & siz[1]) |
            (~siz[0] & ~siz[1]) |
            RnW |
            (addrSiz[0] & addrSiz[1]) |
            (addrSiz[1] & siz[1])
        );
    end else begin
        nRamCE <= 4'hF;
    end
end

// CPU is driving an address that should map to RAM
always_comb begin
    if(!nAS && !addr31) begin
        if(addrSel == 0 && memOverlay == 0 && !RnW) begin
            // on reset, writes to page 0 go through to RAM
            ramSel <= 1;
        end else if(addrSel == 0 && memOverlay == 0 && RnW) begin
            // on reset, reads to page 0 go to ROM, not RAM
            ramSel <= 0;
        end else if(addrSel < 3) begin
            ramSel <= 1;
        end else begin
            ramSel <= 0;
        end
    end else begin
        ramSel <= 0;
    end
end

// CPU is driving an address that should map to ROM
always_comb begin
    if(!nAS && !addr31) begin
        if(addrSel == 0 && memOverlay == 0 && RnW) begin
            // on reset, reads to page 0 go to ROM
            romSel <= 1;
        end else if(addrSel == 4) begin
            // normal ROM access address range
            romSel <= 1;
        end else begin
            romSel <= 0;
        end
    end else begin
        romSel <= 0;
    end
end

// CPU is driving an address that maps to a 16-bit video port
/*always_comb begin
    if(!nAS && !addr31 && addrSel == 5) begin
        vidSel <= 1;
    end else begin
        vidSel <= 0;
    end
end*/
// CPU is driving an address that maps to the video port (RAM page 3)
always_comb begin
    if(!nAS && !addr31 && addrSel == 3) begin
        vidSel <= 1;
    end else begin
        vidSel <= 0;
    end
end

// CPU is driving an address that doesn't map to anything
always_comb begin
    if(!nAS && !addr31) begin
        if(addrSel == 5) begin
            // there is nothing mapped here
            berrSel <= 1;
        end else
        if (addrSel == 6 && RnW) begin
            // no reads are allowed on page 6
            berrSel <= 1;
        end else begin
            berrSel <= 0;
        end
    end else begin
        berrSel <= 0;
    end
end

// CPU is driving an address for toggling memory overlay
//assign modeSel = ~nAS & ~addr31 & ((addrSel == 6) & ~RnW);
always_comb begin
    if(!nAS && !addr31 && addrSel == 6 && !RnW) begin
        // writes to page 6 toggle the reset overlay
        modeSel <= 1;
    end else begin
        modeSel <= 0;
    end
end

// Primary timing state machine
always @(posedge sysClk or posedge nAS or negedge nReset) begin
    if(!nReset) begin
        memOverlay <= 0;            // 0 on reset, 1 enables read RAM page 0
    end else if(nAS) begin
        timingState <= sIDLE;
        nRamCEinternal <= 1;
        nRomCEinternal <= 1;
        nMemRDinternal <= 1;
        nMemWRinternal <= 1;
        nDSACKinternal <= 1;
        nSTERMinternal <= 1;
        nBERRinternal <= 1;
    end else begin
        case(timingState)
            sIDLE : begin
                // Idle state.
                // Wait for memory cycle to begin
                if(ramSel) timingState <= sSACTV;
                else if(romSel) timingState <= sAACTV;
                else if(berrSel) timingState <= sBERR;
                else if(modeSel) timingState <= sMODE;
                else if(vidSel) timingState <= sVACTV;
                else timingState <= sIDLE;
                nRamCEinternal <= 1;
                nRomCEinternal <= 1;
                nMemRDinternal <= 1;
                nMemWRinternal <= 1;
                nDSACKinternal <= 1;
                nDSACK16internal <= 1;
                nSTERMinternal <= 1;
                nBERRinternal <= 1;
            end
            sSACTV: begin
                // Sync Active state
                // Always move to sWAT1
                timingState <= sSWAT1;
                nRamCEinternal <= 0;
                nRomCEinternal <= 1;
                nMemRDinternal <= ~RnW;
                nMemWRinternal <= RnW;
                nDSACKinternal <= 1;
                nDSACK16internal <= 1;
                nSTERMinternal <= 1;
                nBERRinternal <= 1;
            end
            sSWAT1: begin
                // Sync Wait 1 state
                // Always move to sSTERM
                timingState <= sSTERM;
                nRamCEinternal <= 0;
                nRomCEinternal <= 1;
                nMemRDinternal <= nMemRDinternal;
                nMemWRinternal <= nMemWRinternal;
                nDSACKinternal <= 1;
                nDSACK16internal <= 1;
                nSTERMinternal <= 1;
                nBERRinternal <= 1;
            end
            sSTERM: begin
                // Sync Term state
                // Always move to sEND
                timingState <= sEND;
                nRamCEinternal <= 0;
                nRomCEinternal <= 1;
                nMemRDinternal <= nMemRDinternal;
                nMemWRinternal <= nMemWRinternal;
                nDSACKinternal <= 1;
                nDSACK16internal <= 1;
                nSTERMinternal <= 0;
                nBERRinternal <= 1;
            end
            sAACTV: begin
                // Async Active state
                // Always move to sAWAIT1
                timingState <= sAWAT1;
                nRamCEinternal <= 1;
                nRomCEinternal <= 0;
                nMemRDinternal <= ~RnW;
                nMemWRinternal <= RnW;
                nDSACKinternal <= 1;
                nDSACK16internal <= 1;
                nSTERMinternal <= 1;
                nBERRinternal <= 1;
            end
            sAWAT1: begin
                // Async wait 1 state
                // Always move to sAWAT2
                timingState <= sAWAT2;
                nRamCEinternal <= 1;
                nRomCEinternal <= 0;
                nMemRDinternal <= nMemRDinternal;
                nMemWRinternal <= nMemWRinternal;
                nDSACKinternal <= 1;
                nDSACK16internal <= 1;
                nSTERMinternal <= 1;
                nBERRinternal <= 1;
            end
            sAWAT2: begin
                // Async wait 2 state
                // Always move to sAWAT3
                timingState <= sAWAT3;
                nRamCEinternal <= 1;
                nRomCEinternal <= 0;
                nMemRDinternal <= nMemRDinternal;
                nMemWRinternal <= nMemWRinternal;
                nDSACKinternal <= 1;
                nDSACK16internal <= 1;
                nSTERMinternal <= 1;
                nBERRinternal <= 1;
            end
            sAWAT3: begin
                // Async wait 3 state
                // Always move to sAWAT4
                timingState <= sAWAT4;
                nRamCEinternal <= 1;
                nRomCEinternal <= 0;
                nMemRDinternal <= nMemRDinternal;
                nMemWRinternal <= nMemWRinternal;
                nDSACKinternal <= 1;
                nDSACK16internal <= 1;
                nSTERMinternal <= 1;
                nBERRinternal <= 1;
            end
            sAWAT4: begin
                // Async wait 4 state
                // Always move to sATERM
                timingState <= sATERM;
                nRamCEinternal <= 1;
                nRomCEinternal <= 0;
                nMemRDinternal <= nMemRDinternal;
                nMemWRinternal <= nMemWRinternal;
                nDSACKinternal <= 1;
                nDSACK16internal <= 1;
                nSTERMinternal <= 1;
                nBERRinternal <= 1;
            end
            sATERM: begin
                // Async Term state
                // Always move to sEND
                timingState <= sEND;
                nRamCEinternal <= 1;
                nRomCEinternal <= 0;
                nMemRDinternal <= nMemRDinternal;
                nMemWRinternal <= nMemWRinternal;
                nDSACKinternal <= 0;
                nDSACK16internal <= 1;
                nSTERMinternal <= 1;
                nBERRinternal <= 1;
            end
            sVACTV: begin
                // Video Active state
                // Always move to sVWAT1
                timingState <= sVWAT1;
                nRamCEinternal <= 0;
                nRomCEinternal <= 1;
                nMemRDinternal <= ~RnW;
                nMemWRinternal <= RnW;
                nDSACKinternal <= 1;
                nDSACK16internal <= 1;
                nSTERMinternal <= 1;
                nBERRinternal <= 1;
            end
            sVWAT1: begin
                // Video Wait 1 state
                // Always move to sVWAT2
                timingState <= sVWAT2;
                nRamCEinternal <= 0;
                nRomCEinternal <= 1;
                nMemRDinternal <= nMemRDinternal;
                nMemWRinternal <= nMemWRinternal;
                nDSACKinternal <= 1;
                nDSACK16internal <= 1;
                nSTERMinternal <= 1;
                nBERRinternal <= 1;
            end
            sVWAT2: begin
                // Video Wait 2 state
                // Always move to sVWAT3
                timingState <= sVWAT3;
                nRamCEinternal <= 0;
                nRomCEinternal <= 1;
                nMemRDinternal <= nMemRDinternal;
                nMemWRinternal <= nMemWRinternal;
                nDSACKinternal <= 1;
                nDSACK16internal <= 1;
                nSTERMinternal <= 1;
                nBERRinternal <= 1;
            end
            sVWAT3: begin
                // Video Wait 3 state
                // Always move to sVTERM
                timingState <= sVTERM;
                nRamCEinternal <= 0;
                nRomCEinternal <= 1;
                nMemRDinternal <= nMemRDinternal;
                nMemWRinternal <= nMemWRinternal;
                nDSACKinternal <= 1;
                nDSACK16internal <= 1;
                nSTERMinternal <= 1;
                nBERRinternal <= 1;
            end
            sVTERM: begin
                // Video Term state
                // Always move to sEND
                timingState <= sEND;
                timingState <= sEND;
                nRamCEinternal <= 0;
                nRomCEinternal <= 1;
                nMemRDinternal <= nMemRDinternal;
                nMemWRinternal <= nMemWRinternal;
                nDSACKinternal <= 1;
                nDSACK16internal <= 1;
                nSTERMinternal <= 0;
                nBERRinternal <= 1;
            end
            sBERR : begin
                // Bus Error state
                // Always move to sEND
                timingState <= sEND;
                nRamCEinternal <= 1;
                nRomCEinternal <= 1;
                nMemRDinternal <= 1;
                nMemWRinternal <= 1;
                nDSACKinternal <= 1;
                nDSACK16internal <= 1;
                nSTERMinternal <= 1;
                nBERRinternal <= 0;
            end
            sMODE : begin
                // Mode Switch state
                // Always move to sEND
                timingState <= sEND;
                nRamCEinternal <= 1;
                nRomCEinternal <= 1;
                nMemRDinternal <= 1;
                nMemWRinternal <= 1;
                nDSACKinternal <= 1;
                nDSACK16internal <= 1;
                nSTERMinternal <= 0;
                nBERRinternal <= 1;
                memOverlay <= ~memOverlay;
            end
            sEND  : begin
                // Cycle End state
                // Wait for CPU to deassert nAS
                if(nAS) timingState <= sIDLE;
                else timingState <= sEND;
                // hold all signals at previous level except Memory Write
                nRamCEinternal <= nRamCEinternal;
                nRomCEinternal <= nRomCEinternal;
                nMemRDinternal <= nMemRDinternal;
                nMemWRinternal <= 1;    // force high early
                nDSACKinternal <= nDSACKinternal;
                nDSACK16internal <= nDSACK16internal;
                nSTERMinternal <= nSTERMinternal;
                nBERRinternal <= nBERRinternal;
            end
            default: begin
                // How did we end up here?
                timingState <= sIDLE;
                // hold all signals at previous level
                nRamCEinternal <= nRamCEinternal;
                nRomCEinternal <= nRomCEinternal;
                nMemRDinternal <= nMemRDinternal;
                nMemWRinternal <= nMemWRinternal;
                nDSACKinternal <= nDSACKinternal;
                nDSACK16internal <= nDSACK16internal;
                nSTERMinternal <= nSTERMinternal;
                nBERRinternal <= nBERRinternal;
            end
        endcase
    end
end


/*// primary timing state machine
always @(posedge sysClk or posedge nAS or negedge nReset) begin
    if(!nReset) begin
        memOverlay <= 0;            // 0 on reset; 1 enables read RAM page 0
    end else if(nAS) begin
        timingState <= S0;
        nRamCEinternal <= 1;
        nRomCEinternal <= 1;
        nMemRDinternal <= 1;
        nMemWRinternal <= 1;
        nDSACKinternal <= 1;
        nSTERMinternal <= 1;
        nBERRinternal <= 1;
        // memOverlay <= 0;         // 0 on reset; 1 enables read RAM page 0
    end else begin
        case(timingState)
            S0 : begin
                // Idle state.
                // Wait for memory cycle to begin
                if(ramSel) timingState <= S1;
                else if(romSel) timingState <= S3;
                else if(berrSel) timingState <= S7;
                else if(modeSel) timingState <= S8;
                else if(vidSel) timingState <= S9;
                else timingState <= S0;
                nRamCEinternal <= 1;
                nRomCEinternal <= 1;
                nMemRDinternal <= 1;
                nMemWRinternal <= 1;
                nDSACKinternal <= 1;
                nDSACK16internal <= 1;
                nSTERMinternal <= 1;
                nBERRinternal <= 1;
            end
            S1 : begin
                // Sync Active state
                // Always move to S2
                timingState <= S2;
                nRamCEinternal <= 0;
                nRomCEinternal <= 1;
                nMemRDinternal <= ~RnW;
                nMemWRinternal <= RnW;
                nDSACKinternal <= 1;
                nDSACK16internal <= 1;
                nSTERMinternal <= 1;
                nBERRinternal <= 1;
            end
            S2 : begin
                // Sync Term state
                // Always move to S15
                timingState <= S15;
                nRamCEinternal <= 0;
                nRomCEinternal <= 1;
                nMemRDinternal <= nMemRDinternal;
                nMemWRinternal <= nMemWRinternal;
                nDSACKinternal <= 1;
                nDSACK16internal <= 1;
                nSTERMinternal <= 0;
                nBERRinternal <= 1;
            end
            S3 : begin
                // Async Active state
                // always move to S4
                timingState <= S4;
                nRamCEinternal <= 1;
                nRomCEinternal <= 0;
                nMemRDinternal <= ~RnW;
                nMemWRinternal <= RnW;
                nDSACKinternal <= 1;
                nDSACK16internal <= 1;
                nSTERMinternal <= 1;
                nBERRinternal <= 1;
            end
            S4 : begin
                // Async Wait 1 state
                // always move to S5
                timingState <= S5;
                nRamCEinternal <= 1;
                nRomCEinternal <= 0;
                nMemRDinternal <= nMemRDinternal;
                nMemWRinternal <= nMemWRinternal;
                nDSACKinternal <= 1;
                nDSACK16internal <= 1;
                nSTERMinternal <= 1;
                nBERRinternal <= 1;
            end
            S5 : begin
                // Async Wait 2 state
                // always move to S6
                timingState <= S6;
                nRamCEinternal <= 1;
                nRomCEinternal <= 0;
                nMemRDinternal <= nMemRDinternal;
                nMemWRinternal <= nMemWRinternal;
                nDSACKinternal <= 1;
                nDSACK16internal <= 1;
                nSTERMinternal <= 1;
                nBERRinternal <= 1;
            end
            S6 : begin
                // Async Term state
                // Always move to S15
                timingState <= S15;
                nRamCEinternal <= 1;
                nRomCEinternal <= 0;
                nMemRDinternal <= nMemRDinternal;
                nMemWRinternal <= nMemWRinternal;
                nDSACKinternal <= 0;
                nDSACK16internal <= 1;
                nSTERMinternal <= 1;
                nBERRinternal <= 1;
            end
            S7 : begin
                // Bus Error state
                // Always move to S15
                timingState <= S15;
                nRamCEinternal <= 1;
                nRomCEinternal <= 1;
                nMemRDinternal <= 1;
                nMemWRinternal <= 1;
                nDSACKinternal <= 1;
                nDSACK16internal <= 1;
                nSTERMinternal <= 1;
                nBERRinternal <= 0;
            end
            S8 : begin
                // Mode Switch state
                // Always move to S15
                timingState <= S15;
                nRamCEinternal <= 1;
                nRomCEinternal <= 1;
                nMemRDinternal <= 1;
                nMemWRinternal <= 1;
                nDSACKinternal <= 1;
                nDSACK16internal <= 1;
                nSTERMinternal <= 0;
                nBERRinternal <= 1;
                memOverlay <= ~memOverlay;
            end
            S9 : begin
                // Vid Active state
                // Always move to S10
                timingState <= S10;
                nRamCEinternal <= 1;
                nRomCEinternal <= 1;
                nMemRDinternal <= 1;
                nMemWRinternal <= 1;
                nDSACKinternal <= 1;
                nDSACK16internal <= 1;
                nSTERMinternal <= 1;
                nBERRinternal <= 1;
            end
            S10: begin
                // Vid Wait 1 state
                // Always move to S11
                timingState <= S11;
                nRamCEinternal <= 1;
                nRomCEinternal <= 1;
                nMemRDinternal <= 1;
                nMemWRinternal <= 1;
                nDSACKinternal <= 1;
                nDSACK16internal <= 1;
                nSTERMinternal <= 1;
                nBERRinternal <= 1;
            end
            S11: begin
                // Vid Wait 2 state
                // Always move to S12
                timingState <= S12;
                nRamCEinternal <= 1;
                nRomCEinternal <= 1;
                nMemRDinternal <= 1;
                nMemWRinternal <= 1;
                nDSACKinternal <= 1;
                nDSACK16internal <= 1;
                nSTERMinternal <= 1;
                nBERRinternal <= 1;
            end
            S12: begin
                // Vid Wait 3 state
                // Always move to S13
                timingState <= S13;
                nRamCEinternal <= 1;
                nRomCEinternal <= 1;
                nMemRDinternal <= 1;
                nMemWRinternal <= 1;
                nDSACKinternal <= 1;
                nDSACK16internal <= 1;
                nSTERMinternal <= 1;
                nBERRinternal <= 1;
            end
            S13: begin
                // Vid Term state
                // Always move to S15
                timingState <= S15;
                nRamCEinternal <= 1;
                nRomCEinternal <= 1;
                nMemRDinternal <= 1;
                nMemWRinternal <= 1;
                nDSACKinternal <= 1;
                nDSACK16internal <= 0;
                nSTERMinternal <= 1;
                nBERRinternal <= 1;
            end
            S15: begin
                // Cycle End state
                // Wait for CPU to deassert nAS
                if(nAS) timingState <= S0;
                else timingState <= S15;
                // hold all signals at previous level except Memory Write
                nRamCEinternal <= nRamCEinternal;
                nRomCEinternal <= nRomCEinternal;
                nMemRDinternal <= nMemRDinternal;
                nMemWRinternal <= 1;    // force high early
                nDSACKinternal <= nDSACKinternal;
                nDSACK16internal <= nDSACK16internal;
                nSTERMinternal <= nSTERMinternal;
                nBERRinternal <= nBERRinternal;
            end
            default: begin
                // How did we end up here?
                timingState <= S0;
                // hold all signals at previous level
                nRamCEinternal <= nRamCEinternal;
                nRomCEinternal <= nRomCEinternal;
                nMemRDinternal <= nMemRDinternal;
                nMemWRinternal <= nMemWRinternal;
                nDSACKinternal <= nDSACKinternal;
                nDSACK16internal <= nDSACK16internal;
                nSTERMinternal <= nSTERMinternal;
                nBERRinternal <= nBERRinternal;
            end
        endcase
    end
end
*/
endmodule