module bus030selects (
    input   wire [1:0]      cpuAddr,
    input   wire [1:0]      cpuSIZ,
    input   wire            cpuRWn,
    output  wire [3:0]      byteSELn,
    output  wire [1:0]      wordSELn
);

// data bus byte & word select signals
wire UUDn, UMDn, LMDn, LLDn, UDn, LDn;
always_comb begin
    UUDn = ~(
        cpuRWn | (~cpuAddr[0] & ~cpuAddr[1])
    );
    UMDn = ~(
        cpuRWn | (~cpuSIZ[0] & ~cpuAddr[1]) | (~cpuAddr[1] & cpuAddr[0]) |
        (cpuSIZ[1] & !cpuAddr[1])
    );
    LMDn = ~(
        cpuRWn | (~cpuAddr[0] & cpuAddr[1]) |
        (~cpuAddr[1] & ~cpuSIZ[0] & ~cpuSIZ[1]) | 
        (cpuSIZ[1] & cpuSIZ[0] & ~cpuAddr[1]) |
        (~cpuSIZ[0] & ~cpuAddr[1] & cpuAddr[0])
    );
    LLDn = ~(
        cpuRWn | (cpuAddr[0] & cpuSIZ[0] & cpuSIZ[1]) | (~cpuSIZ[0] & ~cpuSIZ[1]) | 
        (cpuAddr[0] & cpuAddr[1]) | (cpuAddr[1] & cpuSIZ[1])
    );
    UDn = ~(~cpuAddr[0] | cpuRWn);
    LDn = ~(~cpuSIZ[0] | cpuSIZ[1] | cpuAddr[0] | cpuRWn);
end

assign byteSELn[0] = LLDn;
assign byteSELn[1] = LMDn;
assign byteSELn[2] = UMDn;
assign byteSELn[3] = UUDn;

assign wordSELn[0] = LDn;
assign wordSELn[1] = UDn;

endmodule