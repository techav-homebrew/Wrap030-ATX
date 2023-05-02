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

// initialization timer
reg [12:0] initCount;
always @(posedge sysClk, negedge sysRESETn) begin
    if(!sysRESETn) begin
        initCount <= 13'd5000;
        //initCount <= 13'd0010;          // <=== set low for testing purposes!
    end else begin
        if(initCount > 0) begin
            initCount <= initCount - 13'd1;
        end else begin
            initCount <= 13'd0;
        end
    end
end

// refresh timing counter
reg [8:0] refreshTimer;
reg refreshCall, refreshAck;
reg [2:0] initRfshCount;
always @(posedge sysClk, negedge sysRESETn) begin
    if(!sysRESETn) begin
        refreshTimer <= 0;
        refreshCall <= 0;
    end else if(refreshTimer >= 390) begin
        refreshCall <= 1;
        refreshTimer <= 0;
    end else begin
        refreshTimer = refreshTimer + 9'h001;
        if(refreshAck) refreshCall <= 0;
    end
end

always @(negedge sysClk, negedge sysRESETn) begin
    if(!sysRESETn) begin
        refreshAck <= 0;
    end else begin
        if(nextState == sRC0) begin
            refreshAck <= 1;
        end else begin
            refreshAck <= 0;
        end
    end
end

// initRfshCount counts 8 refresh cycles immediately following the reset
// initialization hold sequence. It is incremented when the state machine
// is in the middle of the refresh sequence, and held there until reset
always @(negedge sysClk, negedge sysRESETn) begin
    if(!sysRESETn) begin
        initRfshCount <= 0;
    end else begin
        if(initRfshCount != 3'd7) begin
            if(timingState == sRR2) begin
                initRfshCount <= initRfshCount + 3'd1;
            end
        end
    end
end

// primary DRAM controller state machine
parameter
    sIDL    =   0,  //  Idle state
    sCR0    =   1,  //  Cycle RAS state 0
    sCC0    =   2,  //  Cycle CAS state 0
    sCC1    =   3,  //  Cycle CAS state 1
    sBST    =   4,  //  Burst Cycle state
    sBND    =   5,  //  Burst End state
    sRC0    =   6,  //  Refresh CAS state 0
    sRR0    =   7,  //  Refresh RAS state 0
    sRR1    =   8,  //  Refresh RAS state 1
    sRR2    =   9,  //  Refresh RAS state 2
    sINIT   =  10,  //  Startup initialization state
    sREG    =  11;  //  Write configuration registers state
reg [3:0] timingState, nextState;

always @(negedge sysClk, negedge sysRESETn) begin
    if(!sysRESETn) begin
        timingState <= sINIT;
    end else begin
        timingState <= nextState;
    end
end

always @(timingState, ramCEn, cpuCBREQn, refreshCall, initRfshCount, initCount, cpuAddr, cpuRWn) begin
    nextState = timingState;
    case(timingState)
        sINIT: begin
            // Startup initialization state
            // hold here until initCount is 0
            // then move on to sRC0 to start a series of 8 refresh cycles
            if(initCount > 0) begin
                nextState = sINIT;
            end else begin
                nextState = sRC0;
            end
        end
        sIDL: begin
            // Idle state
            // if time for refresh, then move to sRC0
            // else if time for CPU cycle then move to sCR0
            // else stay at Idle
            if(refreshCall) begin
                nextState = sRC0;
            end else if(!ramCEn) begin
                if(cpuAddr[29] & cpuAddr[28] & !cpuRWn) begin
                    // do a register write cycle
                    nextState = sREG;
                end else if(cpuAddr[29] & cpuAddr[28] & cpuRWn) begin
                    // this is an attempt to read the config registers, which
                    // is not possible. Instead of trying to start any kind of
                    // bus cycle, we'll stay at sIDL. This will (eventually)
                    // cause the bus controller to assert bus error
                    nextState = sIDL;
                end else begin
                    // do a regular CPU read/write cycle
                    nextState = sCR0;
                end
            end else begin
                nextState = sIDL;
            end
        end
        sCR0: begin
            // Cycle RAS state 0
            // always progress immediately to sCC0
            nextState = sCC0;
        end
        sCC0: begin
            // Cycle CAS state 0
            // always progress immediately to sCC1
            nextState = sCC1;
        end
        sCC1: begin
            // Cycle CAS state 1
            // if cache burst, then proceed to sBST
            // else progress to sIDL to end cycle
            if(!cpuCBREQn) begin
                nextState = sBST;
            end else begin
                nextState = sIDL;
            end
        end
        sBST: begin
            // Cycle burst state
            // if cpu cache burst request still asserted then proceed to sCC1
            // else proceed to sBND to end cycle
            if(!cpuCBREQn) begin
                nextState = sCC1;
            end else begin
                nextState = sBND;
            end
        end
        sBND: begin
            // Cycle burst end
            // always proceed to sIDL to end cycle
            nextState = sIDL;
        end
        sRC0: begin
            // Refresh cycle CAS state 0
            // always proceed to sRR0
            nextState = sRR0;
        end
        sRR0: begin
            // Refresh cycle RAS state 0
            // always proceed to sRR1
            nextState = sRR1;
        end
        sRR1: begin
            // Refresh cycle RAS state 1
            // always proceed to sRR2
            nextState = sRR2;
        end
        sRR2: begin
            // Refresh cycle RAS state 2
            // if initialization is not complete, then start another refresh cycle
            // else procede to sIDL
            if(initRfshCount != 3'd7) begin
                nextState = sINIT;
            end else begin
                nextState = sIDL;
            end
        end
        sREG: begin
            // Register write state
            // procede to sIDL
            nextState = sIDL;
        end
        default: begin
            // how did we get here?
            nextState = sIDL;
        end
    endcase
end

// set configuration registers
always @(posedge sysClk, negedge sysRESETn) begin
    if(!sysRESETn) begin
        // set default register settings on reset
        rRowSize <= 2'h2;
        rColSize <= 2'h2;
    end else begin
        if(timingState == sREG) begin
            rRowSize <= cpuAddr[11:10];
            rColSize <= cpuAddr[9:8];
        end
    end
end

// memory address output
reg[1:0] burstAddr;
always @(negedge sysClk, negedge sysRESETn) begin
    if(!sysRESETn) begin
        memAddr <= 0;
        burstAddr <= 0;
    end else begin
        case(nextState)
            sCR0: begin
                // output row address
                memAddr <= memAddrRow;
                // and store initial burst address value
                burstAddr <= cpuAddr[3:2];
            end
            sCC0, sBST: begin
                // output column address
                memAddr[11:2] <= memAddrCol[11:2];
                // output burst address
                memAddr[1:0] <= burstAddr;
            end
            sCC1: begin
                // update burst address
                burstAddr <= burstAddr + 2'h1;
            end
        endcase
    end
end

// row & column strobe outputs
// these are double-buffered to ensure timing, given everything that goes into
// calculating each signal (especially CAS)
reg [3:0] nextMemCASn, nextMemRASn;

// calculate nextMemRASn
always @(posedge sysClk, negedge sysRESETn) begin
    if(!sysRESETn) begin
        nextMemRASn <= 4'b1111;
    end else begin
        case(nextState)
            sCR0, sCC0, sCC1, sBST, sBND: begin
                // cpu access cycle
                nextMemRASn <= rasCalcExpn;
            end
            sRR0, sRR1, sRR2: begin
                // refresh cycle
                nextMemRASn <= 4'b0000;
            end
            default: begin
                nextMemRASn <= 4'b1111;
            end
        endcase
    end
end

// calculate nextMemCASn
always @(posedge sysClk, negedge sysRESETn) begin
    if(!sysRESETn) begin
        nextMemCASn <= 4'b1111;
    end else begin
        case(nextState)
            sCC0, sCC1, sBND: begin
                // cpu access cycle
                nextMemCASn <= casCalcExpn;
            end
            sRC0, sRR0, sRR1: begin
                nextMemCASn <= 4'b0000;
            end
            sINIT: begin
                // this is to catch a special case at the end of the initialization cycle
                if(initCount == 1) nextMemCASn <= 4'b0000;
                else nextMemCASn <= 4'b1111;
            end
            default: begin
                nextMemCASn <= 4'b1111;
            end
        endcase
    end
end

// now actually output RAS/CAS signals
always @(negedge sysClk, negedge sysRESETn) begin
    if(!sysRESETn) begin
        memRASn <= 4'b1111;
        memCASn <= 4'b1111;
    end else begin
        memRASn <= nextMemRASn;
        memCASn <= nextMemCASn;
    end
end

// misc other control signals output
always_comb begin
    case(timingState)
        sCR0, sCC0: begin
            cpuCBACKn = cpuCBREQn;
            ramACKn = 1;
            memWEn = cpuRWn;
        end
        sCC1: begin
            cpuCBACKn = cpuCBREQn;
            ramACKn = 0;
            memWEn = cpuRWn;
        end
        sBST: begin
            cpuCBACKn = 0;
            ramACKn = 1;
            memWEn = cpuRWn;
        end
        sBND: begin
            cpuCBACKn = 1;
            ramACKn = 0;
            memWEn = cpuRWn;
        end
        sREG: begin
            cpuCBACKn = 1;
            if(cpuRWn) ramACKn = 1;
            else ramACKn = 0;
            memWEn = cpuRWn;
        end
        default: begin
            cpuCBACKn = 1;
            ramACKn = 1;
            memWEn = 1;
        end
    endcase
end

endmodule