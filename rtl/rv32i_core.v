// -----------------------------------------------------------------------------
// rv32i_core.v - 5-stage pipelined RV32I core
//
//   IF  -> ID  -> EX  -> MEM -> WB
//
//   * full RV32I base integer ISA + Zifencei (FENCE.I flushes the pipeline);
//     FENCE/ECALL/EBREAK/CSR execute as NOPs
//   * forwarding from EX/MEM and MEM/WB into EX, register-file write bypass
//   * 1-cycle load-use stall
//   * branches and jumps resolved in EX, static not-taken prediction:
//     a taken branch/jump flushes the 2 younger instructions (2-cycle penalty)
//   * separate instruction and data ports (Harvard), both combinational read
//   * retire port (valid/pc/instr) for tracing and CPI measurement
// -----------------------------------------------------------------------------
`timescale 1ns/1ps
`default_nettype none
`include "rv32i_defs.vh"

module rv32i_core #(
    parameter [31:0] RESET_PC = 32'h0000_0000
) (
    input  wire        clk,
    input  wire        rst_n,

    // instruction memory port
    output wire [31:0] imem_addr,
    input  wire [31:0] imem_rdata,

    // data memory port
    output wire [31:0] dmem_addr,
    output wire        dmem_re,
    output wire        dmem_we,
    output wire [3:0]  dmem_wstrb,
    output wire [31:0] dmem_wdata,
    input  wire [31:0] dmem_rdata,

    // retirement / debug
    output wire        retire_valid,
    output wire [31:0] retire_pc,
    output wire [31:0] retire_instr,
    output wire        illegal_instr
);

    // =========================================================================
    // Signals shared between stages
    // =========================================================================
    wire        stall;          // load-use hazard: freeze IF and ID, bubble into EX
    wire        redirect;       // taken branch / jump in EX
    wire [31:0] redirect_pc;

    // =========================================================================
    // IF - instruction fetch
    // =========================================================================
    reg [31:0] pc;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pc <= RESET_PC;
        else if (redirect)
            pc <= redirect_pc;
        else if (!stall)
            pc <= pc + 32'd4;
    end

    assign imem_addr = pc;

    // ---------------- IF/ID ----------------
    reg        if_id_valid;
    reg [31:0] if_id_pc;
    reg [31:0] if_id_instr;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            if_id_valid <= 1'b0;
            if_id_pc    <= 32'd0;
            if_id_instr <= `INSTR_NOP;
        end else if (redirect) begin           // wrong-path instruction
            if_id_valid <= 1'b0;
            if_id_instr <= `INSTR_NOP;
        end else if (!stall) begin
            if_id_valid <= 1'b1;
            if_id_pc    <= pc;
            if_id_instr <= imem_rdata;
        end
    end

    // =========================================================================
    // ID - decode and register read
    // =========================================================================
    wire [4:0] id_rs1 = if_id_instr[19:15];
    wire [4:0] id_rs2 = if_id_instr[24:20];
    wire [4:0] id_rd  = if_id_instr[11:7];

    wire        dec_reg_write, dec_mem_read, dec_mem_write;
    wire        dec_branch, dec_jal, dec_jalr, dec_fence_i;
    wire [1:0]  dec_alu_a_sel, dec_wb_sel;
    wire        dec_alu_b_imm;
    wire [3:0]  dec_alu_ctrl;
    wire        dec_uses_rs1, dec_uses_rs2, dec_illegal;
    wire [31:0] id_imm;
    wire [31:0] id_rs1_data, id_rs2_data;

    rv32i_decoder u_decoder (
        .instr     (if_id_instr),
        .reg_write (dec_reg_write),
        .mem_read  (dec_mem_read),
        .mem_write (dec_mem_write),
        .branch    (dec_branch),
        .jal       (dec_jal),
        .jalr      (dec_jalr),
        .fence_i   (dec_fence_i),
        .alu_a_sel (dec_alu_a_sel),
        .alu_b_imm (dec_alu_b_imm),
        .alu_ctrl  (dec_alu_ctrl),
        .wb_sel    (dec_wb_sel),
        .uses_rs1  (dec_uses_rs1),
        .uses_rs2  (dec_uses_rs2),
        .illegal   (dec_illegal)
    );

    rv32i_imm_gen u_imm_gen (
        .instr (if_id_instr),
        .imm   (id_imm)
    );

    // write-back signals (driven in the WB section below)
    wire        wb_we;
    wire [4:0]  wb_rd;
    wire [31:0] wb_wdata;

    rv32i_regfile u_regfile (
        .clk    (clk),
        .raddr1 (id_rs1),
        .raddr2 (id_rs2),
        .rdata1 (id_rs1_data),
        .rdata2 (id_rs2_data),
        .we     (wb_we),
        .waddr  (wb_rd),
        .wdata  (wb_wdata)
    );

    // ---------------- ID/EX ----------------
    reg        id_ex_valid;
    reg [31:0] id_ex_pc, id_ex_instr;
    reg [31:0] id_ex_rs1_data, id_ex_rs2_data, id_ex_imm;
    reg [4:0]  id_ex_rs1, id_ex_rs2, id_ex_rd;
    reg [2:0]  id_ex_funct3;
    reg        id_ex_reg_write, id_ex_mem_read, id_ex_mem_write;
    reg        id_ex_branch, id_ex_jal, id_ex_jalr, id_ex_fence_i;
    reg [1:0]  id_ex_alu_a_sel, id_ex_wb_sel;
    reg        id_ex_alu_b_imm;
    reg [3:0]  id_ex_alu_ctrl;
    reg        id_ex_illegal;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            id_ex_valid     <= 1'b0;
            id_ex_pc        <= 32'd0;
            id_ex_instr     <= `INSTR_NOP;
            id_ex_rs1_data  <= 32'd0;
            id_ex_rs2_data  <= 32'd0;
            id_ex_imm       <= 32'd0;
            id_ex_rs1       <= 5'd0;
            id_ex_rs2       <= 5'd0;
            id_ex_rd        <= 5'd0;
            id_ex_funct3    <= 3'd0;
            id_ex_reg_write <= 1'b0;
            id_ex_mem_read  <= 1'b0;
            id_ex_mem_write <= 1'b0;
            id_ex_branch    <= 1'b0;
            id_ex_jal       <= 1'b0;
            id_ex_jalr      <= 1'b0;
            id_ex_fence_i   <= 1'b0;
            id_ex_alu_a_sel <= `A_RS1;
            id_ex_alu_b_imm <= 1'b0;
            id_ex_alu_ctrl  <= `ALU_ADD;
            id_ex_wb_sel    <= `WB_ALU;
            id_ex_illegal   <= 1'b0;
        end else if (redirect || stall) begin
            // bubble: kill everything that has an architectural effect
            id_ex_valid     <= 1'b0;
            id_ex_instr     <= `INSTR_NOP;
            id_ex_reg_write <= 1'b0;
            id_ex_mem_read  <= 1'b0;
            id_ex_mem_write <= 1'b0;
            id_ex_branch    <= 1'b0;
            id_ex_jal       <= 1'b0;
            id_ex_jalr      <= 1'b0;
            id_ex_fence_i   <= 1'b0;
            id_ex_illegal   <= 1'b0;
        end else begin
            id_ex_valid     <= if_id_valid;
            id_ex_pc        <= if_id_pc;
            id_ex_instr     <= if_id_instr;
            id_ex_rs1_data  <= id_rs1_data;
            id_ex_rs2_data  <= id_rs2_data;
            id_ex_imm       <= id_imm;
            id_ex_rs1       <= id_rs1;
            id_ex_rs2       <= id_rs2;
            id_ex_rd        <= id_rd;
            id_ex_funct3    <= if_id_instr[14:12];
            id_ex_reg_write <= if_id_valid & dec_reg_write;
            id_ex_mem_read  <= if_id_valid & dec_mem_read;
            id_ex_mem_write <= if_id_valid & dec_mem_write;
            id_ex_branch    <= if_id_valid & dec_branch;
            id_ex_jal       <= if_id_valid & dec_jal;
            id_ex_jalr      <= if_id_valid & dec_jalr;
            id_ex_fence_i   <= if_id_valid & dec_fence_i;
            id_ex_alu_a_sel <= dec_alu_a_sel;
            id_ex_alu_b_imm <= dec_alu_b_imm;
            id_ex_alu_ctrl  <= dec_alu_ctrl;
            id_ex_wb_sel    <= dec_wb_sel;
            id_ex_illegal   <= if_id_valid & dec_illegal;
        end
    end

    // =========================================================================
    // EX - execute, forwarding, branch resolution
    // =========================================================================
    // EX/MEM and MEM/WB registers are declared here because EX forwards from them
    reg        ex_mem_valid;
    reg [31:0] ex_mem_pc, ex_mem_instr;
    reg [31:0] ex_mem_result, ex_mem_store_data;
    reg [4:0]  ex_mem_rd;
    reg [2:0]  ex_mem_funct3;
    reg        ex_mem_reg_write, ex_mem_mem_read, ex_mem_mem_write;
    reg [1:0]  ex_mem_wb_sel;

    reg        mem_wb_valid;
    reg [31:0] mem_wb_pc, mem_wb_instr;
    reg [31:0] mem_wb_wdata;
    reg [4:0]  mem_wb_rd;
    reg        mem_wb_reg_write;

    wire [1:0] fwd_a, fwd_b;

    rv32i_hazard_unit u_hazard (
        .id_valid       (if_id_valid),
        .id_rs1         (id_rs1),
        .id_rs2         (id_rs2),
        .id_uses_rs1    (dec_uses_rs1),
        .id_uses_rs2    (dec_uses_rs2),
        .ex_valid       (id_ex_valid),
        .ex_rs1         (id_ex_rs1),
        .ex_rs2         (id_ex_rs2),
        .ex_rd          (id_ex_rd),
        .ex_mem_read    (id_ex_mem_read),
        .mem_valid      (ex_mem_valid),
        .mem_reg_write  (ex_mem_reg_write),
        .mem_rd         (ex_mem_rd),
        .wb_valid       (mem_wb_valid),
        .wb_reg_write   (mem_wb_reg_write),
        .wb_rd          (mem_wb_rd),
        .fwd_a          (fwd_a),
        .fwd_b          (fwd_b),
        .load_use_stall (stall)
    );

    wire [31:0] rs1_val = (fwd_a == 2'b10) ? ex_mem_result :
                          (fwd_a == 2'b01) ? mem_wb_wdata  : id_ex_rs1_data;
    wire [31:0] rs2_val = (fwd_b == 2'b10) ? ex_mem_result :
                          (fwd_b == 2'b01) ? mem_wb_wdata  : id_ex_rs2_data;

    wire [31:0] alu_a = (id_ex_alu_a_sel == `A_PC)   ? id_ex_pc :
                        (id_ex_alu_a_sel == `A_ZERO) ? 32'd0    : rs1_val;
    wire [31:0] alu_b = id_ex_alu_b_imm ? id_ex_imm : rs2_val;
    wire [31:0] alu_y;

    rv32i_alu u_alu (
        .alu_ctrl (id_ex_alu_ctrl),
        .a        (alu_a),
        .b        (alu_b),
        .y        (alu_y)
    );

    // branch comparison
    reg br_cond;
    always @(*) begin
        case (id_ex_funct3)
            `F3_BEQ:  br_cond = (rs1_val == rs2_val);
            `F3_BNE:  br_cond = (rs1_val != rs2_val);
            `F3_BLT:  br_cond = ($signed(rs1_val) <  $signed(rs2_val));
            `F3_BGE:  br_cond = ($signed(rs1_val) >= $signed(rs2_val));
            `F3_BLTU: br_cond = (rs1_val <  rs2_val);
            `F3_BGEU: br_cond = (rs1_val >= rs2_val);
            default:  br_cond = 1'b0;
        endcase
    end

    wire [31:0] pc_plus4    = id_ex_pc + 32'd4;
    wire [31:0] br_target   = id_ex_pc + id_ex_imm;                  // branches, JAL
    /* verilator lint_off UNUSEDSIGNAL */      // bit 0 is dropped on purpose
    wire [31:0] jalr_sum    = rs1_val + id_ex_imm;
    /* verilator lint_on UNUSEDSIGNAL */
    wire [31:0] jalr_target = {jalr_sum[31:1], 1'b0};                 // clear bit 0

    // FENCE.I: re-fetch from pc+4. Any older store is in MEM this cycle and is
    // written before the re-fetch, so the new instruction bytes are picked up.
    assign redirect    = id_ex_valid && (id_ex_jal || id_ex_jalr || id_ex_fence_i ||
                                         (id_ex_branch && br_cond));
    assign redirect_pc = id_ex_fence_i ? pc_plus4    :
                         id_ex_jalr    ? jalr_target : br_target;

    wire [31:0] ex_result = (id_ex_wb_sel == `WB_PC4) ? pc_plus4 : alu_y;

    assign illegal_instr = id_ex_valid && id_ex_illegal;

    // ---------------- EX/MEM ----------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ex_mem_valid      <= 1'b0;
            ex_mem_pc         <= 32'd0;
            ex_mem_instr      <= `INSTR_NOP;
            ex_mem_result     <= 32'd0;
            ex_mem_store_data <= 32'd0;
            ex_mem_rd         <= 5'd0;
            ex_mem_funct3     <= 3'd0;
            ex_mem_reg_write  <= 1'b0;
            ex_mem_mem_read   <= 1'b0;
            ex_mem_mem_write  <= 1'b0;
            ex_mem_wb_sel     <= `WB_ALU;
        end else begin
            ex_mem_valid      <= id_ex_valid;
            ex_mem_pc         <= id_ex_pc;
            ex_mem_instr      <= id_ex_instr;
            ex_mem_result     <= ex_result;
            ex_mem_store_data <= rs2_val;        // forwarded store data
            ex_mem_rd         <= id_ex_rd;
            ex_mem_funct3     <= id_ex_funct3;
            ex_mem_reg_write  <= id_ex_reg_write;
            ex_mem_mem_read   <= id_ex_mem_read;
            ex_mem_mem_write  <= id_ex_mem_write;
            ex_mem_wb_sel     <= id_ex_wb_sel;
        end
    end

    // =========================================================================
    // MEM - data memory access
    // =========================================================================
    wire [31:0] lsu_wdata, lsu_load_data;
    wire [3:0]  lsu_wstrb;

    rv32i_lsu u_lsu (
        .funct3     (ex_mem_funct3),
        .byte_off   (ex_mem_result[1:0]),
        .store_data (ex_mem_store_data),
        .wdata      (lsu_wdata),
        .wstrb      (lsu_wstrb),
        .rdata_word (dmem_rdata),
        .load_data  (lsu_load_data)
    );

    assign dmem_addr  = ex_mem_result;
    assign dmem_re    = ex_mem_valid && ex_mem_mem_read;
    assign dmem_we    = ex_mem_valid && ex_mem_mem_write;
    assign dmem_wstrb = dmem_we ? lsu_wstrb : 4'b0000;
    assign dmem_wdata = lsu_wdata;

    wire [31:0] mem_stage_wdata = (ex_mem_wb_sel == `WB_MEM) ? lsu_load_data : ex_mem_result;

    // ---------------- MEM/WB ----------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_wb_valid     <= 1'b0;
            mem_wb_pc        <= 32'd0;
            mem_wb_instr     <= `INSTR_NOP;
            mem_wb_wdata     <= 32'd0;
            mem_wb_rd        <= 5'd0;
            mem_wb_reg_write <= 1'b0;
        end else begin
            mem_wb_valid     <= ex_mem_valid;
            mem_wb_pc        <= ex_mem_pc;
            mem_wb_instr     <= ex_mem_instr;
            mem_wb_wdata     <= mem_stage_wdata;
            mem_wb_rd        <= ex_mem_rd;
            mem_wb_reg_write <= ex_mem_reg_write;
        end
    end

    // =========================================================================
    // WB - register write-back
    // =========================================================================
    assign wb_we    = mem_wb_valid && mem_wb_reg_write;
    assign wb_rd    = mem_wb_rd;
    assign wb_wdata = mem_wb_wdata;

    assign retire_valid = mem_wb_valid;
    assign retire_pc    = mem_wb_pc;
    assign retire_instr = mem_wb_instr;

endmodule

`default_nettype wire
