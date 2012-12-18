/** RAM for the Altair 680.
 * Joe Wingbermuehle
 * 2007-09-03
 */

module ram(clk_in, write_in, addr_in, bus_io);

   input wire clk_in;
   input wire write_in;
   input wire [14 - 1:0] addr_in;
   inout wire [7:0] bus_io;

   reg [7:0] data [0:(1 << 14) - 1];
   reg [7:0] buffer;

   // Handle reads/writes.
   always @(posedge clk_in) begin
      if (write_in) begin
         data[addr_in] <= bus_io;
         buffer <= bus_io;
      end else begin
         buffer <= data[addr_in];
      end
   end

   // Drive the bus.
   assign bus_io = write_in ? 8'bz : buffer;

endmodule

