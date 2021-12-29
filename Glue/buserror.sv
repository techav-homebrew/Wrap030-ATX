/******************************************************************************
 * Bus Error
 * techav
 * 2021-12-26
 ******************************************************************************
 * Generates Bus Error if bus cycle isn't otherwise terminated
 *****************************************************************************/

module buserror (
    input   wire                sysClk,     // primary system clock
    input   wire                nReset,      // primary system reset
    input   wire                nAS,        // address strobe
    input   logic [1:0]         nDsack,     // DS acknowledge
    input   wire                nSterm,     // Synchronous bus term
    input   wire                nAvec,      // AutoVector termination
    output  wire                nBerr       // bus error
);

logic [5:0] cycleCount;

reg nBERRinternal;

assign nBerr = nBERRinternal;

always @(posedge sysClk or negedge nReset) begin
    if(!nReset) begin
        // system reset. reset count to 0 and deassert BERR
        cycleCount <= 0;
        nBERRinternal <= 1;
    end else if(nAS) begin
        // no active CPU cycle. reset count to 0 and deassert BERR 
        cycleCount <= 0;
        nBERRinternal <= 1;
    end else if(cycleCount == 6'h3F &&
            nDsack[1] && nDsack[0] &&
            nSterm && nAvec) begin
        // timer has expired. hold count where it is and assert BERR
        cycleCount <= cycleCount;
        nBERRinternal <= 0;
    end else begin
        // active bus cycle. increment counter
        cycleCount <= cycleCount + 6'h1;
        nBERRinternal <= 1;
    end
end

endmodule