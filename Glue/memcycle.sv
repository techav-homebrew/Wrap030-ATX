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
parameter
    S0  =   0,  // Idle state
    S1  =   1,  // Sync Active state
    S2  =   2,  // Sync Term state
    S3  =   3,  // Async Active state
    S4  =   4,  // Async Wait 1 state
    S5  =   5,  // Async Wait 2 state
    S6  =   6,  // Async Term state
    S7  =   7,  // Berr state
    S8  =   8,  // Mode Switch state
    S15 =  15;  // Cycle End state
logic [3:0] timingState;

reg nRamCEinternal,
    nRomCEinternal,
    nMemRDinternal,
    nMemWRinternal,
    nDSACKinternal,
    nSTERMinternal,
    nBERRinternal,
    memOverlay;     // 0 on reset; 1 enables read RAM page 0

wire    ramSel,
        romSel,
        berrSel,
        modeSel;

assign nRomCE = nRomCEinternal;
assign nMemRd = nMemRDinternal;
assign nMemWr = nMemWRinternal;
assign nSterm = nSTERMinternal;
assign nBerr = nBERRinternal;

assign nDsack[1] = 1;
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
        end else if(addrSel < 4) begin
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

// CPU is driving an address that doesn't map to anything
always_comb begin
    if(!nAS && !addr31) begin
        if(addrSel == 5) begin
            // there is nothing mapped here
            berrSel <= 1;
        end else if (addrSel == 6 && RnW) begin
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

// primary timing state machine
always @(posedge sysClk or posedge nAS) begin
    if(nAS) begin
        timingState <= S0;
        nRamCEinternal <= 1;
        nRomCEinternal <= 1;
        nMemRDinternal <= 1;
        nMemWRinternal <= 1;
        nDSACKinternal <= 1;
        nSTERMinternal <= 1;
        nBERRinternal <= 1;
        memOverlay <= 0;         // 0 on reset; 1 enables read RAM page 0
    end else begin
        case(timingState)
            S0 : begin
                // Idle state.
                // Wait for memory cycle to begin
                if(ramSel) timingState <= S1;
                else if(romSel) timingState <= S3;
                else if(berrSel) timingState <= S7;
                else if(modeSel) timingState <= S8;
                else timingState <= S0;
                nRamCEinternal <= 1;
                nRomCEinternal <= 1;
                nMemRDinternal <= 1;
                nMemWRinternal <= 1;
                nDSACKinternal <= 1;
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
                nSTERMinternal <= 0;
                nBERRinternal <= 1;
                memOverlay <= ~memOverlay;
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
                nSTERMinternal <= nSTERMinternal;
                nBERRinternal <= nBERRinternal;
            end
        endcase
    end
end

endmodule