// -----------------------------------------------------------------------------
// rv32i_hazard_unit.v - data-hazard handling
//
// Forwarding (EX stage operands):
//   fwd = 2'b10 : take the value from EX/MEM  (instruction 1 ahead)
//   fwd = 2'b01 : take the value from MEM/WB  (instruction 2 ahead)
//   fwd = 2'b00 : use the value read from the register file in ID
//   EX/MEM has priority because it holds the newer value.
//   (Instructions 3 ahead are covered by the register-file bypass.)
//
// Load-use stall:
//   A load's data only exists at the end of MEM, so an instruction that needs
//   it in the very next cycle cannot be forwarded in time. The ID instruction
//   is held for one cycle and a bubble is inserted into EX; after that the
//   value is forwarded from MEM/WB.
// -----------------------------------------------------------------------------
`timescale 1ns/1ps
`default_nettype none

module rv32i_hazard_unit (
    // instruction in ID
    input  wire       id_valid,
    input  wire [4:0] id_rs1,
    input  wire [4:0] id_rs2,
    input  wire       id_uses_rs1,
    input  wire       id_uses_rs2,
    // instruction in EX
    input  wire       ex_valid,
    input  wire [4:0] ex_rs1,
    input  wire [4:0] ex_rs2,
    input  wire [4:0] ex_rd,
    input  wire       ex_mem_read,
    // instruction in MEM
    input  wire       mem_valid,
    input  wire       mem_reg_write,
    input  wire [4:0] mem_rd,
    // instruction in WB
    input  wire       wb_valid,
    input  wire       wb_reg_write,
    input  wire [4:0] wb_rd,
    // outputs
    output wire [1:0] fwd_a,
    output wire [1:0] fwd_b,
    output wire       load_use_stall
);

    wire mem_fwd_ok = mem_valid && mem_reg_write && (mem_rd != 5'd0);
    wire wb_fwd_ok  = wb_valid  && wb_reg_write  && (wb_rd  != 5'd0);

    assign fwd_a = (mem_fwd_ok && mem_rd == ex_rs1) ? 2'b10 :
                   (wb_fwd_ok  && wb_rd  == ex_rs1) ? 2'b01 : 2'b00;

    assign fwd_b = (mem_fwd_ok && mem_rd == ex_rs2) ? 2'b10 :
                   (wb_fwd_ok  && wb_rd  == ex_rs2) ? 2'b01 : 2'b00;

    assign load_use_stall = id_valid && ex_valid && ex_mem_read && (ex_rd != 5'd0) &&
                            ((id_uses_rs1 && id_rs1 == ex_rd) ||
                             (id_uses_rs2 && id_rs2 == ex_rd));

endmodule

`default_nettype wire
