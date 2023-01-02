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
    output  wire                nIORd,      // ide io read strobe           5
    output  wire                nIOWr,      // ide io write strobe          40
    output  wire                nIdeBufEn,  // ide buffer enable            12
    input   wire                nIdeIO16,   // ide 16-bit signal            9
    output  wire                nIdeCS3,    // ide CE3 signal               8
    output  wire                nIdeCS1,    // ide CE1 signal               6
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

// temporary assignments
assign nIdeCS1 = 1;
assign nIdeCS3 = 1;
assign nIORd = 1;
assign nIOWr = 1;
assign nIdeBufEn = 1;
assign znDsack = 2'bZZ;

/*****************************************************************************/
endmodule