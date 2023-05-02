/******************************************************************************
 * Wrap030 Bus Controller logic
 * techav
 * 2023-04-15
 ******************************************************************************
 * 2023-04-15 Initial build
 *****************************************************************************/

module busCtrl (
    // general system signals
    input   wire            sysClk,         // Primary system clock
    inout   wire            sysRESETn,      // Primary system reset signal
    input   wire            sysPWROK,       // System power on OK signal
    output  wire            sysPWRON,       // System ATX soft power on latch
    output  wire            sysMWRn,        // System memory write strobe
    output  wire            sysMRDn,        // System memory read strobe
    output  wire            sysLEDdebug,    // GPIO for software-controlled LED
    input   wire [1:0]      sysACKn,        // System generic cycle acknowledge
    // CPU control signals
    inout   wire [7:0]      cpuDataHiHi,    // CPU data bus D[31:24]
    input   wire [10:0]     cpuAddrHi,      // CPU addr bus A[31:21]
    input   wire [3:0]      cpuAddrMid,     // CPU addr bus A[19:16]
    input   wire [1:0]      cpuAddrLo,      // CPU addr bus A[1:0]
    input   wire [2:0]      cpuFC,          // CPU function code FC[2:0]
    input   wire            cpuDSn,         // CPU data strobe
    input   wire            cpuASn,         // CPU address strobe
    input   wire            cpuRWn,         // CPU read/write signal
    input   wire [1:0]      cpuSIZ,         // CPU size signals
    output  wire [1:0]      cpuDSACKn,      // CPU async cycle acknowledge signals
    input   wire            cpuSTERMn,      // CPU sync cycle acknowledge signals
    output  wire            cpuAVECn,       // CPU autovector signal
    output  wire            cpuBERRn,       // CPU bus error signal
    output  wire            cpuCIINn,       // CPU cache inhibit signal
    // FPU signals
    input   wire            fpuSENSEn,      // FPU presence detect signal
    output  reg             fpuCEn,         // FPU chip enable
    // General peripheral signals
    output  reg             romCEn,         // ROM chip enable
    output  reg             vidCEn,         // Video chip enable
    input   wire            vidACKn,        // Video cycle acknowledge
    output  wire            keyATNn,        // Keyboard chip enable
    input   wire            keyACKn,        // Keyboard cycle acknowledge
    output  reg             spioCEn,        // Serial/Parallel chip enable
    output  reg             isaCEn,         // ISA chip enable
    input   wire            isaACK8n,       // ISA 8-bit cycle acknowledge
    input   wire            isaACK16n,      // ISA 16-bit cycle acknoledge
    output  reg             ramCEn,         // RAM chip enable
    input   wire            ramACKn         // RAM cycle acknowledge
);

// bus controller settings register
reg [7:0] regSets;

// bus cycle timeout counter
reg [7:0] berrTimer;

// primary bus state machine
parameter
    sIDL    =    0, // Idle state
    sRM1    =    1, // ROM1 state
    sRM2    =    2, // ROM2 state
    sRM3    =    3, // ROM3 state
    sRM4    =    4, // ROM4 state
    sSP1    =    5, // SPIO1 state
    sSP2    =    6, // SPIO2 state
    sSP3    =    7, // SPIO3 state
    sSP4    =    8, // SPIO4 state
    sSP5    =    9, // SPIO5 state
    sSP6    =   10, // SPIO6 state
    sRRD    =   11, // Bus controller register read state
    sRWR    =   12, // Bus controller register write state
    sEXT    =   13, // External cycle
    sBRR    =   14, // Immediate bus error state
    sEND    =   15; // Cycle end state
reg [3:0] timingState;

always @(posedge sysClk or posedge cpuASn) begin
    if(cpuASn) begin
        cpuDSACKn <= 2'b11;
        cpuBERRn <= 1;
        timingState <= 0;
        romCEn <= 1;
        sysMRDn <= 1;
        sysMWRn <= 1;
        cpuDataHiHi <= 8'bZZZZZZZZ;
        spioCEn <= 1;
        keyATNn <= 1;
        vidCEn <= 1;
        isaCEn <= 1;
        fpuCEn <= 1;
        ramCEn <= 1;
        cpuCIINn <= 1;
        cpuAVECn <= 1;
    end else begin
        case (timingState)
            sIDL: begin
                // Idle state. Deassert all signals. Wait for CPU to start a bus cycle
                cpuDSACKn <= 2'b11;
                cpuBERRn <= 1;
                romCEn <= 1;
                sysMRDn <= 1;
                sysMWRn <= 1;
                cpuDataHiHi <= 8'bZZZZZZZZ;
                spioCEn <= 1;
                keyATNn <= 1;
                vidCEn <= 1;
                isaCEn <= 1;
                fpuCEn <= 1;
                ramCEn <= 1;
                cpuCIINn <= 1;
                cpuAVECn <= 1;
                if(!cpuASn) begin
                    // CPU has started a bus cycle
                    if(cpuFC == 3'b111) begin
                        // this is a CPU space cycle
                        if(cpuAddrHi == 0 && cpuAddrMid == 4'h2) begin
                            // this is an coprocessor cycle
                            if(!fpuSENSEn) begin
                                // FPU is present
                                fpuCEn <= 0;
                                timingState <= sEXT;
                            end else begin
                                // FPU is not present, BERR
                                timingState <= sBRR;
                            end
                        end else if(cpuAddrHi == 11'h7ff && cpuAddrMid == 4'hf) begin
                            // this is an IRQ cycle, for now just assert AVEC
                            cpuAVECn <= 0;
                            timingState <= sEND;
                        end else begin
                            // this is an unsupported CPU cycle
                            timingState <= sBRR;
                        end
                    end else begin
                        // this is a normal memory space cycle
                        if(cpuAddrHi[10:3] == 8'he0) begin
                            // this is a bus controller register cycle
                            if(cpuRWn) begin
                                // bus controller register read cycle
                                timingState <= sRRD;
                            end else begin
                                // bus controller register write cycle
                                timingState <=sRWR;
                            end
                        end else if(cpuAddrHi[10:3] == 8'h00) begin
                            /*// this is a rom cycle
                            timingState <= sRM1;
                            romCEn <= 0;
                            if(cpuRWn) begin
                                // rom read cycle
                                sysMRDn <= 0;
                            end else begin
                                // rom write cycle
                                sysMWRn <= 0;
                            end*/
                            cpuCIINn <= 1;
                            if(~regSets[0] & cpuRWn) begin
                                // overlay ROM Read cycle
                                timingState <= sRM1;
                                romCEn <= 0;
                                sysMRDn <= 0;
                            end else begin
                                // DRAM cycle
                                timingState <= sEXT;
                                ramCEn <= 0;
                            end
                        end else if(cpuAddrHi[10:3] == 8'hdc) begin
                            // this is an S/P I/O cycle
                            timingState <= sSP1;
                            spioCEn <= 0;
                            cpuCIINn <= 0;
                        end else if(cpuAddrHi[10:3] == 8'hd0) begin
                            // this is a video cycle
                            vidCEn <= 0;
                            berrTimer <= 8'hff;
                            timingState <= sEXT;
                        end else if(cpuAddrHi[10:4] == 7'b1101001) begin
                            // this is an ISA bus cycle
                            isaCEn <= 0;
                            berrTimer <= 8'hff;
                            timingState <= sEXT;
                            if(cpuAddrHi[3]) begin
                                // this is an ISA I/O cycle, inhibit cache
                                cpuCIINn <= 0;
                            end
                        end else if(cpuAddrHi[10:3] == 8'hde) begin
                            // this is a keyboard controller access cycle
                            keyATNn <= 0;
                            berrTimer <= 8'hff;
                            timingState <= sEXT;
                            cpuCIINn <= 0;
                        end else if(cpuAddrHi[10:3] == 8'hf0) begin
                            // this is a normal ROM access cycle
                            romCEn <= 0;
                            timingState <= sRM1;
                            if(cpuRWn) sysMRDn <= 0;
                            else sysMWRn <= 0;
                        end else begin
                            // requested address not addressed by bus controller
                            // start a bus error countdown
                            berrTimer <= 8'hff;
                            timingState <= sEXT;
                            cpuCIINn <= 0;
                        end
                    end
                end else begin
                    // keep idling
                    timingState <= sIDL;
                end
            end
            sEND: begin
                // cycle end state. Proceed to sIDL when CPU deasserts cpuASn, otherwise hold here
                if(cpuASn) begin
                    timingState <= sIDL;
                    cpuDSACKn <= 2'b11;
                    cpuBERRn <= 1;
                end else begin
                    timingState <= sEND;
                end
            end
            sRM1: begin
                // ROM1 state. Wait state 0. Proceed immediately to sRM2
                timingState <= sRM2;
            end
            sRM2: begin
                // ROM2 state. Wait state 1. Proceed immediately to sRM3
                timingState <= sRM3;
            end
            sRM3: begin
                // ROM3 state. Wait state 2. Proceed immediately to sRM4
                timingState <= sRM4;
            end
            sRM4: begin
                // ROM4 state. Assert DSACK0. Proceed immediately to sEND
                cpuDSACKn <= 2'b10;
                timingState <= sEND;
            end
            sRRD: begin
                // register read state. Assert DSACK0 and put regSets on data bus. 
                // Proceed immediately to sEND
                timingState <= sEND;
                cpuDSACKn <= 2'b10;
                cpuDataHiHi <= regSets;
            end
            sRWR: begin
                // register write state. Assert DSACK0. Data write to register
                // will be handled by another function on opposite clock edge.
                // Proceed immediately to sEND
                timingState <= sEND;
                cpuDSACKn <= 2'b10;
            end
            sSP1: begin
                // SPIO1 state. Wait state 1. Assert read/write strobe
                // Proceed immediately to sSP2
                if(cpuRWn) begin
                    sysMRDn <= 0;
                end else begin
                    sysMWRn <= 0;
                end
                timingState <= sSP2;
            end
            sSP2: begin
                timingState <= sSP3;
            end
            sSP3: begin
                timingState <= sSP4;
            end
            sSP4: begin
                timingState <= sSP5;
            end
            sSP5: begin
                timingState <= sSP6;
            end
            sSP6: begin
                timingState <= sEND;
                cpuDSACKn <= 2'b10;
            end
            sEXT: begin
                if(sysACKn[0] & sysACKn[1] & vidACKn & keyACKn & isaACK16n & isaACK8n & ramACKn) begin
                    // no external device is trying to end a cycle
                    if(berrTimer != 0) begin
                        // timeout countdown has not yet expired
                        berrTimer <= berrTimer - 1;
                        timingState <= sEXT;
                    end else begin
                        // bus error timer has expired
                        // assert cpuBERRn and move to cycle end
                        cpuBERRn <= 0;
                        timingState <= sEND;
                    end
                end else begin
                    // external device is ending a bus cycle
                    /*if(!ramACKn) begin
                        cpuSTERMn <= 0;
                    end else begin*/
                        cpuDSACKn[0] <= sysACKn[0] & vidACKn & keyACKn & isaACK8n;
                        cpuDSACKn[1] <= sysACKn[1] & isaACK16n;
                    //end
                    timingState <= sEND;
                end
            end
            sBRR: begin
                // immediate bus error state
                // assert cpuBERRn and move to cycle end
                cpuBERRn <= 0;
                timingState <= sEND;
            end
            default:  begin
                // how did we get here?
                timingState <= sIDL;
            end
        endcase
    end
end

// load data into settings register
always @(negedge sysClk) begin
    if(timingState == sRWR) begin
        regSets <= cpuDataHiHi;
    end
end

always_comb begin
    //sysPWRON <= 0;
    sysPWRON <= regSets[1];
    sysLEDdebug <= regSets[2];

    // on power on, hold RESET low until the power supply pulls PWR_OK high.
    if(sysPWROK) begin
        sysRESETn <= 1'bZ;
    end else begin
        sysRESETn <= 1'b0;
    end
end
    
endmodule