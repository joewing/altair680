/**
 * @file ps2.v
 * @author Joe Wingbermuehle
 * @date 2007-09-27
 *
 * PS/2 keyboard controller.
 * For now only reading and upper-case ASCII is supported.
 *
 */

/** Module to read data from a PS/2 port.
 * @param rst_in Reset.
 * @param clk_in Clock.
 * @param ps2_data_in PS/2 data line.
 * @param ps2_clk_in PS/2 clock line.
 * @param data_out Data output.
 * @param ready_out Set when data is ready, cleared when data is being read.
 */
module ps2_port(rst_in, clk_in, ps2_data_in, ps2_clk_in, data_out, ready_out);

   input wire rst_in;
   input wire clk_in;
   input wire ps2_data_in;
   input wire ps2_clk_in;
   output reg [7:0] data_out;
   output reg ready_out;

   // Buffer the PS/2 clock and data signals.
   reg ps2_data;
   reg ps2_clk;
   always @(posedge clk_in) begin
      ps2_data <= ps2_data_in;
      ps2_clk <= ps2_clk_in;
   end

   // Read data coming from the port.
   // Format is 1 start bit, 8 bits of data, 1 parity bit, 1 stop bit.
   reg [3:0] state;
   wire [3:0] next_state = state + 1;
   reg got_clk;
   always @(posedge clk_in) begin
      if (rst_in) begin
         state <= 0;
         data_out <= 0;
         got_clk <= 0;
         ready_out <= 0;
      end else if (~ps2_clk & ~got_clk) begin
         case (state)
            1, 2, 3, 4, 5, 6, 7, 8:
               begin
                  data_out <= {ps2_data, data_out[7:1]};
                  state <= next_state;
                  ready_out <= 0;
               end
            9:
               begin
                  state <= 10;
                  ready_out <= 1;
               end
            10:
               begin
                  state <= 0;
                  ready_out <= 0;
               end
            default:
               begin
                  state <= ps2_data ? 0 : 1;
                  ready_out <= 0;
               end
         endcase
         got_clk <= 1;
      end else begin
         ready_out <= 0;
         if (ps2_clk) got_clk <= 0;
      end
   end

endmodule

// Module to decode scan codes from the keyboard to get ASCII.
// We only handle uppercase for now (as if the caps lock were on).
/** Keyboard scan code decoder.
 * @param rst_in Reset.
 * @param clk_in Clock.
 * @param data_in Scan code input.
 * @param valid_in Set when a scan code is ready.
 * @param data_out ASCII output.
 * @param valid_out Set when an ASCII character is ready.
 */
module keyboard_decoder(rst_in, clk_in, data_in, valid_in,
                        data_out, valid_out);

   input wire rst_in;
   input wire clk_in;
   input wire [7:0] data_in;
   input wire valid_in;
   output reg [7:0] data_out;
   output reg valid_out;

   reg shift_pressed;

   // Scan-code decoder.
   reg is_shift;
   reg is_release;
   reg is_extended;
   always @(*) begin
      data_out = 0;
      is_shift = 0;
      is_release = 0;
      is_extended = 0;
      case (data_in)
         8'hF0:   // indicates that the next scan code is release.
            is_release = 1;
         8'hE0:   // indicates that the next scan code is an extended code.
            is_extended = 1;
         8'h76:   // escape
            data_out = 8'h1B;
         8'h0E:   // `~
            data_out = shift_pressed ? 8'h7E : 8'h60;
         8'h16:   // 1!
            data_out = shift_pressed ? 8'h21 : 8'h31;
         8'h1E:   // 2@
            data_out = shift_pressed ? 8'h40 : 8'h32;
         8'h26:   // 3#
            data_out = shift_pressed ? 8'h23 : 8'h33;
         8'h25:   // 4$
            data_out = shift_pressed ? 8'h24 : 8'h34;
         8'h2E:   // 5%
            data_out = shift_pressed ? 8'h25 : 8'h35;
         8'h36:   // 6^
            data_out = shift_pressed ? 8'h5E : 8'h36;
         8'h3D:   // 7&
            data_out = shift_pressed ? 8'h26 : 8'h37;
         8'h3E:   // 8*
            data_out = shift_pressed ? 8'h2A : 8'h38;
         8'h46:   // 9(
            data_out = shift_pressed ? 8'h28 : 8'h39;
         8'h45:   // 0)
            data_out = shift_pressed ? 8'h29 : 8'h30;
         8'h4E:   // -_
            data_out = shift_pressed ? 8'h5F : 8'h2D;
         8'h55:   // =+
            data_out = shift_pressed ? 8'h2B : 8'h3D;
         8'h66:   // backspace
            data_out = 8'h08;
         8'h0D:   // tab
            data_out = 8'h09;
         8'h15:   // Q
            data_out = 8'h51;
         8'h1D:   // W
            data_out = 8'h57;
         8'h24:   // E
            data_out = 8'h45;
         8'h2D:   // R
            data_out = 8'h52;
         8'h2C:   // T
            data_out = 8'h54;
         8'h35:   // Y
            data_out = 8'h59;
         8'h3C:   // U
            data_out = 8'h55;
         8'h43:   // I
            data_out = 8'h49;
         8'h44:   // O
            data_out = 8'h4F;
         8'h4D:   // P
            data_out = 8'h50;
         8'h54:   // [{
            data_out = shift_pressed ? 8'h7B : 8'h5B;
         8'h5B:   // ]}
            data_out = shift_pressed ? 8'h7D : 8'h5D;
         8'h5D:   // \|
            data_out = shift_pressed ? 8'h7C : 8'h5C;
         8'h1C:   // A
            data_out = 8'h41;
         8'h1B:   // S
            data_out = 8'h53;
         8'h23:   // D
            data_out = 8'h44;
         8'h2B:   // F
            data_out = 8'h46;
         8'h34:   // G
            data_out = 8'h47;
         8'h33:   // H
            data_out = 8'h48;
         8'h3B:   // J
            data_out = 8'h4A;
         8'h42:   // K
            data_out = 8'h4B;
         8'h4B:   // L
            data_out = 8'h4C;
         8'h4C:   // ;:
            data_out = shift_pressed ? 8'h3A : 8'h3B;
         8'h52:   // '"
            data_out = shift_pressed ? 8'h22 : 8'h27;
         8'h5A:   // enter
            data_out = 8'h0A;    // Note that we need to send 0D 0A
         8'h12, 8'h59:   // shift
            is_shift = 1;
         8'h1A:   // Z
            data_out = 8'h5A;
         8'h22:   // X
            data_out = 8'h58;
         8'h21:   // C
            data_out = 8'h43;
         8'h2A:   // V
            data_out = 8'h56;
         8'h32:   // B
            data_out = 8'h42;
         8'h31:   // N
            data_out = 8'h4E;
         8'h3A:   // M
            data_out = 8'h4D;
         8'h41:   // ,<
            data_out = shift_pressed ? 8'h3C : 8'h2C;
         8'h49:   // .>
            data_out = shift_pressed ? 8'h3E : 8'h2E;
         8'h4A:   // /?
            data_out = shift_pressed ? 8'h3F : 8'h2F;
         8'h29:   // space
            data_out = 8'h20;
      endcase
   end

   // State logic.
   localparam STATE_IDLE      = 0;
   localparam STATE_EXTENDED  = 1;
   localparam STATE_RELEASE   = 2;
   localparam STATE_ERELEASE  = 3;
   reg [1:0] state;
   always @(posedge clk_in) begin
      if (rst_in) begin
         state <= STATE_IDLE;
         shift_pressed <= 0;
         valid_out <= 0;
      end else if (valid_in) begin
         case (state)
            STATE_IDLE:
               case (1'b1)
                  is_release:    state <= STATE_RELEASE;
                  is_extended:   state <= STATE_EXTENDED;
                  is_shift:      shift_pressed <= 1;
                  default:       valid_out <= |data_out;
               endcase
            STATE_EXTENDED:
               state <= is_release ? STATE_ERELEASE : STATE_IDLE;
            STATE_RELEASE:
               begin
                  if (is_shift) shift_pressed <= 0;
                  state <= STATE_IDLE;
               end
            STATE_ERELEASE:
               state <= STATE_IDLE;
         endcase
      end else begin
         valid_out <= 0;
      end
   end

endmodule

/** PS/2 Keyboard interface.
 * @param rst_in Reset.
 * @param clk_in Clock.
 * @param ps2_data_in PS/2 data line.
 * @param ps2_clk_in PS/2 clock line.
 * @param data_out ASCII output.
 * @param ready_out ASCII output ready.
 */
module keyboard(rst_in, clk_in, ps2_data_in, ps2_clk_in, data_out, ready_out);

   input wire rst_in;
   input wire clk_in;
   input wire ps2_data_in;
   input wire ps2_clk_in;
   output reg [7:0] data_out;
   output reg ready_out;

   // PS/2 handler.
   wire [7:0] scan_code;
   wire scan_ready;
   ps2_port ps2(rst_in, clk_in, ps2_data_in, ps2_clk_in,
                scan_code, scan_ready);

   // Keyboard character decoder.
   wire [7:0] ascii_code;
   wire ascii_ready;
   keyboard_decoder kd(rst_in, clk_in, scan_code, scan_ready,
                       ascii_code, ascii_ready);

   // Data latch.
   always @(posedge clk_in) begin
      if (rst_in) begin
         data_out <= 0;
         ready_out <= 0;
      end else begin
         data_out <= ascii_code;
         ready_out <= ascii_ready;
      end
   end

endmodule

