module busCtrl (
    // general system signals
    input   wire            sysClk,         // Primary system clock
    input   wire            sysRESETn,      // Primary system reset signal
    input   wire            sysPWROKn,      // System power on OK signal
    output  wire            sysPRWONn,      // System ATX soft power on latch
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

// control registers
reg regOverlay, regPower, regGPIO;

// primary bus controller state machine
parameter
    sIDLE   =    0, // Idle state
    sROM0   =    1, // ROM state 0
    sROM1   =    2, // ROM state 1
    sROM2   =    3, // ROM state 2
    sROM3   =    4, // ROM state 3
    sSPI0   =    5, // SPIO state 0
    sSPI1   =    6, // SPIO state 1
    sSPI2   =    7, // SPIO state 2
    sSPI3   =    8, // SPIO state 3
    sSPI4   =    9, // SPIO state 4
    sSPI5   =   10, // SPIO state 5
    sSPI6   =   11, // SPIO state 6
    sDRAM   =   12, // DRAM access cycle
    sAVEC   =   13, // IRQ Autovector cycle
    sFPU0   =   14, // FPU access start
    sFPU1   =   15, // FPU access termination
    sBERR   =   16, // Bus Error state
    sVID0   =   17, // vidGen access start
    sVID1   =   18, // vidGen access termination
    sKBD0   =   19, // keyboard access start
    sKBD1   =   20, // keyboard access termination
    sISA0   =   21, // ISA access start
    sISA1   =   22, // ISA access termination
    sREGR   =   23, // busCtrl register read
    sREGW   =   24, // busCtrl register write
    sEXT    =   25; // external access cycle
reg [4:0] timingState, nextState;

always @(posedge sysClk, negedge sysRESETn) begin
    if(!sysRESETn) begin
        timingState <= sIDLE;
    end else begin
        timingState <= nextState;
    end 
end

always_comb begin
    nextState = timingState;
    case(timingState)
        sIDLE: begin
            if(!cpuASn) begin
                if(cpuFC == 3'b111) begin
                    // CPU space 
                    if(cpuAddrHi == 0 & cpuAddrMid == 4'h2) begin
                        // coprocessor access cycle
                        if(!fpuSENSEn) nextState = sFPU0;
                        else nextState = sBERR;
                    end else if(cpuAddrHi == 11'h7ff & cpuAddrMid == 4'hf) begin
                        // IRQ cycle
                        nextState = sAVEC;
                    end else begin
                        // unsupported CPU space cycle
                        nextState = sBERR;
                    end
                end else begin
                    // memory space
                    if(cpuAddrHi[10:9] == 0) begin
                        // DRAM space or overlay ROM read
                        if(!regOverlay & cpuRWn) nextState = sROM0;
                        else nextState = sDRAM;
                    end else begin
                        case(cpuAddrHi[10:3])
                            /*8'h00: begin
                                // DRAM space or overlay ROM read
                                if(!regOverlay & cpuRWn) nextState = sROM0;
                                else nextState = sDRAM;
                            end*/
                            8'hf0: nextState = sROM0;
                            8'hd0: nextState = sVID0;
                            8'hd2, 8'hd3: nextState = sISA0;
                            8'hdc: nextState = sSPI0;
                            8'hde: nextState = sKBD0;
                            8'he0: begin
                                if(cpuRWn) nextState = sREGR;
                                else nextState = sREGW;
                            end
                            default: nextState = sEXT;
                        endcase 
                    end
                end
            end else begin
                nextState = sIDLE;
            end
        end
        
        // ROM sequence
        sROM0: nextState = sROM1;
        sROM1: nextState = sROM2;
        sROM2: nextState = sROM3;

        // SPIO sequence
        sSPI0: nextState = sSPI1;
        sSPI1: nextState = sSPI2;
        sSPI2: nextState = sSPI3;
        sSPI3: nextState = sSPI4;
        sSPI4: nextState = sSPI5;
        sSPI5: nextState = sSPI6;

        // FPU sequence
        sFPU0: nextState = sFPU0;

        // vidGen sequence
        sVID0: nextState = sVID1;

        // keyboard controller sequence
        sKBD0: nextState = sKBD1;

        // ISA sequence
        sISA0: nextState = sISA1;

        // cycle end states for each sequence that can time out
        sDRAM, sFPU1, sVID1, sKBD1, sISA1, sEXT: begin
            if(cpuASn) begin
                nextState = sIDLE;
            end else if(berrTimer == 0) begin
                nextState = sBERR;
            end else begin
                nextState = timingState;
            end
        end

        // direct end cycles
        sROM3, sSPI6, sAVEC, sBERR, sREGR, sREGW: begin
            if(cpuASn) nextState = sIDLE;
            else nextState = timingState;
        end
    endcase
end

// bus error timout
reg [7:0] berrTimer;
always @(negedge sysClk, negedge sysRESETn) begin
    if(!sysRESETn) begin
        berrTimer <= 8'hff;
    end else begin
        case(timingState)
            sIDLE: berrTimer <= 8'hff;
            default: berrTimer <= berrTimer - 8'h01;
        endcase
    end
end

// load data into settings registers during sREGW state
always @(negedge sysClk, negedge sysRESETn) begin
    if(!sysRESETn) begin
        // regOverlay <= 0;
        regPower <= 0;
        regGPIO <= 0;
    end else begin
        if(timingState == sREGW) begin
            // regOverlay <= cpuDataHiHi[0];
            regPower <= cpuDataHiHi[1];
            regGPIO <= cpuDataHiHi[2];
        end
    end
end

// automatically disable overlay on 8th ROM access cycle
// ... I think this will work?
reg [2:0] overlayCycleCount;
always @(negedge romCEn, negedge sysRESETn) begin
    if(!sysRESETn) begin
        regOverlay <= 0;
        overlayCycleCount <= 0;
    end else begin
        if(overlayCycleCount != 3'h7) begin
            overlayCycleCount <= overlayCycleCount + 3'h1;
        end else begin
            regOverlay <= 1;
        end
    end
end

// synchronous control output signals
// DSACKx & AVEC
always @(posedge sysClk, negedge sysRESETn) begin
    if(!sysRESETn) begin
        cpuDSACKn <= 2'b11;
        cpuAVECn <= 1'b1;
    end else begin
        case(nextState)
            sROM3, sSPI6, sREGR, sREGW: begin
                cpuDSACKn <= 2'b10;
                cpuAVECn <= 1'b1;
            end
            sVID1: begin
                cpuDSACKn[0] <= vidACKn;
                cpuDSACKn[1] <= 1'b1;
                cpuAVECn <= 1'b1;
            end
            sKBD1: begin
                cpuDSACKn[0] <= keyACKn;
                cpuDSACKn[1] <= 1'b1;
                cpuAVECn <= 1'b1;
            end
            sAVEC: begin
                cpuDSACKn <= 2'b11;
                cpuAVECn <= 1'b0;
            end
            sFPU1, sEXT: begin
                cpuDSACKn <= sysACKn;
                cpuAVECn <= 1'b1;
            end
            sISA1: begin
                cpuDSACKn[1] <= isaACK16n;
                cpuDSACKn[0] <= isaACK8n;
                cpuAVECn <= 1'b1;
            end
            default: begin
                cpuDSACKn <= 2'b11;
                cpuAVECn <= 1'b1;
            end
        endcase
    end
end
// CIIN
always @(posedge sysClk, negedge sysRESETn) begin
    if(!sysRESETn) begin
        cpuCIINn <= 1'b1;
    end else begin
        case(nextState)
            sIDLE, sROM0, sROM1, sROM2, sROM3, sDRAM: begin
                cpuCIINn <= 1'b1;
            end
            default: begin
                cpuCIINn <= 1'b0;
            end
        endcase
    end
end
// CPU Data bus
always @(posedge sysClk, negedge sysRESETn) begin
    if(!sysRESETn) begin
        cpuDataHiHi <= 8'bZZZZZZZZ;
    end else begin
        if(nextState == sREGR) begin
            cpuDataHiHi[0] <= regOverlay;
            cpuDataHiHi[1] <= regPower;
            cpuDataHiHi[2] <= regGPIO;
            cpuDataHiHi[7:3] <= 5'h00;
        end else begin
            cpuDataHiHi <= 8'bZZZZZZZZ;
        end
    end
end
// bus error signal
always @(posedge sysClk, negedge sysRESETn) begin
    if(!sysRESETn) begin
        cpuBERRn <= 1'b1;
    end else begin
        if(nextState == sBERR) begin
            cpuBERRn <= 1'b0;
        end else begin
            cpuBERRn <= 1'b1;
        end
    end
end
// read/write strobe signals
always @(posedge sysClk, negedge sysRESETn) begin
    if(!sysRESETn) begin
        sysMRDn <= 1'b1;
        sysMWRn <= 1'b1;
    end else begin
        case(nextState)
            sROM0, sROM1, sROM2, sROM3, sSPI1, sSPI2, sSPI3, sSPI4, sSPI5, sSPI6: begin
                if(cpuRWn) begin
                    sysMRDn <= 1'b0;
                    sysMWRn <= 1'b1;
                end else begin
                    sysMRDn <= 1'b1;
                    sysMWRn <= 1'b0;
                end
            end
            default: begin
                sysMRDn <= 1'b1;
                sysMWRn <= 1'b1;
            end
        endcase
    end
end

// asynchronous control signals
always_comb begin
     fpuCEn = 1'b1;
     romCEn = 1'b1;
     vidCEn = 1'b1;
     keyATNn = 1'b1;
     spioCEn = 1'b1;
     isaCEn = 1'b1;
     ramCEn = 1'b1;
     case(timingState)
        sFPU0, sFPU1: fpuCEn = 1'b0;
        sROM0, sROM1, sROM2, sROM3: romCEn = 1'b0;
        sVID0, sVID1: vidCEn = 1'b0;
        sKBD0, sKBD1: keyATNn = 1'b0;
        sSPI0, sSPI1, sSPI2, sSPI3, sSPI4, sSPI5, sSPI6: spioCEn = 1'b0;
        sISA0, sISA1: isaCEn = 1'b0;
        sDRAM: ramCEn = 1'b0;
        default: begin
            fpuCEn = 1'b1;
            romCEn = 1'b1;
            vidCEn = 1'b1;
            keyATNn = 1'b1;
            spioCEn = 1'b1;
            isaCEn = 1'b1;
            ramCEn = 1'b1;
        end
     endcase
end

always_comb begin
    sysPRWONn = regPower;
    sysLEDdebug = regGPIO;
end

endmodule