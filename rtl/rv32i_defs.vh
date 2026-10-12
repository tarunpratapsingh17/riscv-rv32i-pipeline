// -----------------------------------------------------------------------------
// rv32i_defs.vh - shared encodings for the RV32I pipeline
// -----------------------------------------------------------------------------
`ifndef RV32I_DEFS_VH
`define RV32I_DEFS_VH

// ---- major opcodes (instr[6:0]) ----
`define OPC_LUI      7'b0110111
`define OPC_AUIPC    7'b0010111
`define OPC_JAL      7'b1101111
`define OPC_JALR     7'b1100111
`define OPC_BRANCH   7'b1100011
`define OPC_LOAD     7'b0000011
`define OPC_STORE    7'b0100011
`define OPC_OP_IMM   7'b0010011
`define OPC_OP       7'b0110011
`define OPC_MISC_MEM 7'b0001111   // FENCE / FENCE.I  -> executed as NOP
`define OPC_SYSTEM   7'b1110011   // ECALL / EBREAK / CSR -> executed as NOP

// ---- ALU control = {instr[30], funct3} style ----
`define ALU_ADD  4'b0000
`define ALU_SUB  4'b1000
`define ALU_SLL  4'b0001
`define ALU_SLT  4'b0010
`define ALU_SLTU 4'b0011
`define ALU_XOR  4'b0100
`define ALU_SRL  4'b0101
`define ALU_SRA  4'b1101
`define ALU_OR   4'b0110
`define ALU_AND  4'b0111

// ---- ALU operand A select ----
`define A_RS1   2'd0
`define A_PC    2'd1
`define A_ZERO  2'd2

// ---- write-back select ----
`define WB_ALU  2'd0
`define WB_MEM  2'd1
`define WB_PC4  2'd2

// ---- branch funct3 ----
`define F3_BEQ  3'b000
`define F3_BNE  3'b001
`define F3_BLT  3'b100
`define F3_BGE  3'b101
`define F3_BLTU 3'b110
`define F3_BGEU 3'b111

// ---- load / store funct3 ----
`define F3_B    3'b000
`define F3_H    3'b001
`define F3_W    3'b010
`define F3_BU   3'b100
`define F3_HU   3'b101

`define INSTR_NOP 32'h0000_0013   // addi x0, x0, 0

`endif
