/**
 * @file uart.v
 * @author Joe Wingbermuehle
 * @date 2007-09-03
 *
 * UART supporting 8 bits, 1 stop bit, no parity.
 *
 */

`define BAUD_RATE       9600
`define CLOCK_FREQ      (50_000_000 / (1 << 2))    // 12.5 MHz
`define SAMPLE_BITS     4

`define SAMPLE_COUNT    (1 << `SAMPLE_BITS)
`define SAMPLE_RATE     (`BAUD_RATE * `SAMPLE_COUNT)
`define SAMPLE_ACC_BITS 16
`define BAUD_INC        (((`SAMPLE_RATE << (`SAMPLE_ACC_BITS - 4)) \
                         + (`CLOCK_FREQ >> 5)) / (`CLOCK_FREQ >> 4))


// Receiver.
module uart_rx(rst_in, clk_in, baud_in, data_out, ready_out, rxd_in);

   input wire rst_in;
   input wire clk_in;
   input wire baud_in;
   output wire [7:0] data_out;
   output wire ready_out;
   input wire rxd_in;

   // RX states.
   parameter RX_WAIT    = 0;  // Wait for a start bit.
   parameter RX_WAIT2   = 1;  // Make sure we are still at a start bit.
   parameter RX_START   = 2;  // Read the start bit.
   parameter RX_READ    = 3;  // Read data.
   parameter RX_STOP    = 4;  // Wait for the stop bit.

   // RX internal registers.
   reg [7:0] rx_buffer;
   reg [`SAMPLE_BITS - 1:0] rx_count;
   reg [`SAMPLE_BITS - 1:0] rx_offset;
   reg [4:0] rx_state;
   reg [3:0] rx_bits;

   // RX counter.
   always @(posedge clk_in) begin
      if (rst_in) begin
         rx_count <= 0;
      end else begin
         if (baud_in) rx_count <= rx_count + 1;
      end
   end

   // RX strobe.
   wire rx_strobe = (rx_count == rx_offset) & baud_in;

   // RX offset.
   always @(posedge clk_in) begin
      if (rst_in) begin
         rx_offset <= 0;
      end else begin
         if (rx_state[RX_WAIT]) rx_offset <= rx_count + (`SAMPLE_COUNT / 2);
      end
   end

   // Keep track of how many bits have been read.
   always @(posedge clk_in) begin
      if (rst_in) begin
         rx_bits <= 0;
      end else begin
         if (rx_strobe) begin
            rx_bits <= rx_state[RX_READ] ? rx_bits + 1 : 0;
         end
      end
   end

   // State logic.
   always @(posedge clk_in) begin
      if (rst_in) begin
         rx_state <= 1 << RX_WAIT;
      end else begin
         case (1'b1)
            rx_state[RX_WAIT2]:
               if (~rxd_in)         rx_state <= 1 << RX_START;
               else                 rx_state <= 1 << RX_WAIT;
            rx_state[RX_START]:
               if (rx_strobe)       rx_state <= 1 << RX_READ;
               else                 rx_state <= 1 << RX_START;
            rx_state[RX_READ]:
               if (rx_bits == 8)    rx_state <= 1 << RX_STOP;
               else                 rx_state <= 1 << RX_READ;
            rx_state[RX_STOP]:
               if (rxd_in)          rx_state <= 1 << RX_WAIT;
               else                 rx_state <= 1 << RX_STOP;
            default:
               if (~rxd_in)         rx_state <= 1 << RX_WAIT2;
               else                 rx_state <= 1 << RX_WAIT;
         endcase
      end
   end

   // RX buffer.
   always @(posedge clk_in) begin
      if (rst_in) begin
         rx_buffer <= 0;
      end else if (baud_in) begin
         if (rx_state[RX_READ]) begin
            if (rx_strobe) rx_buffer <= {rxd_in, rx_buffer[7:1]};
         end else begin
            rx_buffer <= 0;
         end
      end
   end

   // RX data ready and data output.
   assign data_out = rx_buffer;
   assign ready_out = rx_bits == 7 && rx_strobe;

endmodule

// Transmitter.
module uart_tx(rst_in, clk_in, baud_in, data_in, ready_in, ready_out, txd_out);

   input wire rst_in;
   input wire clk_in;
   input wire baud_in;
   input wire [7:0] data_in;
   input wire ready_in;
   output wire ready_out;
   output reg txd_out;

   // Since baud_clk is actually `SAMPLE_RATE, we need to divide it.
   reg [`SAMPLE_BITS - 1:0] clock_counter;
   always @(posedge clk_in) begin
      if (rst_in) begin
         clock_counter <= 0;
      end else begin
         if (baud_in) clock_counter <= clock_counter + 1;
      end
   end
   wire txd_clk = (clock_counter == 0) && baud_in;

   // This is the bit we are currently sending.
   // Note that 0 means we are idle, 1 is the start bit,
   // values 2 through 9 are the data bits, and 10 is the stop bit.
   reg [3:0] write_count;

   // Write count.
   always @(posedge clk_in) begin
      if (rst_in) begin
         write_count <= 0;
      end else begin
         if (ready_in && write_count == 0) begin
            write_count <= 1;
         end else if (txd_clk && write_count != 0) begin
            write_count <= write_count == 10 ? 0 : write_count + 1;
         end
      end
   end

   // txd_out.
   always @(posedge clk_in) begin
      if (rst_in) begin
         txd_out <= 1;
      end else begin
         if (txd_clk) begin
            case (write_count)
               1:          txd_out <= 0;
               2:          txd_out <= data_in[0];
               3:          txd_out <= data_in[1];
               4:          txd_out <= data_in[2];
               5:          txd_out <= data_in[3];
               6:          txd_out <= data_in[4];
               7:          txd_out <= data_in[5];
               8:          txd_out <= data_in[6];
               9:          txd_out <= data_in[7];
               default:    txd_out <= 1;
            endcase
         end
      end
   end

   // Determine if we can accept a byte to send.
   assign ready_out = write_count == 0;

endmodule

// The UART.
module uart
    (rst_in,         // Reset.
     clk_in,         // Clock.
     data_in,        // Data input.
     data_out,       // Data output.
     send_in,        // Start sending.
     rx_ready_out,   // Ready to read.
     tx_ready_out,   // Ready to send.
     rxd_in,         // Serial RxD.
     txd_out);       // Serial TxD.

   input wire rst_in;
   input wire clk_in;
   input wire [7:0] data_in;
   output wire [7:0] data_out;
   input wire send_in;
   output reg rx_ready_out;
   output wire tx_ready_out;
   input wire rxd_in;
   output wire txd_out;

   // The baud clock logic.
   reg [`SAMPLE_ACC_BITS:0] clock_counter;
   wire baud_clk = clock_counter[`SAMPLE_ACC_BITS];
   always @(posedge clk_in) begin
      if (rst_in) begin
         clock_counter <= 0;
      end else begin 
         clock_counter <= clock_counter[`SAMPLE_ACC_BITS - 1:0] + `BAUD_INC;
      end
   end

   // RX side.
   wire rx_ready;
   uart_rx rx(rst_in, clk_in, baud_clk, data_out, rx_ready, rxd_in);

   // Only signal that a byte is ready to read for one clock.
   reg rx_ready_sent;
   always @(posedge clk_in) begin
      if (rst_in) begin
         rx_ready_out <= 0;
         rx_ready_sent <= 0;
      end else begin
         if (rx_ready & ~rx_ready_sent) begin
            rx_ready_out <= 1;
            rx_ready_sent <= 1;
         end else begin
            if (~rx_ready) rx_ready_sent <= 0;
            rx_ready_out <= 0;
         end
      end
   end

   // TX side.
   uart_tx tx(rst_in, clk_in, baud_clk, data_in, send_in,
              tx_ready_out, txd_out);

endmodule

