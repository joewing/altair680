/** Terminal interface.
 * Joe Wingbermuehle
 * 2007-09-03
 */

module terminal(rst_in, clk_in, rxd_in, txd_out, ps2_data_in, ps2_clk_in,
                red_out, green_out, blue_out, hsync_out, vsync_out);

   input wire rst_in;
   input wire clk_in;
   input wire rxd_in;
   output wire txd_out;
   input wire ps2_data_in;
   input wire ps2_clk_in;
   output wire red_out;
   output wire green_out;
   output wire blue_out;
   output wire hsync_out;
   output wire vsync_out;

   // Generate the UART clock (12.5 MHz from 50 MHz).
   wire uart_clk;
   wire clk0;
   clock125 uc(clk_in, uart_clk, clk0);

   // UART (12.5 MHz).
   wire [7:0] rxd_data;
   reg [7:0] txd_data;
   reg start_send;
   wire rx_ready;
   wire tx_ready;
   uart rt(rst_in, uart_clk, txd_data, rxd_data, start_send,
          rx_ready, tx_ready, rxd_in, txd_out);

   // Keyboard (12.5 MHz).
   wire [7:0] kb_data;
   wire kb_ready;
   keyboard kb(rst_in, uart_clk, ps2_data_in, ps2_clk_in, kb_data, kb_ready);

   // Connect the keyboard and UART.
   reg kb_state;
   always @(posedge uart_clk) begin
      if (rst_in) begin
         start_send <= 0;
         txd_data <= 0;
         kb_state <= 0;
      end else if (tx_ready) begin
         if (kb_state) begin
            kb_state <= 0;
            txd_data <= 8'h0A;
            start_send <= 1;
         end else if (kb_ready) begin
            if (kb_data == 8'h0A) begin
               txd_data <= 8'h0D;
               kb_state <= 1;
            end else begin
               txd_data <= kb_data;
            end
            start_send <= 1;
         end else begin
            start_send <= 0;
         end
      end else begin
         start_send <= 0;
      end
   end

   // Display (50 MHz).
   wire [6:0] disp_data;
   wire disp_write;
   wire disp_ready;
   display disp(rst_in, clk_in, disp_data, disp_write, disp_ready,
                red_out, green_out, blue_out, hsync_out, vsync_out);

   // FIFO to act as a buffer between the display and UART.
   // Note that the display should be able to keep up with the UART
   // unless it is scrolling.
   reg [6:0] fifo_data;
   reg fifo_write;
   wire fifo_empty;
   wire fifo_full;
   fifo #(.word_bits(7))
      disp_fifo(rst_in, clk_in, fifo_data, fifo_write, disp_write,
                disp_data, fifo_empty, fifo_full);
   assign disp_write = disp_ready & ~fifo_empty;

   // Connect the display FIFO and the UART.
   // Note that the display FIFO (50 MHz) runs 4x faster than
   // the UART (12.5 MHz).
   reg [1:0] state;
   always @(posedge clk_in) begin
      if (rst_in) begin
         state <= 0;
         fifo_write <= 0;
         fifo_data <= 0;
      end else begin
         case (state)
            1, 2, 3:
               begin
                  state <= state + 1;
                  fifo_write <= 0;
               end
            default:
               if (rx_ready & ~fifo_full) begin
                  fifo_write <= 1;
                  fifo_data <= rxd_data;
                  state <= 1;
               end else begin
                  fifo_write <= 0;
               end
         endcase
      end
   end

endmodule

