// -----------------------------------------------------------------------------
// rv32i_decoder.v - main control decoder (ID stage)
//
// Produces every control signal the later stages need.
//   * FENCE.I (Zifencei) is executed as a jump to pc+4, which flushes the
//     instructions fetched behind it, so self-modifying code is seen correctly.
//   * FENCE, ECALL, EBREAK and CSR instructions are executed as NOPs (this core
//     has no privileged mode or CSRs; memory is already strongly ordered).
//   * Anything else is flagged as illegal.
// -----------------------------------------------------------------------------
`timescale 1ns/1ps
`default_nettype none
`include "rv32i_defs.vh"

module rv32i_decoder (
    /* verilator lint_off UNUSEDSIGNAL */      // register fields are decoded elsewhere
    input  wire [31:0] instr,
    /* verilator lint_on UNUSEDSIGNAL */
    output reg         reg_write,
    output reg         mem_read,
    output reg         mem_write,
    output reg         branch,
    output reg         jal,
    output reg         jalr,
    output reg         fence_i,
    output reg  [1:0]  alu_a_sel,
    output reg         alu_b_imm,     // 1: operand B is the immediate
    output reg  [3:0]  alu_ctrl,
    output reg  [1:0]  wb_sel,
    output reg         uses_rs1,
    output reg         uses_rs2,
    output reg         illegal
);

    wire [6:0] opcode = instr[6:0];
    wire [2:0] funct3 = instr[14:12];
    wire [6:0] funct7 = instr[31:25];

    always @(*) begin
        // defaults: a NOP
        reg_write = 1'b0;
        mem_read  = 1'b0;
        mem_write = 1'b0;
        branch    = 1'b0;
        jal       = 1'b0;
        jalr      = 1'b0;
        fence_i   = 1'b0;
        alu_a_sel = `A_RS1;
        alu_b_imm = 1'b0;
        alu_ctrl  = `ALU_ADD;
        wb_sel    = `WB_ALU;
        uses_rs1  = 1'b0;
        uses_rs2  = 1'b0;
        illegal   = 1'b0;

        case (opcode)
            `OPC_LUI: begin
                reg_write = 1'b1;
                alu_a_sel = `A_ZERO;
                alu_b_imm = 1'b1;
            end

            `OPC_AUIPC: begin
                reg_write = 1'b1;
                alu_a_sel = `A_PC;
                alu_b_imm = 1'b1;
            end

            `OPC_JAL: begin
                reg_write = 1'b1;
                jal       = 1'b1;
                wb_sel    = `WB_PC4;
            end

            `OPC_JALR: begin
                reg_write = 1'b1;
                jalr      = 1'b1;
                wb_sel    = `WB_PC4;
                uses_rs1  = 1'b1;
                illegal   = (funct3 != 3'b000);
            end

            `OPC_BRANCH: begin
                branch   = 1'b1;
                uses_rs1 = 1'b1;
                uses_rs2 = 1'b1;
                illegal  = (funct3 == 3'b010) || (funct3 == 3'b011);
            end

            `OPC_LOAD: begin
                reg_write = 1'b1;
                mem_read  = 1'b1;
                alu_b_imm = 1'b1;
                wb_sel    = `WB_MEM;
                uses_rs1  = 1'b1;
                illegal   = (funct3 == 3'b011) || (funct3 == 3'b110) || (funct3 == 3'b111);
            end

            `OPC_STORE: begin
                mem_write = 1'b1;
                alu_b_imm = 1'b1;
                uses_rs1  = 1'b1;
                uses_rs2  = 1'b1;
                illegal   = (funct3 > 3'b010);
            end

            `OPC_OP_IMM: begin
                reg_write = 1'b1;
                alu_b_imm = 1'b1;
                uses_rs1  = 1'b1;
                // only SRAI uses instr[30]; for ADDI etc. it is part of the immediate
                alu_ctrl  = {(funct3 == 3'b101) & instr[30], funct3};
                if (funct3 == 3'b001)
                    illegal = (funct7 != 7'b0000000);
                else if (funct3 == 3'b101)
                    illegal = (funct7 != 7'b0000000) && (funct7 != 7'b0100000);
            end

            `OPC_OP: begin
                reg_write = 1'b1;
                uses_rs1  = 1'b1;
                uses_rs2  = 1'b1;
                alu_ctrl  = {instr[30], funct3};
                illegal   = !((funct7 == 7'b0000000) ||
                              (funct7 == 7'b0100000 && (funct3 == 3'b000 || funct3 == 3'b101)));
            end

            `OPC_MISC_MEM: begin
                fence_i = (funct3 == 3'b001);   // FENCE (000) is a NOP
            end

            `OPC_SYSTEM: begin
                // ECALL / EBREAK / CSR*: no architectural effect on this core
            end

            default: illegal = 1'b1;
        endcase

        if (illegal) begin          // make sure an illegal instruction does nothing
            reg_write = 1'b0;
            mem_read  = 1'b0;
            mem_write = 1'b0;
            branch    = 1'b0;
            jal       = 1'b0;
            jalr      = 1'b0;
            fence_i   = 1'b0;
        end
    end

endmodule

`default_nettype wire
