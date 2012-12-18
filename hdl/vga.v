/**
 * @file vga.v
 * @author Joe Wingbermuehle
 * @date 2007-09-27
 *
 * 80x30 character VGA display controller.
 * 640x480 pixels at 60Hz.
 *
 */

/** ROM for character generation.
 * @param data_in     7-bit ASCII character to display.
 * @param line_in     Line of the character (0 to 15).
 * @param data_out    The bits of the character line.
 */
module vga_raster(data_in, line_in, data_out);

   input wire [6:0] data_in;
   input wire [3:0] line_in;
   output wire [7:0] data_out;

   wire [9:0] addr = {data_in, line_in[3:1]};
   font8x8 fnt(addr, data_out);

endmodule

/** VGA sync generator.
 * @param rst_in      Reset
 * @param clk_in      Pixel clock (25 MHz)
 * @param hsync_out   Horizontal sync signal
 * @param vsync_out   Veritical sync signal
 * @param row_out     Row output (0 to 479)
 * @param col_out     Column output (0 to 639)
 * @param send_out    Set if data should be sent to the monitor.
 */
module vga_sync(rst_in, clk_in, hsync_out, vsync_out,
                row_out, col_out, send_out);

   input wire rst_in;
   input wire clk_in;
   output reg hsync_out;
   output reg vsync_out;
   output wire [8:0] row_out;
   output wire [9:0] col_out;
   output wire send_out;

   // Horizontal timing control.
   reg [9:0] hcounter;
   reg hvalid;
   wire [9:0] next_hcounter = hcounter + 1;
   always @(posedge clk_in) begin
      if (rst_in) begin
         hsync_out <= 1;
         hvalid <= 0;
         hcounter <= 0;
      end else begin
         case (hcounter)
            0:    // Pulse, 96 clocks
               begin
                  hsync_out <= 0;
                  hvalid <= 0;
                  hcounter <= next_hcounter;
               end
            96:   // Back porch, 48 clocks
               begin
                  hsync_out <= 1;
                  hvalid <= 0;
                  hcounter <= next_hcounter;
               end
            144:  // Display, 640 clocks
               begin
                  hsync_out <= 1;
                  hvalid <= 1;
                  hcounter <= next_hcounter;
               end
            784:  // Front porch, 16 clocks
               begin
                  hsync_out <= 1;
                  hvalid <= 0;
                  hcounter <= next_hcounter;
               end
            799:  // Restart
               begin
                  hsync_out <= 1;
                  hvalid <= 0;
                  hcounter <= 0;
               end
            default:
               begin
                  hcounter <= next_hcounter;
               end
         endcase
      end
   end

   // Vertical timing control.
   reg [9:0] vcounter;
   wire [9:0] next_vcounter = vcounter + 1;
   reg vvalid;
   always @(posedge hsync_out) begin
      if (rst_in) begin
         vcounter <= 0;
         vsync_out <= 1;
         vvalid <= 0;
      end else begin
         case (vcounter)
            0:    // Pulse, 2 lines
               begin
                  vsync_out <= 0;
                  vvalid <= 0;
                  vcounter <= next_vcounter;
               end
            2:    // Back porch, 29 lines
               begin
                  vsync_out <= 1;
                  vvalid <= 0;
                  vcounter <= next_vcounter;
               end
            31:   // Display, 480 lines
               begin
                  vsync_out <= 1;
                  vvalid <= 1;
                  vcounter <= next_vcounter;
               end
            511:  // Front porch, 10 lines
               begin
                  vsync_out <= 1;
                  vvalid <= 0;
                  vcounter <= next_vcounter;
               end
            520:  // Restart
               begin
                  vsync_out <= 1;
                  vvalid <= 0;
                  vcounter <= 0;
               end
            default:
               begin
                  vcounter <= next_vcounter;
               end
         endcase
      end
   end

   // Row/column.
   assign row_out = vcounter - 31;
   assign col_out = hcounter - 144;

   // Address valid signal.
   assign send_out = vvalid & hvalid;

endmodule

/** Video RAM (stores characters).
 * 128 x 32 (only 80 x 30 are used) -> 4096 = 2 ** 12.
 * We only store 7 bits since we only display 7-bit ASCII.
 * @param clk_in The clock.
 * @param write_in Set to write a character.
 * @param write_addr_in The write address.
 * @param read_addr_in The read address.
 * @param data_in The character to write.
 * @param data_out The character being read.
 */
module vga_ram(clk_in, write_in, write_addr_in, read_addr_in,
               data_in, data_out);

   input wire clk_in;
   input wire write_in;
   input wire [11:0] write_addr_in;
   input wire [11:0] read_addr_in;
   input wire [6:0] data_in;
   output reg [6:0] data_out;

   reg [6:0] ram [0:4095];

   // Handle writes.
   always @(posedge clk_in) begin
      if (write_in)
         ram[write_addr_in] <= data_in;
   end

   // Handle reads.
   always @(posedge clk_in) begin
      data_out <= ram[read_addr_in];
   end

endmodule

/** 80x30 (virtual 128x32) character VGA display controller.
 * 640x480 pixels at 60Hz.
 * @param rst_in Asynchronous reset.
 * @param clk_in Global clock (must be 50 MHz).
 * @param pixel_clk_in Pixel clock (must be 25 MHz).
 * @param write_in Set to write (writes happen at pixel_clk_in).
 * @param row_in The row to write (0 to 29).
 * @param col_in The column to write (0 to 79).
 * @param data_in The 7-bit ASCII character code to write.
 * @param scroll_in Set to scroll the display one row (set at pixel_clk_in).
 * @param read_out Set if the display can accept data.
 * @param red_out Red signal.
 * @param green_out Green signal.
 * @param blue_out Blue signal.
 * @param hsync_out Horizontal sync.
 * @param vsync_out Vertical sync.
 */
module vga(rst_in, clk_in, pixel_clk_in,
           write_in, row_in, col_in, data_in, scroll_in, ready_out,
           red_out, green_out, blue_out, hsync_out, vsync_out);

   input wire rst_in;
   input wire clk_in;
   input wire pixel_clk_in;
   input wire write_in;
   input wire [4:0] row_in;
   input wire [6:0] col_in;
   input wire [6:0] data_in;
   input wire scroll_in;
   output wire ready_out;
   output reg red_out;
   output wire green_out;
   output wire blue_out;
   output wire hsync_out;
   output wire vsync_out;

   // Sync generator.
   wire [9:0] column;      // Pixel column (0 to 639).
   wire [8:0] row;         // Pixel row (0 to 479).
   wire send;
   vga_sync sync(rst_in, pixel_clk_in, hsync_out, vsync_out,
                 row, column, send);

   // Determine the address in the RAM of the character to display.
   // 640 columns -> 80 (128) columns of width 8.
   // 480 rows -> 30 (32) rows of height 16.
   wire [11:0] disp_addr = {row[8:4], column[9:3]};
   wire [3:0] line = row[3:0];

   // VGA RAM.
   wire ram_write;
   wire [11:0] ram_write_addr;
   wire [11:0] ram_read_addr;
   wire [6:0] ram_write_data;
   wire [6:0] ram_read_data;
   vga_ram ram(clk_in, ram_write, ram_write_addr, ram_read_addr,
               ram_write_data, ram_read_data);

   // Raster generator.
   wire [7:0] bits;
   vga_raster raster(ram_read_data, line, bits);
   always @(posedge pixel_clk_in or posedge rst_in) begin
      if (rst_in) begin
         red_out <= 0;
      end else if (send) begin
         case (column[2:0])
            0:    red_out <= bits[7];
            1:    red_out <= bits[6];
            2:    red_out <= bits[5];
            3:    red_out <= bits[4];
            4:    red_out <= bits[3];
            5:    red_out <= bits[2];
            6:    red_out <= bits[1];
            7:    red_out <= bits[0];
         endcase
      end else begin
         red_out <= 0;
      end
   end

   // We use white-on-black for the display.
   assign green_out  = red_out;
   assign blue_out   = red_out;

   // Handle scrolling and clearing.
   reg scrolling;
   reg clearing;
   wire scrolling_or_clearing = scrolling | scroll_in | clearing;
   reg [6:0] scroll_column;
   reg [4:0] scroll_row;
   reg scroll_state;
   reg [6:0] scroll_char;
   wire [4:0] next_scroll_row = scroll_row + 1;
   wire [11:0] write_addr = {row_in, col_in};
   wire [11:0] scroll_write_addr = {scroll_row, scroll_column};
   wire [11:0] scroll_read_addr = {next_scroll_row, scroll_column};
   always @(posedge pixel_clk_in or posedge rst_in) begin
      if (rst_in) begin
         scrolling <= 0;
         scroll_column <= 0;
         scroll_row <= 0;
         scroll_state <= 0;
         scroll_char <= 0;
         clearing <= 1;
      end else if (scrolling_or_clearing) begin
         if (scroll_state | clearing) begin
            // Advance to the next row/column.
            if (scroll_column == 79) begin
               if (scroll_row == 29) begin
                  scroll_row <= 0;
                  scrolling <= 0;
                  clearing <= 0;
               end else begin
                  scroll_row <= next_scroll_row;
               end
               scroll_column <= 0;
            end else begin
               scroll_column <= scroll_column + 1;
            end
            scroll_state <= 0;
         end else begin
            if (~send) begin
               // Read the character.
               // We read from the next row of characters if there
               // is one, otherwise we use 0.
               if (next_scroll_row < 30) begin
                  scroll_char <= ram_read_data;
               end else begin
                  scroll_char <= 0;
               end
               scroll_state <= 1;
            end
            scrolling <= scroll_in | scrolling;
         end
      end
   end

   // Hook up the RAM.
   assign ram_write = scrolling_or_clearing ? (scroll_state | clearing)
                                            : write_in;
   assign ram_write_data = scrolling_or_clearing ? scroll_char : data_in;
   assign ram_read_addr = send ? disp_addr : scroll_read_addr;
   assign ram_write_addr = scrolling_or_clearing ? scroll_write_addr
                                                 : write_addr;

   assign ready_out = ~scrolling_or_clearing;

endmodule

