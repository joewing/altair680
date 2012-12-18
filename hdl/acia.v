/* ACIA (Asynchronous Communications Interface Adaptor) for the Altair 680.
 * Joe Wingbermuehle
 * 2007-09-03
 * Uses the "uart" module.
 */

module acia(rst_in, clk_in, mode_in, read_in, write_in,
            bus_io, rxd_in, rxd_out, irq_out);

   input wire rst_in;
   input wire clk_in;
   input wire mode_in;     // 0 for status, 1 for data
   input wire read_in;
   input wire write_in;
   inout wire [7:0] bus_io;
   input wire rxd_in;
   output wire rxd_out;
   output wire irq_out;

   // The UART.
   wire rx_ready;
   wire tx_ready;
   reg start_send;
   wire [7:0] rx_data;
   reg [7:0] tx_data;
   uart u(rst_in, clk_in, tx_data, rx_data, start_send,
          rx_ready, tx_ready, rxd_in, rxd_out);

   // Control register.
   //    7 - Receiver IRQ
   //    6 \ Transmitter Control
   //    5 /
   //    4 \
   //    3 | Word select (we ignore this)
   //    2 /
   //    1 \ Counter division (we ignore this)
   //    0 /
   reg [7:0] control;
   wire [1:0] transmitter_irq = control[6:5];
   wire receiver_irq = control[7];

   // Transmitter control:
   //    00 - Disabled, RTS = 0
   //    01 - Enabled, RTS = 0
   //    10 - Disabled, RTS = 1
   //    11 - Disabled, sends break, RTS = 0

   // Assign status bits.
   //    7 - IRQ     - Interrupt Request.
   //    6 - PE      - Parity Error (always clear)
   //    5 - OVRN    - Overrun (always clear)
   //    4 - FE      - Framing Error (always clear)
   //    3 - !CTS    - Clear To Send (always clear)
   //    2 - !DCD    - Data Carrier Detect (always clear)
   //    1 - TDRE    - Ready to send data
   //    0 - RDRF    - Data ready to read
   wire [7:0] status;
   reg rx_buffer_ready;
   assign status[0] = rx_buffer_ready; // RDRF
   assign status[1] = tx_ready;        // TDRE
   assign status[2] = 0;               // !DCD
   assign status[3] = 0;               // !CTS
   assign status[4] = 0;               // FE
   assign status[5] = 0;               // OVRN
   assign status[6] = 0;               // PE
   assign status[7] = ~irq_out;        // !IRQ

   // Handle receives.
   reg [7:0] rx_buffer;
   always @(posedge clk_in) begin
      if (rst_in) begin
         rx_buffer_ready <= 0;
         rx_buffer <= 0;
      end else begin
         if (read_in & mode_in) begin
            rx_buffer_ready <= 0;
         end else if (rx_ready) begin
            rx_buffer_ready <= 1;
            rx_buffer <= rx_data;
         end
      end
   end

   // Write to the bus.
   assign bus_io = write_in ? 8'bz : (mode_in ? rx_buffer : status);

   // Handle transmits.
   always @(posedge clk_in) begin
      if (rst_in) begin
         start_send <= 0;
         tx_data <= 0;
      end else begin
         if (write_in & mode_in) begin
            start_send <= 1;
            tx_data <= {1'b0, bus_io[6:0]};  // We only allow 7-bit ASCII
         end else if (start_send) begin
            start_send <= 0;
         end
      end
   end

   // Writes to the control register.
   always @(posedge clk_in) begin
      if (rst_in) begin
         control <= 0;
      end else begin
         if (write_in & ~mode_in)
            control <= bus_io;
      end
   end

   // Assign the IRQ output.
   assign irq_out = ((transmitter_irq == 2'b01) & tx_ready)
                  | (receiver_irq & rx_ready);

endmodule


