/** Altair 680T.
 * Joe Wingbermuehle
 * 2007-09-03
 *
 * This provides a terminal interface to the altair680 module.
 */

module altair680t(rst_in, clk_in, ps2_data_in, ps2_clk_in, rxd_in,
                  data_out, txd_out,
                  red_out, green_out, blue_out, hsync_out, vsync_out);

   input wire rst_in;
   input wire clk_in;
   input wire ps2_data_in;
   input wire ps2_clk_in;
   input wire rxd_in;
   output wire [7:0] data_out;
   output wire txd_out;
   output wire red_out;
   output wire green_out;
   output wire blue_out;
   output wire hsync_out;
   output wire vsync_out;

   // The ALTAIR 680.
   wire run = 1;
   wire load = 1;
   wire nmi = 0;
   wire rxd;
   wire txd;
   altair680 altair(rst_in, clk_in, run, rxd, data_out, txd, load, nmi);

   // The terminal.
   wire term_rxd;
   wire term_txd;
   terminal term(rst_in, clk_in, term_rxd, term_txd, ps2_data_in, ps2_clk_in,
                 red_out, green_out, blue_out, hsync_out, vsync_out);

   // Connect the RXD and TXD signals.
   assign txd_out = txd;
   assign rxd = rxd_in & term_txd;
   assign term_rxd = txd;

endmodule

