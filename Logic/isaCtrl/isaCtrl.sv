module isaCtrl (
    input   wire            sysClk,         // primary system clock
    input   wire            sysRESETn,      // primary system reset

    input   wire [1:0]      cpuSIZ,         // CPU size signals
    input   wire            cpuDSn,         // CPU data strobe
    input   wire            cpuASn,         // CPU address strobe
    input   wire            cpuRWn,         // CPU read/write signal

    input   wire            isaCEn          // isa chip enable
    output  wire            isaACK8n,       // isa bus 8-bit cycle acknowledge
    output  wire            isaACK16n,      // isa bus 16-bit cycle acknowledge

    output  wire            isaXFER8n,      // isa bus 8-bit data path
    output  wire            isaXFER16n,     // isa bus 16-bit data path
    output  wire            isaIORn,        // isa bus IO read strobe
    output  wire            isaIOWn,        // isa bus IO write strobe
    output  wire            isaMEMRn,       // isa bus Mem read strobe
    output  wire            isaMEMWn,       // isa bus Mem write strobe

    output  wire            isaAEN,         // isa bus Address Enable
    input   wire            isaMASTER,      // isa card taking control of bus
    output  wire            isaSBHEn,       // isa system bus high enable (16b xfer)
    output  wire            isaRESET,       // isa active high reset
    input   wire            isaREADY,       // isa card ready signal

    output  wire            isaCLK,         // isa bus clock
    output  wire            isaALE,         // isa address latch

    input   wire            isaMEM16n,      // isa card is 8-bit
    input   wire            isaIO16n,       // isa card is 16-bit

    input   wire            isaA9,          // isa Address bit 9 (for IDE)
    
    output  wire            ideCS1n,        // ide chip select 1
    output  wire            ideCE3n,        // ide chip select 3
    input   wire            ideCEn          // ide chip select
);

// primary isa bus state machine
parameter
    sIDLE   =    0, // Idle state
    sAEN    =    1, // Assert isa address enable
    sALE    =    2, // Assert isa address latch
    s8BWR   =    3, // Start 8-bit write cycle
    s8BRD   =    4, // Start 8-bit read cycle
    s8BW0   =    5, // 8-bit wait 0
    s8BW1   =    6, // 8-bit wait 1
    s8BW2   =    7, // 8-bit wait 2
    s16WR   =    8, // Start 16-bit write cycle
    s16RD   =    9, // Start 16-bit read cycle
    s16W0   =   10, // 16-bit wait 0
    s16W1   =   11, // 16-bit wait 1
    s16W2   =   12, // 16-bit wait 2
    sTERM   =   13; // End isa bus cycle
reg [3:0] timingState, nextState;

always @(posedge sysClk, negedge sysRESETn) begin
    if(!sysRESETn) begin
        timingState <= sIDLE;
    end else begin
        //
    end
end


endmodule