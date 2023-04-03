/******************************************************************************
 * Wrap030 Glue
 * techav
 * 2021-12-26
 ******************************************************************************
 * Glue logic 
 *****************************************************************************/

module wrap030 (
    input   wire                nReset,     // primary system reset         1
    input   wire                nAS,        // address strobe               2
    input   wire                nDS,        // cpu data strobe              18
    input   wire                sysClk,     // primary system clock         43
    input   wire                RnW,        // cpu read/write signal        24
    input   wire                addr31,     // address bit 31               8
    input   wire [1:0]          cpuFC,      // cpu function code            11/12
    input   wire [1:0]          addrSiz,    // address bus 0/1              4/5
    input   wire [1:0]          siz,        // transfer size bits           9/21
    input   wire [2:0]          addrSel,    // address select bits (21:19)  36/34/33
    inout   wire                znAvec,     // cpu autovector request       16
    inout   wire                znSTERM,    // cpu sync cycle terminate     19
    inout   wire                znCiin,     // cache inhibit                20
    inout   wire                znBerr,     // cpu bus error                26
    inout   wire [1:0]          znDsack,    // cpu data strobe acknowledge  17/25
    output  wire                nRomCE,     // rom chip select              6
    output  wire                cpuClk,     // primary cpu clock            14
    output  wire                nAciaCE,    // acia chip enable signal      29
    output  wire                aciaClk,    // acia clock signal            31
    output  wire                nMemRd,     // memory read strobe           41
    output  wire                nMemWr,     // memory write strobe          40
    output  wire [3:0]          nRamCE      // ram chip select              28/27/37/39
);

wire [1:0]  nIntDsack;
wire        nIntBerr;

assign nIntDsack[0] = nMemDsack[0] & nAciaDsack[0];
assign nIntDsack[1] = nMemDsack[1] & nAciaDsack[1];

assign nIntBerr     = nMemBerr & nErrBerr;

assign cpuClk = sysClk;

always_comb begin
    if(!nIntDsack[0]) znDsack[0] <= 0;
    else znDsack[0] <= 1'bZ;

    if(!nIntDsack[1]) znDsack[1] <= 0;
    else znDsack[1] <= 1'bZ;

    if(!nIntBerr) znBerr <= 0;
    else znBerr <= 1'bZ;

    if(!nMemSterm) znSTERM <= 0;
    else znSTERM <= 1'bZ;

    if(!nAciaAciaCE) znCiin <= 0;
    else znCiin <= 1'bZ;
end

wire [1:0]  nMemDsack;
wire        nMemSterm,
            nMemBerr;
memcycle mainmem(
    // inputs
    .sysClk(sysClk),
    .nReset(nReset),
    .nAS(nAS),
    .addr31(addr31),
    .RnW(RnW),
    .addrSel(addrSel),
    .addrSiz(addrSiz),
    .siz(siz),
    // outputs
    .nRomCE(nRomCE),
    .nDsack(nMemDsack),
    .nSterm(nMemSterm),
    .nMemRd(nMemRd),
    .nMemWr(nMemWr),
    .nRamCE(nRamCE),
    .nBerr(nMemBerr)
);

wire [1:0]  nAciaDsack;
wire        nAciaAciaCE;
assign nAciaCE = nAciaAciaCE;
aciacycle maincom (
    // inputs
    .sysClk(sysClk),
    .nReset(nReset),
    .nAS(nAS),
    .addr31(addr31),
    .addrSel(addrSel),
    // outputs
    .nDsack(nAciaDsack),
    .aciaClk(aciaClk),
    .nAciaCE(nAciaAciaCE)
);

wire        nErrBerr,
            nErrSterm;
assign nErrSterm = znSTERM;
buserror mainberr (
    // inputs
    .sysClk(sysClk),
    .nReset(nReset),
    .nAS(nAS),
    .nDsack(znDsack),
    .nSterm(nErrSterm),
    .nAvec(znAvec),
    // outputs
    .nBerr(nErrBerr)
);

endmodule