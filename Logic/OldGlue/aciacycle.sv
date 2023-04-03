/******************************************************************************
 * ACIA Cycle
 * techav
 * 2021-05-31
 ******************************************************************************
 * Timing and control signals for 6850 ACIA (UART)
 *****************************************************************************/

module aciacycle (
    input   wire                sysClk,     // primary system clock
    input   wire                nReset,      // primary system reset
    input   wire                nAS,        // address strobe
    input   wire                addr31,     // address bit 31
    input   logic [2:0]         addrSel,    // address select bits (21:19)
    output  logic [1:0]         nDsack,     // DS acknowledge
    output  wire                aciaClk,    // ACIA ~1MHz Clock
    output  wire                nAciaCE     // ACIA chip enable signal
);

// ACIA clock divider
// Divides the incoming 25MHz system clock down to roughly 1MHz
logic [4:0] clockDiv;
reg aciaClkInternal;
always @(posedge sysClk) begin
    if(clockDiv >= 24) begin
        clockDiv <= 0;
        aciaClkInternal <= 0;
    end else if(clockDiv == 12) begin
        clockDiv <= clockDiv + 5'h1;
        aciaClkInternal <= 1;
    end else begin
        clockDiv <= clockDiv + 5'h1;
        aciaClkInternal <= aciaClkInternal;
    end
end

assign aciaClk = aciaClkInternal;

// define state machine states
parameter
    S0  =   0,  // Idle state
    S1  =   1,  // Active state
    S2  =   2,  // Wait 1 state
    S3  =   3,  // Wait 2 state
    S4  =   4,  // Term state
    S5  =   5;  // End state
logic [2:0] timingState;

wire nDsackInternal, nAciaCeInternal;
always @(posedge sysClk or posedge nAS) begin
    if(nAS) begin
        timingState <= S0;
        nDsackInternal <= 1;
        nAciaCeInternal <= 1;
    end else begin
        case (timingState)
            S0 : begin
                // Idle state
                // wait for CPU to assert AS & addrSel=1
                if(!nAS && !addr31 && addrSel == 7) timingState <= S2;
                else timingState <= S0;
                nDsackInternal <= 1;
                nAciaCeInternal <= 1;
            end
            /* this state is unnecessary
            S1 : begin
                // Align to acia clock
                if(clockDiv == 0) timingState <= S2;
                else timingState <= S1;
                nDsackInternal <= 1;
                nAciaCeInternal <= 1;
            end*/
            S2 : begin
                // Wait to assert CE
                if(clockDiv == 8) timingState <= S3;
                else timingState <= S2;
                nDsackInternal <= 1;
                nAciaCeInternal <= 1;
            end
            S3 : begin
                // Chip Enable
                // Wait for end of cycle
                if(clockDiv == 24) timingState <= S4;
                else timingState <= S3;
                nDsackInternal <= 1;
                nAciaCeInternal <= 0;
            end
            S4 : begin
                // Cycle Term
                timingState <= S5;
                nDsackInternal <= 0;
                nAciaCeInternal <= 0;
            end
            S5 : begin
                // End cycle
                if(nAS) timingState <= S0;
                else timingState <= S5;
                nDsackInternal <= 0;
                nAciaCeInternal <= 1;
            end
            default : begin
                //
                timingState <= S0;
                nDsackInternal <= nDsackInternal;
                nAciaCeInternal <= nAciaCeInternal;
            end
        endcase
    end
end

assign nAciaCE = nAciaCeInternal;
assign nDsack[0] = nDsackInternal;
assign nDsack[1] = 1;

endmodule