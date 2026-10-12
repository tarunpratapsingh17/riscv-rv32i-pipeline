// -----------------------------------------------------------------------------
// rv32i_alu.v - RV32I integer ALU (purely combinational)
// -----------------------------------------------------------------------------
`timescale 1ns/1ps
`default_nettype none
`include "rv32i_defs.vh"

module rv32i_alu (
    input  wire [3:0]  alu_ctrl,
    input  wire [31:0] a,
    input  wire [31:0] b,
    output reg  [31:0] y
);

    wire [4:0] shamt = b[4:0];

    always @(*) begin
        case (alu_ctrl)
            `ALU_ADD:  y = a + b;
            `ALU_SUB:  y = a - b;
            `ALU_SLL:  y = a << shamt;
            `ALU_SLT:  y = {31'd0, $signed(a) < $signed(b)};
            `ALU_SLTU: y = {31'd0, a < b};
            `ALU_XOR:  y = a ^ b;
            `ALU_SRL:  y = a >> shamt;
            `ALU_SRA:  y = $unsigned($signed(a) >>> shamt);
            `ALU_OR:   y = a | b;
            `ALU_AND:  y = a & b;
            default:   y = a + b;
        endcase
    end

endmodule

`default_nettype wire
