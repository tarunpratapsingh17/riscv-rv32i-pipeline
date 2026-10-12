// -----------------------------------------------------------------------------
// rv32i_imm_gen.v - immediate generator for all RV32I instruction formats
// -----------------------------------------------------------------------------
`timescale 1ns/1ps
`default_nettype none
`include "rv32i_defs.vh"

module rv32i_imm_gen (
    input  wire [31:0] instr,
    output reg  [31:0] imm
);

    wire [31:0] imm_i = {{20{instr[31]}}, instr[31:20]};
    wire [31:0] imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};
    wire [31:0] imm_b = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
    wire [31:0] imm_u = {instr[31:12], 12'd0};
    wire [31:0] imm_j = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};

    always @(*) begin
        case (instr[6:0])
            `OPC_LUI, `OPC_AUIPC:          imm = imm_u;
            `OPC_JAL:                      imm = imm_j;
            `OPC_BRANCH:                   imm = imm_b;
            `OPC_STORE:                    imm = imm_s;
            default:                       imm = imm_i;   // OP-IMM, LOAD, JALR
        endcase
    end

endmodule

`default_nettype wire
