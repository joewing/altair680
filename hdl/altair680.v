/** Altair 680 top level.
 * Joe Wingbermuehle
 * 2007-09-03
 *
 * Uses the "mmu" and "m6800" modules.
 *
 * Inputs:
 *    rst   - Reset
 *    clk   - Clock.
 *    run   - 0 to halt, 1 to run.
 *    dep   - Deposit.
 *    data  - 8 bits, data in.
 *    addr  - 16 bits, address in.
 *    rxd   - Receive data.
 *
 * Outputs:
 *    hlt   - Halt indicator.
 *    run   - Run indicator.
 *    data  - 8 bits, data out.
 *    addr  - 16 bits, address out.
 *    txd   - Transmit data.
 *
 */

module altair680(rst_in, clk_in, run_in, rxd_in, data_out, txd_out,
                 load_in, nmi_in);

   input wire rst_in;
   input wire clk_in;
   input wire run_in;
   input wire rxd_in;
   output wire [7:0] data_out;
   output wire txd_out;
   input wire load_in;
   input wire nmi_in;

   // Note that the MMU must be clocked 2x higher to allow the
   // address to appear before the read.
   // Clock the MMU at 25 MHz.
   wire mem_clk;
   wire mclk0;
   clock25 mc(clk_in, mem_clk, mclk0);

   // Clock the CPU at 12.5 MHz.
   wire slow_clk;
   wire cclk0;
   clock125 cc(clk_in, slow_clk, cclk0);

   wire blink = 0;

   // Memory management.
   wire mem_write;
   wire [15:0] mem_addr;
   wire [7:0] bus;
   wire mmu_ready;
   wire irq;
   mmu m(rst_in, mem_clk, mem_write, mem_addr, bus,
         rxd_in, txd_out, load_in, mmu_ready, irq);

   // CPU.
   wire cpu_clk = slow_clk;
   wire cpu_rst = rst_in | ~mmu_ready;
   m6800 cpu(cpu_clk, cpu_rst, mem_addr, mem_write, bus, irq, nmi_in);

   // Determine what to output (for debugging).
   assign data_out = {blink, run_in, rst_in, load_in,
                      mmu_ready, mem_write, rxd_in, txd_out};

endmodule

