
module display(rst_in, clk_in, data_in, write_in, ready_out,
               red_out, green_out, blue_out, hsync_out, vsync_out);

   input wire rst_in;
   input wire clk_in;
   input wire [6:0] data_in;
   input wire write_in;
   output wire ready_out;
   output wire red_out;
   output wire green_out;
   output wire blue_out;
   output wire hsync_out;
   output wire vsync_out;

   // Counter to generate the pixel clock and cursor blink.
   // clk_in should be 50 MHz.
   // Pixel clock is 25 MHz.
   reg pixel_clk = 0;
   always @(posedge clk_in) begin
      pixel_clk <= ~pixel_clk;
   end

   // VGA.
   reg vga_write;
   reg [4:0] vga_row;
   reg [6:0] vga_col;
   reg [6:0] vga_data;
   reg vga_scroll;
   wire vga_ready;
   vga video(rst_in, clk_in, pixel_clk,
             vga_write, vga_row, vga_col, vga_data, vga_scroll, vga_ready,
             red_out, green_out, blue_out, hsync_out, vsync_out);

   // Compute the next row/column.
   reg [6:0] write_data;
   reg [4:0] next_row;
   reg [6:0] next_col;
   reg [6:0] next_data;
   reg next_scroll;
   reg next_write;
   reg show_cursor;
   always @(*) begin
      next_col = vga_col;
      next_row = vga_row;
      next_scroll = 0;
      next_write = 1;
      next_data = write_data;
      show_cursor = 1;
      case (write_data)
         7'h08:      // Backspace
            if (vga_col != 0) begin
               next_col = vga_col - 1;
               next_data = 0;
            end
         7'h0A:      // New line
            if (vga_row == 29) begin
               next_scroll = 1;
               next_write = 0;
            end else begin
               next_row = vga_row + 1;
               next_write = 0;
            end
         7'h0D:      // Carriage return
            begin
               next_col = 0;
               show_cursor = 0;
               next_data = 0;
               next_write = vga_col != 79;
            end
         default:
            if (vga_col == 79) begin
               show_cursor = 0;
            end else begin
               next_col = vga_col + 1;
            end
      endcase
   end

   // State logic.
   localparam STATE_IDLE      = 0;
   localparam STATE_WRITE1    = 1;
   localparam STATE_WRITE2    = 2;
   localparam STATE_WRITE3    = 3;
   localparam STATE_CURSOR1   = 4;
   localparam STATE_CURSOR2   = 5;
   reg [2:0] state;
   always @(posedge clk_in) begin
      if (rst_in) begin
         state <= STATE_CURSOR1;
         vga_col <= 0;
         vga_row <= 0;
         vga_data <= 0;
         vga_write <= 0;
         vga_scroll <= 0;
      end else begin
         case (state)
            STATE_WRITE1:
               // First phase of the write.
               if (vga_ready) begin
                  vga_scroll <= next_scroll;
                  vga_write <= next_write;
                  vga_data <= next_data;
                  state <= STATE_WRITE2;
               end
            STATE_WRITE2:
               // Second phase of the write.
               begin
                  state <= STATE_WRITE3;
               end
            STATE_WRITE3:
               // Update position after write.
               begin
                  vga_write <= 0;
                  vga_scroll <= 0;
                  vga_row <= next_row;
                  vga_col <= next_col;
                  if (show_cursor)
                     state <= STATE_CURSOR1;
                  else
                     state <= STATE_IDLE;
               end
            STATE_CURSOR1:
               if (vga_ready) begin
                  vga_write <= 1;
                  vga_data <= 7'h03;
                  state <= STATE_CURSOR2;
               end
            STATE_CURSOR2:
               begin
                  state <= STATE_IDLE;
               end
            default:          // Idle
               begin
                  vga_write <= 0;
                  vga_scroll <= 0;
                  if (write_in) begin
                     write_data <= data_in;
                     state <= STATE_WRITE1;                  
                  end
               end
         endcase
      end
   end

   assign ready_out = state == STATE_IDLE;

endmodule

