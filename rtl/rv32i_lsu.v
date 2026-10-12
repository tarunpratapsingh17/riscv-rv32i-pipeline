// -----------------------------------------------------------------------------
// rv32i_lsu.v - load/store alignment (MEM stage, combinational)
//
// Memory is 32 bits wide and byte-addressed (little endian).
//   Stores: replicate the byte/half across the word and raise only the byte
//           strobes being written.
//   Loads:  shift the addressed byte/half down and sign- or zero-extend.
// Misaligned half/word accesses are not supported (as allowed by the spec for
// a core without a trap handler); the riscv-tests ma_data test is not run.
// -----------------------------------------------------------------------------
`timescale 1ns/1ps
`default_nettype none
`include "rv32i_defs.vh"

module rv32i_lsu (
    input  wire [2:0]  funct3,
    input  wire [1:0]  byte_off,      // addr[1:0]
    input  wire [31:0] store_data,    // rs2
    output reg  [31:0] wdata,
    output reg  [3:0]  wstrb,
    input  wire [31:0] rdata_word,    // word read from memory
    output reg  [31:0] load_data
);

    // ---------------- stores ----------------
    always @(*) begin
        case (funct3[1:0])
            2'b00: begin   // SB
                wdata = {4{store_data[7:0]}};
                wstrb = 4'b0001 << byte_off;
            end
            2'b01: begin   // SH
                wdata = {2{store_data[15:0]}};
                wstrb = byte_off[1] ? 4'b1100 : 4'b0011;
            end
            default: begin // SW
                wdata = store_data;
                wstrb = 4'b1111;
            end
        endcase
    end

    // ---------------- loads ----------------
    /* verilator lint_off UNUSEDSIGNAL */      // only the low half-word is used
    wire [31:0] shifted = rdata_word >> {byte_off, 3'b000};
    /* verilator lint_on UNUSEDSIGNAL */

    always @(*) begin
        case (funct3)
            `F3_B:   load_data = {{24{shifted[7]}},  shifted[7:0]};
            `F3_H:   load_data = {{16{shifted[15]}}, shifted[15:0]};
            `F3_BU:  load_data = {24'd0, shifted[7:0]};
            `F3_HU:  load_data = {16'd0, shifted[15:0]};
            default: load_data = rdata_word;          // LW
        endcase
    end

endmodule

`default_nettype wire
