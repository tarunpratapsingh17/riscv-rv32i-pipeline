// -----------------------------------------------------------------------------
// tb_rv32i.v - program-driven testbench for rv32i_core
//
// * 64 KB unified memory (instruction port + data port), loaded from a hex file
// * memory-mapped test interface:
//     0x0001_0000  TOHOST  : write 1 = PASS, write (n<<1)|1 = FAIL in test n
//     0x0001_0004  PUTCHAR : write a byte to print it on the console
// * reports cycles, retired instructions and CPI
// * fails on: illegal instruction, out-of-range access, X on control signals,
//   timeout
//
// Plusargs:
//   +hex=<file>        program image (required)
//   +max_cycles=<n>    timeout (default 2,000,000)
//   +trace             print every retired instruction
//   +vcd               dump waveform to tb_rv32i.vcd
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

module tb_rv32i;

    localparam MEM_WORDS   = 16384;            // 64 KB
    localparam TOHOST_ADDR = 32'h0001_0000;
    localparam PUTC_ADDR   = 32'h0001_0004;

    reg clk = 1'b0;
    reg rst_n = 1'b0;
    always #5 clk = ~clk;                      // 100 MHz

    // ---------------- DUT ----------------
    wire [31:0] imem_addr, imem_rdata;
    wire [31:0] dmem_addr, dmem_wdata, dmem_rdata;
    wire        dmem_re, dmem_we;
    wire [3:0]  dmem_wstrb;
    wire        retire_valid, illegal_instr;
    wire [31:0] retire_pc, retire_instr;

    rv32i_core dut (
        .clk           (clk),
        .rst_n         (rst_n),
        .imem_addr     (imem_addr),
        .imem_rdata    (imem_rdata),
        .dmem_addr     (dmem_addr),
        .dmem_re       (dmem_re),
        .dmem_we       (dmem_we),
        .dmem_wstrb    (dmem_wstrb),
        .dmem_wdata    (dmem_wdata),
        .dmem_rdata    (dmem_rdata),
        .retire_valid  (retire_valid),
        .retire_pc     (retire_pc),
        .retire_instr  (retire_instr),
        .illegal_instr (illegal_instr)
    );

    // ---------------- memory ----------------
    reg [31:0] mem [0:MEM_WORDS-1];

    wire imem_in_range = (imem_addr < 4*MEM_WORDS);
    wire dmem_in_range = (dmem_addr < 4*MEM_WORDS);
    wire dmem_is_mmio  = (dmem_addr == TOHOST_ADDR) || (dmem_addr == PUTC_ADDR);

    assign imem_rdata = imem_in_range ? mem[imem_addr[15:2]] : 32'h0000_0013;
    assign dmem_rdata = dmem_in_range ? mem[dmem_addr[15:2]] : 32'd0;

    // ---------------- bookkeeping ----------------
    reg [8*256-1:0] hexfile;
    integer max_cycles;
    integer cycles  = 0;
    integer instret = 0;
    reg     trace   = 1'b0;
    reg     done    = 1'b0;
    integer i;

    task finish_test;
        input pass;
        input [31:0] code;
        real cpi;
        begin
            cpi = (instret > 0) ? (1.0 * cycles) / instret : 0.0;
            if (pass)
                $display("RESULT: PASS  cycles=%0d instret=%0d cpi=%0.3f", cycles, instret, cpi);
            else
                $display("RESULT: FAIL  code=%0d  cycles=%0d instret=%0d cpi=%0.3f",
                         code, cycles, instret, cpi);
            done = 1'b1;
            $finish;
        end
    endtask

    always @(posedge clk) begin
        if (rst_n && !done) begin
            cycles = cycles + 1;

            if (retire_valid) begin
                instret = instret + 1;
                if (trace)
                    $display("[%8d] pc=%08h instr=%08h", cycles, retire_pc, retire_instr);
            end

            if (illegal_instr) begin
                $display("ERROR: illegal instruction %08h at pc=%08h", dut.id_ex_instr, dut.id_ex_pc);
                finish_test(1'b0, 32'hFFFF_FFFF);
            end

            if (^{dut.redirect, dut.stall, dmem_we, dmem_re} === 1'bx) begin
                $display("ERROR: X on pipeline control at cycle %0d", cycles);
                finish_test(1'b0, 32'hFFFF_FFFE);
            end

            // data writes
            if (dmem_we) begin
                if (dmem_addr == TOHOST_ADDR) begin
                    if (dmem_wdata == 32'd1) finish_test(1'b1, 0);
                    else                    finish_test(1'b0, dmem_wdata >> 1);
                end else if (dmem_addr == PUTC_ADDR) begin
                    $write("%c", dmem_wdata[7:0]);
                end else if (dmem_in_range) begin
                    if (dmem_wstrb[0]) mem[dmem_addr[15:2]][7:0]   <= dmem_wdata[7:0];
                    if (dmem_wstrb[1]) mem[dmem_addr[15:2]][15:8]  <= dmem_wdata[15:8];
                    if (dmem_wstrb[2]) mem[dmem_addr[15:2]][23:16] <= dmem_wdata[23:16];
                    if (dmem_wstrb[3]) mem[dmem_addr[15:2]][31:24] <= dmem_wdata[31:24];
                end else begin
                    $display("ERROR: store to unmapped address %08h", dmem_addr);
                    finish_test(1'b0, 32'hFFFF_FFFD);
                end
            end

            if (dmem_re && !dmem_in_range && !dmem_is_mmio) begin
                $display("ERROR: load from unmapped address %08h", dmem_addr);
                finish_test(1'b0, 32'hFFFF_FFFC);
            end

            if (cycles >= max_cycles) begin
                $display("ERROR: timeout after %0d cycles (pc=%08h)", cycles, imem_addr);
                finish_test(1'b0, 32'hFFFF_FFFB);
            end
        end
    end

    // ---------------- start-up ----------------
    initial begin
        for (i = 0; i < MEM_WORDS; i = i + 1)
            mem[i] = 32'h0000_0013;

        if (!$value$plusargs("hex=%s", hexfile)) begin
            $display("ERROR: no program given, use +hex=<file>");
            $finish;
        end
        $readmemh(hexfile, mem);

        if (!$value$plusargs("max_cycles=%d", max_cycles))
            max_cycles = 2000000;
        if ($test$plusargs("trace"))
            trace = 1'b1;
        if ($test$plusargs("vcd")) begin
            $dumpfile("tb_rv32i.vcd");
            $dumpvars(0, tb_rv32i);
        end

        repeat (3) @(posedge clk);
        @(negedge clk) rst_n = 1'b1;
    end

endmodule
