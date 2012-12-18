/** Memory Management Unit for the Altair 680.
 * Joe Wingbermuehle
 * 2007-09-03
 * Requires the "basic_rom", "acia", "prom1", and "ram" modules.
 */

module mmu(rst_in, clk_in, write_in, addr_in, bus_io, rxd_in, txd_out,
           load_in, ready_out, irq_out);

   input wire rst_in;
   input wire clk_in;
   input wire write_in;
   input wire [15:0] addr_in;
   inout wire [7:0] bus_io;
   input wire rxd_in;
   output wire txd_out;
   input wire load_in;
   output wire ready_out;
   output wire irq_out;

   // Address ranges:
   //    $0000 - $EFFF     - RAM
   //    $F000 - $F001     - ACIA
   //    $F002             - STRAPS
   //    $F003 - $FEFF     - ?
   //    $FF00 - $FFFF     - PROM

   // BASIC ROM. Loaded at reset.
   reg basic_loaded;
   wire basic_write = ~basic_loaded;
   reg [15:0] basic_addr;
   wire [7:0] basic_data;
   basic_rom br(basic_addr[12:0], basic_data);
   always @(posedge clk_in) begin
      if (rst_in) begin
         basic_loaded <= ~load_in;
         basic_addr <= 0;
      end else begin
         if (~basic_loaded) begin
            if (basic_addr == 16'h3FFF) begin
               basic_loaded <= 1;
            end
            basic_addr <= basic_addr + 1;
         end
      end
   end
   assign ready_out = basic_loaded;

   // STRAPS.
   // The bits of STRAPS are defined as follows:
   //    7 - 0 for terminal, 1 for no terminal.
   //    Other bits control ACIA, which we don't care about.
   wire use_straps = (addr_in[15:0] == 16'hF002) & basic_loaded;
   wire straps_read = use_straps & ~write_in;
   assign bus_io = straps_read ? 8'b0000000 : 8'bz;

   // ACIA.
   wire io_port = addr_in == 16'hF000 || addr_in == 16'hF001;
   wire use_acia = io_port & basic_loaded;
   wire acia_write = use_acia & write_in;
   wire acia_read = use_acia & ~write_in;
   wire acia_mode = addr_in[0];
   wire [7:0] acia_bus;
   wire acia_irq;
   acia a(rst_in, clk_in, acia_mode, acia_read, acia_write,
          acia_bus, rxd_in, txd_out, acia_irq);
   assign acia_bus = acia_write ? bus_io : 8'bz;
   assign bus_io = acia_read ? acia_bus : 8'bz;

   // PROM.
   wire use_prom = (addr_in[15:8] == 8'hFF) & basic_loaded;
   wire prom_read = use_prom & ~write_in;
   wire [7:0] prom_bus;
   prom1 p1(addr_in[7:0], prom_bus);
   assign bus_io = prom_read ? prom_bus : 8'bz;

   // RAM.
   wire use_ram = ~|addr_in[15:14] | basic_write;
   wire ram_write = use_ram & (write_in | basic_write);
   wire ram_read = use_ram & ~(write_in | basic_write);
   wire [13:0] ram_addr  = basic_write ? basic_addr[13:0] : addr_in[13:0];
   wire [7:0] ram_bus;
   ram r1(clk_in, ram_write, ram_addr, ram_bus);
   assign ram_bus = ram_write ? (basic_write ? basic_data : bus_io) : 8'bz;
   assign bus_io = ram_read ? ram_bus : 8'bz;

   // Any other addresses we hardwire to 8'hFF for reads.
   wire unassigned = ~(use_straps | use_acia | use_prom | use_ram);
   wire unassigned_read = unassigned & ~write_in;
   assign bus_io = unassigned_read ? 8'hFF : 8'bz;

   // Assign the IRQ.
//   assign irq_out = acia_irq;
   assign irq_out = 0;

endmodule

