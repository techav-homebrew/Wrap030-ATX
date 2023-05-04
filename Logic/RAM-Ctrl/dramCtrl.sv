module dramCtrl (
    // general system signals
    input   wire            sysClk,         // Primary system clock
    input   wire            sysRESETn,      // Primary system reset signal
    // CPU control signals
    input   wire [29:0]     cpuAddr,        // CPU address bus
    input   wire [1:0]      cpuSIZ,         // CPU size signals
    input   wire            cpuRWn,         // CPU read/write signal
    input   wire            cpuASn,         // CPU address strobe
    input   wire            cpuCBREQn,      // CPU cache burst request
    output  wire            cpuCBACKn,      // CPU cache burst acknowledge
    // Bus control signals
    input   wire            ramCEn,         // RAM chip enable
    output  reg             ramACKn,        // RAM cycle acknowledge
    // DRAM control signals
    output  reg  [11:0]     memAddr,        // DRAM address bus
    output  reg             memWEn,         // DRAM write signal
    output  reg  [3:0]      memCASn,        // DRAM column address strobes
    output  reg  [3:0]      memRASn         // DRAM row address strobes
);

// primary DRAM controller state machine
parameter
    sIDLE   =   0,  // Idle state
    sROW0   =   1,  // Cycle ROW state
    sCOL0   =   2,  // Cycle COL state 0
    sCOL1   =   3,  // Cycle COL state 1
    sBRST   =   4,  // Burst Cycle state
    sBEND   =   5,  // Burst End state
    sRFH0   =   6,  // Refresh 0 state
    sRFH1   =   7,  // Refresh 1 state
    sRFH2   =   8,  // Refresh 2 state
    sRFH3   =   9,  // Refresh 3 state
    sREGW   =  10;  // Register Write state
reg [3:0] timingState, nextState;

always @(negedge sysClk, negedge sysRESETn) begin
    if(!sysRESETn) begin
        timingState <= sIDLE;
    end else begin
        timingState <= nextState;
    end
end

always @(*) begin
    nextState = timingState;
    case(timingState)
        sIDLE: begin
            if(refreshCall) begin
                nextState = sRFH0;
            end else if(!ramCEn) begin
                if(cpuAddr[29] & cpuAddr[28] & !cpuRWn) begin
                    // do a register write cycle
                    nextState = sREGW;
                end else begin
                    // do a regular CPU read/write cycle
                    nextState = sROW0;
                end
            end else begin
                nextState = sIDLE;
            end
        end

        // normal access cycle sequence
        sROW0: nextState = sCOL0;
        sCOL0: nextState = sCOL1;
        sCOL1: begin
            if(!cpuCBREQn) begin
                nextState = sBRST;
            end else begin
                nextState = sIDLE;
            end
        end
        sBRST: begin
            if(!cpuCBREQn) begin
                nextState = sCOL1;
            end else begin
                nextState = sBEND;
            end
        end
        sBEND: nextState = sIDLE;

        // CBR refresh sequence
        sRFH0: nextState = sRFH1;
        sRFH1: nextState = sRFH2;
        sRFH2: nextState = sRFH3;
        sRFH3: nextState = sIDLE;

        default: nextState = sIDLE;
    endcase
end

// settings registers
reg [1:0] rRowSize, rColSize;

// helpful combinatorial signals we'll use later
wire [1:0] rasCalc;
wire selectedSlot, selectedBank;
wire [3:0] memSize;
wire [3:0] rasCalcExpn, casCalcExpn;
wire [11:0] memAddrRow, memAddrCol;
always_comb begin
    rasCalc[0] = selectedSlot;
    rasCalc[1] = selectedBank;
    memSize[1:0] = rColSize;
    memSize[3:2] = rRowSize;
    case(memSize)
        0: selectedSlot = cpuAddr[20];
        1: selectedSlot = cpuAddr[21];
        2: selectedSlot = cpuAddr[22];
        3: selectedSlot = cpuAddr[23];
        4: selectedSlot = cpuAddr[21];
        5: selectedSlot = cpuAddr[22];
        6: selectedSlot = cpuAddr[23];
        7: selectedSlot = cpuAddr[24];
        8: selectedSlot = cpuAddr[22];
        9: selectedSlot = cpuAddr[23];
        10: selectedSlot = cpuAddr[24];
        11: selectedSlot = cpuAddr[25];
        12: selectedSlot = cpuAddr[23];
        13: selectedSlot = cpuAddr[24];
        14: selectedSlot = cpuAddr[25];
        15: selectedSlot = cpuAddr[26];
    endcase
    case(memSize)
        0: selectedBank = cpuAddr[21];
        1: selectedBank = cpuAddr[22];
        2: selectedBank = cpuAddr[23];
        3: selectedBank = cpuAddr[24];
        4: selectedBank = cpuAddr[22];
        5: selectedBank = cpuAddr[23];
        6: selectedBank = cpuAddr[24];
        7: selectedBank = cpuAddr[25];
        8: selectedBank = cpuAddr[23];
        9: selectedBank = cpuAddr[24];
        10: selectedBank = cpuAddr[25];
        11: selectedBank = cpuAddr[26];
        12: selectedBank = cpuAddr[24];
        13: selectedBank = cpuAddr[25];
        14: selectedBank = cpuAddr[26];
        15: selectedBank = cpuAddr[27];
    endcase
    case(rasCalc)
        0: rasCalcExpn = 4'b1110;
        1: rasCalcExpn = 4'b1011;
        2: rasCalcExpn = 4'b1101;
        3: rasCalcExpn = 4'b0111;
    endcase
    memAddrCol = cpuAddr[13:2];
    case(rColSize)
        0: memAddrRow = cpuAddr[22:11];
        1: memAddrRow = cpuAddr[23:12];
        2: memAddrRow = cpuAddr[24:13];
        3: memAddrRow = cpuAddr[25:14];
    endcase
end
bus030selects modCAScalc
(
    .cpuAddr (cpuAddr[1:0]),
    .cpuSIZ  (cpuSIZ),
    .cpuRWn  (cpuRWn),
    .byteSELn(casCalcExpn),
    .wordSELn()
);

// refresh timing counter
reg [8:0] refreshTimer;
reg refreshCall, refreshAck;
//reg [3:0] initRfshCount;
always @(posedge sysClk, negedge sysRESETn) begin
    if(!sysRESETn) begin
        refreshTimer <= 0;
        refreshCall <= 0;
    end else if(refreshTimer >= 9'h186) begin   // 390 cycles @ 25MHz = 15.6us
        refreshCall <= 1;
        refreshTimer <= 0;
    end else begin
        refreshTimer = refreshTimer + 9'h001;
        if(refreshAck) refreshCall <= 0;
    end
    /*else if(initRfshCount >= 4'h8) begin
        refreshTimer = refreshTimer + 9'h001;
        if(refreshAck) refreshCall <= 0;
    end*/
end

always @(negedge sysClk, negedge sysRESETn) begin
    if(!sysRESETn) begin
        refreshAck <= 0;
    end else begin
        if(nextState == sRFH0) begin
            refreshAck <= 1;
        end else begin
            refreshAck <= 0;
        end
    end
end

// set configuration registers
always @(posedge sysClk, negedge sysRESETn) begin
    if(!sysRESETn) begin
        // set default register settings on reset
        rRowSize <= 2'h2;
        rColSize <= 2'h2;
    end else begin
        if(timingState == sREGW) begin
            rRowSize <= cpuAddr[11:10];
            rColSize <= cpuAddr[9:8];
        end
    end
end

// memory address output
// burst address calculation
reg[1:0] burstAddr;
always @(posedge sysClk, negedge sysRESETn) begin
    if(!sysRESETn) begin
        burstAddr <= 0;
    end else begin
        if(timingState == sIDLE & !cpuASn) begin
            burstAddr <= cpuAddr[3:2];
        end else if(timingState == sCOL1) begin
            burstAddr <= burstAddr + 2'h1;
        end
    end
end
// double-buffered to meet timing requirements
wire [11:0] nextMemAddr;
always_comb begin
    case(nextState)
    sROW0: begin
        nextMemAddr <= memAddrRow;
    end
    sCOL0, sCOL1, sBRST, sBEND: begin
        nextMemAddr[11:2] <= memAddrCol[11:2];
        nextMemAddr[1:0] <= burstAddr;
    end
    default:
        nextMemAddr <= 0;
    endcase
end
always @(negedge sysClk, negedge sysRESETn) begin
    if(!sysRESETn) begin
        memAddr <= 0;
    end else begin
        memAddr <= nextMemAddr;
    end
end


/*
reg[1:0] burstAddr;
always @(negedge sysClk, negedge sysRESETn) begin
    if(!sysRESETn) begin
        memAddr <= 0;
        burstAddr <= 0;
    end else begin
        case(nextState)
            sROW0: begin
                // output cycle row address
                memAddr <= memAddrRow;
                // and store the initial burst address value
                burstAddr <= cpuAddr[3:2];
            end
            sCOL0, sBRST: begin
                // output cycle column address
                memAddr[11:2] <= memAddrCol[11:2];
                // output burst address
                memAddr[1:0] <= burstAddr;
            end
            sCOL1: begin
                burstAddr <= burstAddr + 2'h1;
            end
        endcase
    end
end
*/

// output row & column strobes
always @(negedge sysClk, negedge sysRESETn) begin
    if(!sysRESETn) begin
        memRASn <= 4'b1111;
    end else begin
        case(nextState)
            sROW0, sCOL0, sCOL1, sBRST, sBEND: begin
                // cpu access cyle
                memRASn <= rasCalcExpn;
            end
            sRFH1, sRFH2, sRFH3: begin
                // refresh cycle
                memRASn <= 4'b0000;
            end
            default: begin
                memRASn <= 4'b1111;
            end
        endcase
    end
end
always @(negedge sysClk, negedge sysRESETn) begin
    if(!sysRESETn) begin
        memCASn <= 4'b1111;
    end else begin
        case(nextState)
            sCOL0, sCOL1, sBEND: begin
                // cpu access cycle
                memCASn <= casCalcExpn;
            end
            sRFH0, sRFH1, sRFH2: begin
                // refresh cycle
                memCASn <= 4'b0000;
            end
            default: begin
                memCASn <= 4'b1111;
            end
        endcase
    end
end

// other contol signal outputs
always @(negedge sysClk, negedge sysRESETn) begin
    if(!sysRESETn) begin
        cpuCBACKn <= 1;
    end else begin
        case(nextState)
            sROW0, sCOL0, sCOL1, sBRST, sBEND: begin
                if(!cpuCBREQn) cpuCBACKn <= 0;
                else cpuCBACKn <= 1;
            end
            default: cpuCBACKn <= 1;
        endcase
    end
end
always @(negedge sysClk, negedge sysRESETn) begin
    if(!sysRESETn) begin
        ramACKn <= 1;
    end else begin
        case(nextState)
            sCOL1, sBEND: ramACKn <= 0;
            default: ramACKn <= 1;
        endcase
    end
end
always @(negedge sysClk, negedge sysRESETn) begin
    if(!sysRESETn) begin
        memWEn = 1;
    end else begin
        case(nextState)
            sROW0, sCOL0, sCOL1, sBRST, sBEND: begin
                if(cpuRWn) memWEn <= 1;
                else memWEn <= 0;
            end
            default: memWEn <= 1;
        endcase
    end
end


endmodule