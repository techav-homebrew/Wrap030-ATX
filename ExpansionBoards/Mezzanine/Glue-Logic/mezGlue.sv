/******************************************************************************
 * Wrap030 Mezzanine Glue Logic
 * techav
 * 2022-10-28
 ******************************************************************************
 * Glue logic 
 *****************************************************************************/

module mezGlue (
    input   wire                nReset,     // primary system reset         1
    input   wire                nAS,        // address strobe               35
    input   wire                nDS,        // cpu data strobe              41
    input   wire                sysClk,     // primary system clock         2
    input   wire                fpuClk,     // fpu clock                    43
    input   wire                RnW,        // cpu read/write signal        34
    input   wire                addr31,     // address bit 31               15
    input   wire [1:0]          cpuFC,      // cpu function code            14,11
    input   wire [1:0]          siz,        // transfer size bits           17,19
    input   wire [6:0]          addrSel,    // address select bits (19:13)  28-24,21-20
    inout   wire                znBerr,     // cpu bus error                18
    inout   wire [1:0]          znDsack,    // cpu data strobe acknowledge  29,31
    output  reg                 nIORd,      // ide io read strobe           5
    output  reg                 nIOWr,      // ide io write strobe          40
    output  reg                 nIdeBufEn,  // ide buffer enable            12
    input   wire                nIdeIO16,   // ide 16-bit signal            9
    output  reg                 nIdeCS3,    // ide CE3 signal               8
    output  reg                 nIdeCS1,    // ide CE1 signal               6
    input   wire                nIdeCE,     // ide enable signal            4
    output  wire                nFpuCE,     // fpu enabale signal           33
    input   wire                nFpuSense   // fpu presence detect signal   37
);

/*****************************************************************************/
// FPU logic
// this is synchronous with the rising edge of the system clock to ensure there
// is enough setup time between the CPU asserting nAS (on the falling edge) and
// us asserting the nFpuCE. There is not enough time to try to assert nFpuCE 
// before the CPU asserts nAS and still meet the setup time requirements for
// the FPU, so we'll have to use a late chip select.
always @(posedge sysClk or posedge nAS) begin
    if(nAS) nFpuCE <= 1;
    else if(cpuFC == 2'b11 && addrSel == 7'b0010001 && !nAS) nFpuCE <= 0;
    else nFpuCE <= 1;
end

// bus error if the FPU is not detected
reg fpuBerr;
always @(posedge sysClk or negedge nReset) begin
    if(!nReset) begin
        fpuBerr <= 1'b0;
    end else if(cpuFC == 2'b11 && addrSel == 7'b0010001 && !nAS && nFpuSense) begin
        fpuBerr <= 1'b1;
    end else begin
        fpuBerr <= 1'b0;
    end
end
always_comb begin
    if(fpuBerr) znBerr <= 1'b0;
    else znBerr <= 1'bZ;
end
// and that's all we need for the FPU?

/*****************************************************************************/
// IDE logic

// board will assert nIdeCE when A31=1, A20=0, & A[23:21] match jumper setting.
// glue logic needs to confirm A[19:14]=0. A13 selects command/control register

// IDE timing state machine
parameter 
    sIDL    =   0,  // Idle state
    sENA    =   1,  // Enable state
    sWT1    =   2,  // Wait 1 state
    sWT2    =   3,  // Wait 2 state
    sBRW    =   4,  // Assert Read/Write state
    sWT3    =   5,  // Wait 3 state
    sWT4    =   6,  // Wait 4 state
    sEND    =   7;  // Terminate Cycle state
reg [2:0] timingState;

// state machine clocked by rising edge of CPU clock and reset by the rising
// edge of the CPU Address Strobe signal
always @(posedge sysClk or posedge nAS) begin
    if(nAS) begin
        // reset
        timingState <= sIDL;
        nIdeCS1 <= 1;
        nIdeCS3 <= 1;
        nIORd <= 1;
        nIOWr <= 1;
        nIdeBufEn <= 1;
        znDsack <= 2'bZZ;
    end else begin
        // normal operation
        case(timingState)
            sIDL: begin
                if(!nIdeCE && addrSel[6:1]==0 && addr31) begin
                    timingState <= sENA;
                    if(addrSel[0]) begin
                        nIdeCS3 <= 0;
                        nIdeCS1 <= 1;
                    end else begin
                        nIdeCS3 <= 1;
                        nIdeCS1 <= 0;
                    end
                    nIORd <= 1;
                    nIOWr <= 1;
                    nIdeBufEn <= 0;
                    znDsack <= 2'bZZ;
                end else begin
                    timingState <= sIDL;
                    nIdeCS1 <= 1;
                    nIdeCS3 <= 1;
                    nIORd <= 1;
                    nIOWr <= 1;
                    nIdeBufEn <= 1;
                    znDsack <= 2'bZZ;
                end
            end
            sENA: begin
                timingState <= sWT1;
                // no signal changes here
            end
            sWT1: begin
                timingState <= sWT2;
                // no signal changes here
            end
            sWT2: begin
                timingState <= sBRW;
                // assert IDE read or write strobes as appropriate
                if(RnW) begin
                    nIORd <= 0;
                    nIOWr <= 1;
                end else begin
                    nIORd <= 1;
                    nIOWr <= 0;
                end
            end
            sBRW: begin
                timingState <= sWT3;
                // no signal changes here
            end
            sWT3: begin
                timingState <= sWT4;
                // no signal changes here
            end
            sWT4: begin
                timingState <= sEND;
                // assert CPU DS Acknowledge
                znDsack[0] <= 1'bZ;
                znDsack[1] <= 1'b0;
            end
            sEND: begin
                if(nAS) begin
                    timingState <= sIDL;
                    // negate everything
                    nIdeCS1 <= 1;
                    nIdeCS3 <= 1;
                    nIORd <= 1;
                    nIOWr <= 1;
                    nIdeBufEn <= 1;
                    znDsack <= 2'bZZ;
                end else begin
                    timingState <= sEND;
                    // hold everything
                end
            end
            default: begin
                // how did we end up here?
                timingState <= sIDL;
            end
        endcase
    end
end

/*****************************************************************************/
endmodule