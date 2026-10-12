// -----------------------------------------------------------------------------
// rv32i_regfile.v - 32 x 32-bit register file, 2 read ports, 1 write port
//
// * x0 always reads as zero
// * write-through bypass: a register written in WB this cycle is returned on
//   the read port in the same cycle, so ID never sees a stale value
//   (this replaces the "write first half / read second half" trick)
// -----------------------------------------------------------------------------
`timescale 1ns/1ps
`default_nettype none

module rv32i_regfile (
    input  wire        clk,
    input  wire [4:0]  raddr1,
    input  wire [4:0]  raddr2,
    output wire [31:0] rdata1,
    output wire [31:0] rdata2,
    input  wire        we,
    input  wire [4:0]  waddr,
    input  wire [31:0] wdata
);

    reg [31:0] regs [1:31];

    integer i;
    initial begin
        for (i = 1; i < 32; i = i + 1)
            regs[i] = 32'd0;
    end

    always @(posedge clk) begin
        if (we && waddr != 5'd0)
            regs[waddr] <= wdata;
    end

    wire bypass1 = we && (waddr != 5'd0) && (waddr == raddr1);
    wire bypass2 = we && (waddr != 5'd0) && (waddr == raddr2);

    assign rdata1 = (raddr1 == 5'd0) ? 32'd0 : bypass1 ? wdata : regs[raddr1];
    assign rdata2 = (raddr2 == 5'd0) ? 32'd0 : bypass2 ? wdata : regs[raddr2];

endmodule

`default_nettype wire
