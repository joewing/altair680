/**
 * @file fifo.v
 * @author Joe Wingbermuehle
 * @date 2007-09-29
 *
 * FIFO buffer.
 *
 */

/** FIFO.
 * @param rst_in Asynchronous reset.
 * @param clk_in Clock.
 * @param data_in Data to write.
 * @param write_in Set to write.
 * @param read_in Set to read.
 * @param data_out Data output.
 * @param empty_out Set if the FIFO is empty.
 * @param full_out Set if the FIFO is full.
 */
module fifo(rst_in, clk_in, data_in, write_in, read_in,
            data_out, empty_out, full_out);

   parameter word_bits = 8;      // Width in bits.
   parameter depth_bits = 3;     // Depth in bits.

   parameter depth = 1 << depth_bits;

   input wire rst_in;
   input wire clk_in;
   input wire [word_bits - 1:0] data_in;
   input wire write_in;
   input wire read_in;
   output wire [word_bits - 1:0] data_out;
   output wire empty_out;
   output wire full_out;

   reg [depth_bits - 1:0] read_offset;
   reg [depth_bits - 1:0] write_offset;
   reg [depth_bits : 0] data_size;
   reg [word_bits - 1:0] data [depth - 1:0];

   // FIFO size logic.
   always @(posedge clk_in) begin
      if (rst_in) begin
         data_size <= 0;
      end else begin
         if (read_in & ~write_in)      data_size <= data_size - 1;
         else if (write_in & ~read_in) data_size <= data_size + 1;
      end
   end

   // Write logic.
   always @(posedge clk_in) begin
      if (rst_in) begin
         write_offset <= 0;
      end else if (write_in) begin
         data[write_offset] <= data_in;
         write_offset <= write_offset + 1;
      end
   end

   // Read logic.
   wire [depth_bits - 1:0] next_read_offset = read_offset + 1;
   always @(posedge clk_in) begin
      if (rst_in) begin
         read_offset <= 0;
      end else if (read_in) begin
         read_offset <= next_read_offset;
      end
   end

   // Data output.
   assign data_out = data[read_offset];

   // Empty and full signals.
   assign empty_out = data_size == 0;
   assign full_out = data_size == depth;

endmodule

