/**
 * @file m6800.v
 * @author Joe Wingbermuehle
 * @date 2007-09-03
 *
 * A Verilog model of the Motorola 6800 microprocessor.
 *
 */

// ALU operations
`define ALU_ADD   0     // Add
`define ALU_ADC   1     // Add with carry
`define ALU_AND   2     // Logical AND
`define ALU_ASL   3     // Arithmetic shift left
`define ALU_ASR   4     // Arithmetic shift right
`define ALU_EOR   5     // Logical exclusive OR
`define ALU_LSR   6     // Logical shift right
`define ALU_NEG   7     // Negate
`define ALU_OR    8     // Logical OR
`define ALU_ROL   9     // Rotate left
`define ALU_ROR   10    // Rotate right
`define ALU_SUB   11    // Subtract
`define ALU_SBC   12    // Subtract with carry
`define ALU_INC   13    // Increment
`define ALU_DEC   14    // Decrement
`define ALU_CLR   15    // Clear
`define ALU_NOP   16    // No operation
`define ALU_COM   17    // Complement
`define ALU_DAA   18    // Decimal adjust
`define ALU_CLC   19    // Clear carry
`define ALU_CLI   20    // Clear interrupt
`define ALU_CLV   21    // Clear overflow
`define ALU_SEC   22    // Set carry
`define ALU_SEI   23    // Set interrupt
`define ALU_SEV   24    // Set overflow
`define ALU_TST   25    // Test

// Flags
`define FLAG_E    7     // Entire
`define FLAG_F    6     // FIRQ mask
`define FLAG_H    5     // Half carry
`define FLAG_I    4     // Interrupt mask
`define FLAG_N    3     // Negative
`define FLAG_Z    2     // Zero
`define FLAG_V    1     // Overflow
`define FLAG_C    0     // Carry

// Normal instruction states.
`define STATE_FETCH        0
`define STATE_DECODE       1
`define STATE_FETCH2       2
`define STATE_FETCH3       3
`define STATE_DECODE2      4
`define STATE_READ1        5
`define STATE_READ2        6
`define STATE_WRITE1       7
`define STATE_WRITE2       8
`define STATE_DECODE3      9
`define STATE_CPX          10

// Interrupt states.
`define STATE_WAIT         11
`define STATE_RESET1       12
`define STATE_RESET2       13
`define STATE_INT1         14
`define STATE_INT2         15

// Push states.
`define STATE_PUSH_C       16
`define STATE_PUSH_A       17
`define STATE_PUSH_B       18
`define STATE_PUSH_XH      19
`define STATE_PUSH_XL      20
`define STATE_PUSH_PCH     21
`define STATE_PUSH_PCL     22

// Pull states.
`define STATE_PULL_PCL     23
`define STATE_PULL_PCH     24
`define STATE_PULL_XL      25
`define STATE_PULL_XH      26
`define STATE_PULL_B       27
`define STATE_PULL_A       28
`define STATE_PULL_C       29

`define MAX_STATE          29

/** The 6800 ALU.
 * op_in       The ALU operation to perform.
 * srca_in     The left side.
 * srcb_in     The right side (if any).
 * flags_in    The current flags.
 * result_out  The result.
 * flags_out   The new flags.
 */
module m6800_alu(op_in, srca_in, srcb_in, flags_in, result_out, flags_out);

   input wire [5:0] op_in;
   input wire [7:0] srca_in;
   input wire [7:0] srcb_in;
   input wire [7:0] flags_in;
   output reg [7:0] result_out;
   output reg [7:0] flags_out;

   wire carry_in = flags_in[`FLAG_C];

   wire [7:0] add_result = srca_in + srcb_in;
   wire [7:0] adc_result = add_result + carry_in;
   wire [7:0] and_result = srca_in & srcb_in;
   wire [7:0] eor_result = srca_in ^ srcb_in;
   wire [7:0] or_result  = srca_in | srcb_in;
   wire [7:0] asl_result = {srca_in[6:0], 1'b0};
   wire [7:0] asr_result = {srca_in[7], srca_in[7:1]};
   wire [7:0] com_result = ~srca_in;
   wire [7:0] lsr_result = {1'b0, srca_in[7:1]};
   wire [7:0] neg_result = com_result + 1;
   wire [7:0] rol_result = {srca_in[6:0], carry_in};
   wire [7:0] ror_result = {carry_in, srca_in[7:1]};
   wire [7:0] sub_result = srca_in - srcb_in;
   wire [7:0] sbc_result = sub_result - carry_in;
   wire [7:0] inc_result = srca_in + 1;
   wire [7:0] dec_result = srca_in - 1;

   // DAA stuff.
   wire daa_greater_low    = srca_in[3:0] > 9;
   wire daa_greater_high   = srca_in[7:4] > 9;
   wire daa_add_low        = flags_in[`FLAG_H] | daa_greater_low;
   wire [7:0] daa_low      = daa_add_low ? (srca_in + 8'h06) : srca_in;
   wire daa_add_high       = daa_greater_high | carry_in
                           | (daa_greater_low & srca_in[7:4] == 9);
   wire [7:0] daa_result   = daa_add_high ? (daa_low + 8'h60) : daa_low;
   wire daa_carry          = (daa_result[7:4] > 9) | carry_in;
   wire daa_overflow       = srca_in > 199;

   // Determine the result.
   always @(*) begin
      result_out = srca_in;
      case (op_in)
         `ALU_ADD:   result_out = add_result;
         `ALU_ADC:   result_out = adc_result;
         `ALU_AND:   result_out = and_result;
         `ALU_ASL:   result_out = asl_result;
         `ALU_ASR:   result_out = asr_result;
         `ALU_EOR:   result_out = eor_result;
         `ALU_LSR:   result_out = lsr_result;
         `ALU_NEG:   result_out = neg_result;
         `ALU_OR:    result_out = or_result;
         `ALU_SUB:   result_out = sub_result;
         `ALU_SBC:   result_out = sbc_result;
         `ALU_ROL:   result_out = rol_result;
         `ALU_ROR:   result_out = ror_result;
         `ALU_INC:   result_out = inc_result;
         `ALU_DEC:   result_out = dec_result;
         `ALU_CLR:   result_out = 0;
         `ALU_COM:   result_out = com_result;
         `ALU_DAA:   result_out = daa_result;
      endcase
   end

   wire is_neg    = result_out[7];
   wire is_zero   = result_out == 0;
   wire halfcarry = (srca_in[3] & srcb_in[3])
                  | (srca_in[3] & ~result_out[3])
                  | (srcb_in[3] & ~result_out[3]);

   wire asl_carry    = srca_in[7];
   wire asl_overflow = srca_in[6] ^ srca_in[7];
   wire asr_carry    = srca_in[0];
   wire asr_overflow = srca_in[7] ^ srca_in[0];
   wire lsr_carry    = srca_in[0];
   wire lsr_overflow = srca_in[0];
   wire neg_carry    = neg_result == 8'h00;
   wire neg_overflow = neg_result == 8'h80;
   wire rol_carry    = srca_in[7];
   wire rol_overflow = asl_overflow;
   wire ror_carry    = srca_in[0];
   wire ror_overflow = srca_in[0] ^ carry_in;
   wire inc_overflow = srca_in == 8'h7F;
   wire dec_overflow = srca_in == 8'h80;
   wire add_carry    = (srca_in[7] & srcb_in[7])
                     | (srca_in[7] & ~result_out[7])
                     | (srcb_in[7] & ~result_out[7]);
   wire add_overflow = (srca_in[7] & srcb_in[7] & ~result_out[7])
                     | (~srca_in[7] & ~srcb_in[7] & result_out[7]);
   wire sub_carry    = (~srca_in[7] & srcb_in[7])
                     | (~srca_in[7] & result_out[7])
                     | (srcb_in[7] & result_out[7]);
   wire sub_overflow = (srca_in[7] & ~srcb_in[7] & ~result_out[7])
                     | (~srca_in[7] & srcb_in[7] & result_out[7]);

   // Assign the new flags based on the ALU operation.
   always @(*) begin
      flags_out = flags_in;
      case (op_in)
         `ALU_ADD:
            begin
               flags_out[`FLAG_H] = halfcarry;
               flags_out[`FLAG_N] = is_neg;
               flags_out[`FLAG_Z] = is_zero;
               flags_out[`FLAG_V] = add_overflow;
               flags_out[`FLAG_C] = add_carry;
            end
         `ALU_ADC:
            begin
               flags_out[`FLAG_H] = halfcarry;
               flags_out[`FLAG_N] = is_neg;
               flags_out[`FLAG_Z] = is_zero;
               flags_out[`FLAG_V] = add_overflow;
               flags_out[`FLAG_C] = add_carry;
            end
         `ALU_AND:
            begin
               flags_out[`FLAG_N] = is_neg;
               flags_out[`FLAG_Z] = is_zero;
               flags_out[`FLAG_V] = 0;
            end
         `ALU_ASL:
            begin
               flags_out[`FLAG_N] = is_neg;
               flags_out[`FLAG_Z] = is_zero;
               flags_out[`FLAG_V] = asl_overflow;
               flags_out[`FLAG_C] = asl_carry;
            end
         `ALU_ASR:
            begin
               flags_out[`FLAG_N] = is_neg;
               flags_out[`FLAG_Z] = is_zero;
               flags_out[`FLAG_V] = asr_overflow;
               flags_out[`FLAG_C] = asr_carry;
            end
         `ALU_EOR:
            begin
               flags_out[`FLAG_N] = is_neg;
               flags_out[`FLAG_Z] = is_zero;
               flags_out[`FLAG_V] = 0;
            end
         `ALU_LSR:
            begin
               flags_out[`FLAG_N] = 0;
               flags_out[`FLAG_Z] = is_zero;
               flags_out[`FLAG_V] = lsr_overflow;
               flags_out[`FLAG_C] = lsr_carry;
            end
         `ALU_NEG:
            begin
               flags_out[`FLAG_N] = is_neg;
               flags_out[`FLAG_Z] = is_zero;
               flags_out[`FLAG_V] = neg_overflow;
               flags_out[`FLAG_C] = neg_carry;
            end
         `ALU_OR:
            begin
               flags_out[`FLAG_N] = is_neg;
               flags_out[`FLAG_Z] = is_zero;
               flags_out[`FLAG_V] = 0;
            end
         `ALU_SUB:
            begin
               flags_out[`FLAG_N] = is_neg;
               flags_out[`FLAG_Z] = is_zero;
               flags_out[`FLAG_V] = sub_overflow;
               flags_out[`FLAG_C] = sub_carry;
            end
         `ALU_SBC:
            begin
               flags_out[`FLAG_N] = is_neg;
               flags_out[`FLAG_Z] = is_zero;
               flags_out[`FLAG_V] = sub_overflow;
               flags_out[`FLAG_C] = sub_carry;
            end
         `ALU_ROL:
            begin
               flags_out[`FLAG_N] = is_neg;
               flags_out[`FLAG_Z] = is_zero;
               flags_out[`FLAG_V] = rol_overflow;
               flags_out[`FLAG_C] = rol_carry;
            end
         `ALU_ROR:
            begin
               flags_out[`FLAG_N] = is_neg;
               flags_out[`FLAG_Z] = is_zero;
               flags_out[`FLAG_V] = ror_overflow;
               flags_out[`FLAG_C] = ror_carry;
            end
         `ALU_INC:
            begin
               flags_out[`FLAG_N] = is_neg;
               flags_out[`FLAG_Z] = is_zero;
               flags_out[`FLAG_V] = inc_overflow;
            end
         `ALU_DEC:
            begin
               flags_out[`FLAG_N] = is_neg;
               flags_out[`FLAG_Z] = is_zero;
               flags_out[`FLAG_V] = dec_overflow;
            end
         `ALU_CLR:
            begin
               flags_out[`FLAG_N] = 0;
               flags_out[`FLAG_Z] = 1;
               flags_out[`FLAG_V] = 0;
               flags_out[`FLAG_C] = 0;
            end
         `ALU_COM:
            begin
               flags_out[`FLAG_N] = is_neg;
               flags_out[`FLAG_Z] = is_zero;
               flags_out[`FLAG_V] = 0;
               flags_out[`FLAG_C] = 1;
            end
         `ALU_DAA:
            begin
               flags_out[`FLAG_N] = is_neg;
               flags_out[`FLAG_Z] = is_zero;
               flags_out[`FLAG_V] = daa_overflow;
               flags_out[`FLAG_C] = daa_carry;
            end
         `ALU_CLC:   flags_out[`FLAG_C] = 0;
         `ALU_CLI:   flags_out[`FLAG_I] = 0;
         `ALU_CLV:   flags_out[`FLAG_V] = 0;
         `ALU_SEC:   flags_out[`FLAG_C] = 1;
         `ALU_SEI:   flags_out[`FLAG_I] = 1;
         `ALU_SEV:   flags_out[`FLAG_V] = 1;
         `ALU_TST:
            begin
               flags_out[`FLAG_N] = is_neg;
               flags_out[`FLAG_Z] = is_zero;
               flags_out[`FLAG_V] = 0;
               flags_out[`FLAG_C] = 0;
            end
      endcase
   end

endmodule

/** 6800 branch logic.
 * opcode_in   The opcode of the branch (we care about the lower 4 bits).
 * flags_in    The current flags.
 * branch_out  Set if the branch should be taken.
 */
module m6800_branch(opcode_in, flags_in, branch_out);

   input wire [7:0] opcode_in;
   input wire [7:0] flags_in;
   output reg branch_out;

   // Determine if a branch should be taken.
   wire n_xor_v = flags_in[`FLAG_N] ^ flags_in[`FLAG_V];
   wire c_or_z = flags_in[`FLAG_C] | flags_in[`FLAG_Z];
   wire z_or_nxv = flags_in[`FLAG_Z] | n_xor_v;
   always @(*) begin
      branch_out = 0;
      case (opcode_in[3:0])
         4'h0:    // Always
            branch_out = 1;
         4'h1:    // Never
            branch_out = 0;
         4'h2:    // Higher
            branch_out = !c_or_z;
         4'h3:    // Lower or same
            branch_out = c_or_z;
         4'h4:    // Carry clear
            branch_out = !flags_in[`FLAG_C];
         4'h5:    // Carry set
            branch_out = flags_in[`FLAG_C];
         4'h6:    // Not equal
            branch_out = !flags_in[`FLAG_Z];
         4'h7:    // Equal
            branch_out = flags_in[`FLAG_Z];
         4'h8:    // Overflow clear
            branch_out = !flags_in[`FLAG_V];
         4'h9:    // Overflow set
            branch_out = flags_in[`FLAG_V];
         4'hA:    // Plus
            branch_out = !flags_in[`FLAG_N];
         4'hB:    // Minus
            branch_out = flags_in[`FLAG_N];
         4'hC:    // Greater than or equal
            branch_out = !n_xor_v;
         4'hD:    // Less than
            branch_out = n_xor_v;
         4'hE:    // Greater than
            branch_out = !z_or_nxv;
         4'hF:    // Less than or equal
            branch_out = z_or_nxv;
      endcase
   end

endmodule

/** The M6800 microprocessor.
 * clk_in         The clock.
 * rst_in         Reset.
 * address_out    The memory address for reading/writing.
 * write_out      Set to write memory.
 * bus_io         Bidirectional data bus to memory.
 * irq_in         Interrupt request.
 * nmi_in         Non-maskable Interrupt.
 */
module m6800(clk_in, rst_in, address_out, write_out, bus_io, irq_in, nmi_in);

   input wire clk_in;
   input wire rst_in;
   output wire [15:0] address_out;
   output wire write_out;
   inout wire [7:0] bus_io;
   input wire irq_in;
   input wire nmi_in;

   // User registers.
   reg [7:0] rega;      // Accumulator A
   reg [7:0] regb;      // Accumulator B
   reg [7:0] flags;     // Condition code register
   reg [15:0] pc;       // Program counter
   reg [15:0] sp;       // Stack pointer
   reg [15:0] regx;     // Index register

   // Internal registers.
   reg [7:0] opcode;             // Opcode of the current instruction.
   reg [15:0] operand;           // Operand of the current instruction.
   reg [`MAX_STATE:0] state;     // Current state.
   reg [7:0] bus_latch;          // The last bus_io.
   reg [15:0] base_ind_addr2;    // Second address for indirect addressing.

   reg [15:0] new_sp;
   reg [15:0] new_regx;

   // ALU
   reg [5:0] alu_op;
   reg [7:0] alu_srca;
   reg [7:0] alu_srcb;
   wire [7:0] alu_result;
   wire [7:0] alu_flags;
   m6800_alu alu(alu_op, alu_srca, alu_srcb, flags, alu_result, alu_flags);

   // Branch logic
   wire take_branch;
   m6800_branch branch(opcode, flags, take_branch);

   // Decode the opcode.
   wire op_aba          = opcode == 8'h1B;
   wire op_asla         = opcode == 8'h48;
   wire op_aslb         = opcode == 8'h58;
   wire op_asra         = opcode == 8'h47;
   wire op_asrb         = opcode == 8'h57;
   wire op_bsr          = opcode == 8'h8D;
   wire op_cba          = opcode == 8'h11;
   wire op_clc          = opcode == 8'h0C;
   wire op_cli          = opcode == 8'h0E;
   wire op_clra         = opcode == 8'h4F;
   wire op_clrb         = opcode == 8'h5F;
   wire op_clv          = opcode == 8'h0A;
   wire op_coma         = opcode == 8'h43;
   wire op_comb         = opcode == 8'h53;
   wire op_daa          = opcode == 8'h19;
   wire op_deca         = opcode == 8'h4A;
   wire op_decb         = opcode == 8'h5A;
   wire op_des          = opcode == 8'h34;
   wire op_dex          = opcode == 8'h09;
   wire op_inca         = opcode == 8'h4C;
   wire op_incb         = opcode == 8'h5C;
   wire op_ins          = opcode == 8'h31;
   wire op_inx          = opcode == 8'h08;
   wire op_lsra         = opcode == 8'h44;
   wire op_lsrb         = opcode == 8'h54;
   wire op_nega         = opcode == 8'h40;
   wire op_negb         = opcode == 8'h50;
   wire op_nop          = opcode == 8'h01;
   wire op_psha         = opcode == 8'h36;
   wire op_pshb         = opcode == 8'h37;
   wire op_pula         = opcode == 8'h32;
   wire op_pulb         = opcode == 8'h33;
   wire op_rola         = opcode == 8'h49;
   wire op_rolb         = opcode == 8'h59;
   wire op_rora         = opcode == 8'h46;
   wire op_rorb         = opcode == 8'h56;
   wire op_rti          = opcode == 8'h3B;
   wire op_rts          = opcode == 8'h39;
   wire op_sba          = opcode == 8'h10;
   wire op_sec          = opcode == 8'h0D;
   wire op_sei          = opcode == 8'h0F;
   wire op_sev          = opcode == 8'h0B;
   wire op_swi          = opcode == 8'h3F;
   wire op_tab          = opcode == 8'h16;
   wire op_tap          = opcode == 8'h06;
   wire op_tba          = opcode == 8'h17;
   wire op_tpa          = opcode == 8'h07;
   wire op_tsta         = opcode == 8'h4D;
   wire op_tstb         = opcode == 8'h5D;
   wire op_tsx          = opcode == 8'h30;
   wire op_txs          = opcode == 8'h35;
   wire op_wai          = opcode == 8'h3E;

   wire op_ldaa         = (opcode[7:6] == 2'b10) & (opcode[3:0] == 4'b0110);
   wire op_ldab         = (opcode[7:6] == 2'b11) & (opcode[3:0] == 4'b0110);
   wire op_lds          = (opcode[7:6] == 2'b10) & (opcode[3:0] == 4'b1110);
   wire op_ldx          = (opcode[7:6] == 2'b11) & (opcode[3:0] == 4'b1110);
   wire op_cpx          = (opcode[7:6] == 2'b10) & (opcode[3:0] == 4'b1100);
   wire op_adca         = (opcode[7:6] == 2'b10) & (opcode[3:0] == 4'b1001);
   wire op_adda         = (opcode[7:6] == 2'b10) & (opcode[3:0] == 4'b1011);
   wire op_anda         = (opcode[7:6] == 2'b10) & (opcode[3:0] == 4'b0100);
   wire op_cmpa         = (opcode[7:6] == 2'b10) & (opcode[3:0] == 4'b0001);
   wire op_eora         = (opcode[7:6] == 2'b10) & (opcode[3:0] == 4'b1000);
   wire op_ora          = (opcode[7:6] == 2'b10) & (opcode[3:0] == 4'b1010);
   wire op_sbca         = (opcode[7:6] == 2'b10) & (opcode[3:0] == 4'b0010);
   wire op_suba         = (opcode[7:6] == 2'b10) & (opcode[3:0] == 4'b0000);
   wire op_staa         = (opcode[7:6] == 2'b10) & (opcode[3:0] == 4'b0111);
   wire op_adcb         = (opcode[7:6] == 2'b11) & (opcode[3:0] == 4'b1001);
   wire op_addb         = (opcode[7:6] == 2'b11) & (opcode[3:0] == 4'b1011);
   wire op_andb         = (opcode[7:6] == 2'b11) & (opcode[3:0] == 4'b0100);
   wire op_cmpb         = (opcode[7:6] == 2'b11) & (opcode[3:0] == 4'b0001);
   wire op_eorb         = (opcode[7:6] == 2'b11) & (opcode[3:0] == 4'b1000);
   wire op_orb          = (opcode[7:6] == 2'b11) & (opcode[3:0] == 4'b1010);
   wire op_sbcb         = (opcode[7:6] == 2'b11) & (opcode[3:0] == 4'b0010);
   wire op_subb         = (opcode[7:6] == 2'b11) & (opcode[3:0] == 4'b0000);
   wire op_stab         = (opcode[7:6] == 2'b11) & (opcode[3:0] == 4'b0111);
   wire op_bita         = (opcode[7:6] == 2'b10) & (opcode[3:0] == 4'b0101);
   wire op_bitb         = (opcode[7:6] == 2'b11) & (opcode[3:0] == 4'b0101);
   wire op_sts          = (opcode[7:6] == 2'b10) & (opcode[3:0] == 4'b1111);
   wire op_stx          = (opcode[7:6] == 2'b11) & (opcode[3:0] == 4'b1111);

   wire op_asl          = (opcode[7:5] == 3'b011) & (opcode[3:0] == 4'b1000);
   wire op_asr          = (opcode[7:5] == 3'b011) & (opcode[3:0] == 4'b0111);
   wire op_clr          = (opcode[7:5] == 3'b011) & (opcode[3:0] == 4'b1111);
   wire op_com          = (opcode[7:5] == 3'b011) & (opcode[3:0] == 4'b0011);
   wire op_dec          = (opcode[7:5] == 3'b011) & (opcode[3:0] == 4'b1010);
   wire op_inc          = (opcode[7:5] == 3'b011) & (opcode[3:0] == 4'b1100);
   wire op_lsr          = (opcode[7:5] == 3'b011) & (opcode[3:0] == 4'b0100);
   wire op_neg          = (opcode[7:5] == 3'b011) & (opcode[3:0] == 4'b0000);
   wire op_rol          = (opcode[7:5] == 3'b011) & (opcode[3:0] == 4'b1001);
   wire op_ror          = (opcode[7:5] == 3'b011) & (opcode[3:0] == 4'b0110);
   wire op_tst          = (opcode[7:5] == 3'b011) & (opcode[3:0] == 4'b1101);
   wire op_jmp          = (opcode[7:5] == 3'b011) & (opcode[3:0] == 4'b1110);
   wire op_jsr          = (opcode[7:5] == 3'b101) & (opcode[3:0] == 4'b1101);

   wire op_branch       = opcode[7:4] == 4'h2;

   // Determine if this is an inherent mode instruction.
   wire inherent_mode   = op_aba  | op_asla | op_aslb | op_asra | op_asrb
                        | op_cba  | op_clc  | op_cli  | op_clra | op_clrb
                        | op_clv  | op_coma | op_comb | op_daa  | op_deca
                        | op_decb | op_des  | op_dex  | op_inca | op_incb
                        | op_ins  | op_inx  | op_lsra | op_lsrb | op_nega
                        | op_negb | op_nop  | op_rola | op_rolb | op_rora
                        | op_rorb | op_sba  | op_sec  | op_sei  | op_sev
                        | op_swi  | op_tab  | op_tba  | op_tap  | op_tpa
                        | op_tsta | op_tstb | op_tsx  | op_txs  | op_wai;

   // Determine if this is an immediate mode instruction.
   wire supports_immediate = op_adca | op_adcb | op_adda | op_addb | op_anda
                           | op_andb | op_bita | op_bitb | op_cmpa | op_cmpb
                           | op_cpx  | op_eora | op_eorb | op_ldaa | op_ldab
                           | op_lds  | op_ldx  | op_ora  | op_orb  | op_sbca
                           | op_sbcb | op_suba | op_subb;
   wire immediate_mode = supports_immediate & (opcode[5:4] == 2'b00);

   // Determine if this is an extended mode instruction.
   wire supports_extended  = op_adca | op_adcb | op_adda | op_addb | op_anda
                           | op_andb | op_asl  | op_asr  | op_bita | op_bitb
                           | op_clr  | op_cmpa | op_cmpb | op_com  | op_cpx
                           | op_dec  | op_eora | op_eorb | op_inc  | op_jmp
                           | op_jsr  | op_ldaa | op_ldab | op_lds  | op_ldx
                           | op_lsr  | op_neg  | op_ora  | op_orb  | op_rol
                           | op_ror  | op_sbca | op_sbcb | op_staa | op_stab
                           | op_sts  | op_stx  | op_suba | op_subb | op_tst;
   wire extended_mode = supports_extended & (opcode[5:4] == 2'b11);

   // Determine if this is an index mode instruction.
   wire supports_index  = supports_extended;
   wire index_mode      = supports_index & (opcode[5:4] == 2'b10);

   // Note that we don't need a special case for direct mode since it
   // can be handled the same way as extended mode by zeroing the top
   // byte of the operand when reading the second byte of the instruction.

   // Get some more info.
   wire double_byte     = op_lds | op_ldx | op_cpx | op_sts | op_stx;
   wire immediate_16    = immediate_mode & double_byte;

   // Determine if we are targeting register A.
   wire dest_rega = op_aba  | op_adca | op_adda | op_anda | op_asla
                  | op_asra | op_clra | op_coma | op_daa  | op_deca
                  | op_eora | op_inca | op_ldaa | op_lsra | op_nega
                  | op_ora  | op_pula | op_rola | op_rora | op_sba
                  | op_sbca | op_suba | op_tba  | op_tpa;

   // Determine if we are targeting register B.
   wire dest_regb = op_adcb | op_addb | op_andb | op_aslb | op_asrb
                  | op_clrb | op_comb | op_decb | op_eorb | op_incb
                  | op_ldab | op_lsrb | op_negb | op_orb  | op_pulb
                  | op_rolb | op_rorb | op_sbcb | op_subb | op_tab;

   // Determine if we are targeting memory.
   wire dest_memory  = op_asl  | op_asr  | op_clr  | op_com
                     | op_dec  | op_inc  | op_lsr  | op_neg
                     | op_rol  | op_ror  | op_staa | op_stab
                     | op_sts  | op_stx  | op_psha | op_pshb
                     | op_bsr  | op_jsr  | op_swi;

   // Determine if we need to do an indirect read/write.
   wire can_read  = op_adca | op_adcb | op_adda | op_addb
                  | op_anda | op_andb | op_asl  | op_asr
                  | op_bita | op_bitb | op_cmpa | op_cmpb
                  | op_com  | op_cpx  | op_dec  | op_eora
                  | op_eorb | op_inc  | op_ldaa | op_ldab
                  | op_lds  | op_ldx  | op_lsr  | op_neg
                  | op_ora  | op_orb  | op_pula | op_pulb
                  | op_rol  | op_ror  | op_sbca | op_sbcb
                  | op_suba | op_subb | op_tst;
   wire does_read = can_read & ~immediate_mode;

   wire does_write   = dest_memory;

   // Determine if we are pushing or pulling.
   wire is_pushing   = state[`STATE_PUSH_C]  | state[`STATE_PUSH_A]
                     | state[`STATE_PUSH_B]  | state[`STATE_PUSH_XH]
                     | state[`STATE_PUSH_XL] | state[`STATE_PUSH_PCH]
                     | state[`STATE_PUSH_PCL];
   wire is_pulling   = state[`STATE_PULL_C]  | state[`STATE_PULL_A]
                     | state[`STATE_PULL_B]  | state[`STATE_PULL_XH]
                     | state[`STATE_PULL_XL] | state[`STATE_PULL_PCH]
                     | state[`STATE_PULL_PCL];

   // Determine if we should commit the instruction.
   reg commit;
   always @(*) begin
      case (1'b1)
         state[`STATE_FETCH]:    commit = 0;
         state[`STATE_DECODE]:   commit = inherent_mode & ~op_swi;
         state[`STATE_FETCH2]:   commit = 0;
         state[`STATE_FETCH3]:   commit = 0;
         state[`STATE_DECODE2]:  commit = ~(does_write | does_read);
         state[`STATE_READ1]:    commit = ~(does_write | double_byte);
         state[`STATE_READ2]:    commit = ~(does_write | op_cpx);
         state[`STATE_WRITE1]:   commit = 1;
         state[`STATE_WRITE2]:   commit = 1;
         state[`STATE_CPX]:      commit = 1;
         default:                commit = is_pushing | is_pulling;
      endcase
   end
   assign write_out = dest_memory & commit;

   // Latch the opcode.
   always @(posedge clk_in) begin
      if (state[`STATE_FETCH])
         opcode <= bus_io;
   end

   // Latch the operand.
   // We zero the top byte of operand on FETCH2 so that we don't need
   // a special case for direct mode.
   always @(posedge clk_in) begin
      case (1'b1)
         state[`STATE_FETCH2]:   operand <= {8'b00, bus_io};
         state[`STATE_FETCH3]:   operand <= {operand[7:0], bus_io};
      endcase
   end

   // Register IRQs.
   reg irq_pending;
   reg got_irq;
   always @(posedge clk_in) begin
      if (rst_in) begin
         irq_pending <= 0;
      end else begin
         if (state[`STATE_INT2] & got_irq)
            irq_pending <= 0;
         else if (irq_in)
            irq_pending <= ~flags[`FLAG_I];
      end
   end

   // Register NMIs.
   reg nmi_pending;
   reg got_nmi;
   always @(posedge clk_in) begin
      if (rst_in) begin
         nmi_pending <= 0;
      end else begin
         if (state[`STATE_INT2] & got_nmi)
            nmi_pending <= 0;
         else if (nmi_in)
            nmi_pending <= 1;
      end
   end

   // Process IRQs and NMIs.
   always @(posedge clk_in) begin
      if (rst_in) begin
         got_irq <= 0;
         got_nmi <= 0;
      end else begin
         if (state[`STATE_INT2]) begin
            got_irq <= 0;
            got_nmi <= 0;
         end else if (~op_swi & ~got_nmi & ~got_irq) begin
            if (nmi_pending)
               got_nmi <= 1;
            else if (irq_pending)
               got_irq <= ~flags[`FLAG_I];
         end
      end
   end

   // State logic.
   always @(posedge clk_in) begin
      if (rst_in) begin
         state <= 1 << `STATE_RESET1;
      end else begin
         case (1'b1)
            state[`STATE_RESET1]:            state <= 1 << `STATE_RESET2;
            state[`STATE_RESET2]:            state <= 1 << `STATE_FETCH;
            state[`STATE_FETCH]:
               if (got_irq | got_nmi)        state <= 1 << `STATE_PUSH_C;
               else                          state <= 1 << `STATE_DECODE;
            state[`STATE_DECODE]:
               case (1'b1)
                  op_psha:                   state <= 1 << `STATE_PUSH_A;
                  op_pshb:                   state <= 1 << `STATE_PUSH_B;
                  op_pula:                   state <= 1 << `STATE_PULL_A;
                  op_pulb:                   state <= 1 << `STATE_PULL_B;
                  op_swi:                    state <= 1 << `STATE_PUSH_C;
                  op_wai:                    state <= 1 << `STATE_WAIT;
                  op_rts:                    state <= 1 << `STATE_PULL_PCH;
                  op_rti:                    state <= 1 << `STATE_PULL_PCH;
                  default:
                     if (inherent_mode)      state <= 1 << `STATE_FETCH;
                     else                    state <= 1 << `STATE_FETCH2;
               endcase
            state[`STATE_FETCH2]:
               case (1'b1)
                  immediate_16:              state <= 1 << `STATE_FETCH3;
                  extended_mode:             state <= 1 << `STATE_FETCH3;
                  op_bsr:                    state <= 1 << `STATE_PUSH_PCL;
                  op_jsr & index_mode:       state <= 1 << `STATE_PUSH_PCL;
                  op_jmp & index_mode:       state <= 1 << `STATE_DECODE2;
                  default:
                     if (does_read)          state <= 1 << `STATE_READ1;
                     else                    state <= 1 << `STATE_DECODE2;
               endcase
            state[`STATE_FETCH3]:
               case (1'b1)
                  immediate_mode:            state <= 1 << `STATE_DECODE2;
                  op_jsr:                    state <= 1 << `STATE_PUSH_PCL;
                  op_jmp:                    state <= 1 << `STATE_DECODE2;
                  default:
                     if (does_read)          state <= 1 << `STATE_READ1;
                     else if (does_write)    state <= 1 << `STATE_WRITE1;
                     else                    state <= 1 << `STATE_FETCH;
               endcase
            state[`STATE_DECODE2]:
               if (does_write)               state <= 1 << `STATE_WRITE1;
               else if (op_cpx)              state <= 1 << `STATE_CPX;
               else                          state <= 1 << `STATE_FETCH;
            state[`STATE_READ1]:
               if (double_byte)              state <= 1 << `STATE_READ2;
               else if (does_write)          state <= 1 << `STATE_WRITE1;
               else                          state <= 1 << `STATE_FETCH;
            state[`STATE_READ2]:
               if (does_write)               state <= 1 << `STATE_WRITE1;
               else if (op_cpx)              state <= 1 << `STATE_CPX;
               else                          state <= 1 << `STATE_FETCH;
            state[`STATE_WRITE1]:
               if (double_byte)              state <= 1 << `STATE_WRITE2;
               else                          state <= 1 << `STATE_FETCH;
            state[`STATE_WRITE2]:            state <= 1 << `STATE_FETCH;
            state[`STATE_PUSH_C]:            state <= 1 << `STATE_PUSH_A;
            state[`STATE_PUSH_A]:
               if (op_psha)                  state <= 1 << `STATE_FETCH;
               else                          state <= 1 << `STATE_PUSH_B;
            state[`STATE_PUSH_B]:
               if (op_pshb)                  state <= 1 << `STATE_FETCH;
               else                          state <= 1 << `STATE_PUSH_XL;
            state[`STATE_PUSH_XL]:           state <= 1 << `STATE_PUSH_XH;
            state[`STATE_PUSH_XH]:           state <= 1 << `STATE_PUSH_PCL;
            state[`STATE_PUSH_PCL]:          state <= 1 << `STATE_PUSH_PCH;
            state[`STATE_PUSH_PCH]:
               if (got_irq | got_nmi | op_swi)
                                             state <= 1 << `STATE_INT1;
               else                          state <= 1 << `STATE_DECODE3;
            state[`STATE_PULL_PCH]:          state <= 1 << `STATE_PULL_PCL;
            state[`STATE_PULL_PCL]:
               if (op_rts)                   state <= 1 << `STATE_FETCH;
               else                          state <= 1 << `STATE_PULL_XH;
            state[`STATE_PULL_XH]:           state <= 1 << `STATE_PULL_XL;
            state[`STATE_PULL_XL]:           state <= 1 << `STATE_PULL_B;
            state[`STATE_PULL_B]:
               if (op_pulb)                  state <= 1 << `STATE_FETCH;
               else                          state <= 1 << `STATE_PULL_A;
            state[`STATE_PULL_A]:
               if (op_pula)                  state <= 1 << `STATE_FETCH;
               else                          state <= 1 << `STATE_PULL_C;
            state[`STATE_PULL_C]:            state <= 1 << `STATE_FETCH;
            state[`STATE_DECODE3]:           state <= 1 << `STATE_FETCH;
            state[`STATE_INT1]:              state <= 1 << `STATE_INT2;
            state[`STATE_INT2]:              state <= 1 << `STATE_FETCH;
            state[`STATE_WAIT]:
               if (got_irq | got_nmi)        state <= 1 << `STATE_PUSH_C;
               else                          state <= 1 << `STATE_WAIT;
            state[`STATE_CPX]:               state <= 1 << `STATE_FETCH;
         endcase
      end
   end

   // Set the program counter.
   wire [15:0] next_pc = pc + 1;
   wire [15:0] branch_pc = pc + {{8{operand[7]}}, operand[7:0]};
   wire do_branch       = (op_branch & take_branch) | op_bsr;
   wire do_jump_indexed = (op_jmp | op_jsr) & index_mode;
   wire do_jump         = (op_jmp | op_jsr) & extended_mode;
   wire set_pc_ind1     = state[`STATE_INT1] | state[`STATE_PULL_PCL];
   wire set_pc_ind2     = state[`STATE_INT2] | state[`STATE_PULL_PCH];
   wire set_pc_next     = (state[`STATE_FETCH] & ~got_irq & ~got_nmi)
                        | state[`STATE_FETCH2] | state[`STATE_FETCH3];
   wire set_pc_branch   = do_branch
                        & (state[`STATE_DECODE2] | state[`STATE_DECODE3]);
   wire set_pc_operand  = do_jump
                        & (state[`STATE_DECODE2] | state[`STATE_DECODE3]);
   wire set_pc_indexed  = do_jump_indexed
                        & (state[`STATE_DECODE2] | state[`STATE_DECODE3]);
   always @(posedge clk_in) begin: pc_logic
      if (state[`STATE_RESET1]) begin
         pc <= {8'h00, bus_io};
      end else if (state[`STATE_RESET2]) begin
         pc <= {bus_io, pc[7:0]};
      end else begin
         case (1'b1)
            set_pc_ind1:      pc <= {pc[15:8], bus_io};
            set_pc_ind2:      pc <= {bus_io, pc[7:0]};
            set_pc_next:      pc <= next_pc;
            set_pc_branch:    pc <= branch_pc;
            set_pc_operand:   pc <= operand;
            set_pc_indexed:   pc <= regx + operand[7:0];
         endcase
      end
   end

   // Determine if we should use the PC or an indirect address.
   reg read_indirect;
   always @(*) begin
      case (1'b1)
         state[`STATE_RESET1]:   read_indirect <= 1;
         state[`STATE_RESET2]:   read_indirect <= 1;
         state[`STATE_READ1]:    read_indirect <= 1;
         state[`STATE_READ2]:    read_indirect <= 1;
         state[`STATE_INT1]:     read_indirect <= 1;
         state[`STATE_INT2]:     read_indirect <= 1;
         default:                read_indirect <= is_pulling;
      endcase
   end

   // Set register A.
   always @(posedge clk_in) begin
      if (commit & (dest_rega | state[`STATE_PULL_A]))
         rega <= alu_result;
   end

   // Set register B.
   always @(posedge clk_in) begin
      if (commit & (dest_regb | state[`STATE_PULL_B]))
         regb <= alu_result;
   end

   // Buffer for the CPX instruction.
   reg [15:0] cpx_buffer;
   always @(posedge clk_in) begin
      case (1'b1)
         state[`STATE_READ1]:    cpx_buffer[15:8] <= bus_io;
         state[`STATE_READ2]:    cpx_buffer[7:0] <= bus_io;
      endcase
   end
   wire [15:0] cpx_sub = immediate_mode ? operand : cpx_buffer;
   wire [15:0] cpx_result = regx - cpx_sub;
   wire cpx_overflow = ( regx[15] & ~cpx_sub[15] & ~cpx_result[15])
                     | (~regx[15] &  cpx_sub[15] &  cpx_result[15]);

   // Set the flag register.
   always @(posedge clk_in) begin
      if (rst_in) begin
         flags <= 0;
      end else begin
         if (commit) begin
            case (1'b1)
               op_tap:
                  begin
                     flags <= alu_result;
                  end
               op_ldaa, op_ldab, op_staa, op_stab, op_tab, op_tba:
                  begin
                     flags[`FLAG_V] <= 0;
                     flags[`FLAG_Z] <= alu_result == 0;
                     flags[`FLAG_N] <= alu_result[7];
                  end
               op_lds, op_sts:
                  begin
                     flags[`FLAG_V] <= 0;
                     flags[`FLAG_Z] <= new_sp == 0;
                     flags[`FLAG_N] <= new_sp[15];
                  end
               op_ldx, op_stx:
                  begin
                     flags[`FLAG_V] <= 0;
                     flags[`FLAG_Z] <= new_regx == 0;
                     flags[`FLAG_N] <= new_regx[15];
                  end
               op_cpx:
                  begin
                     flags[`FLAG_N] <= cpx_result[15];
                     flags[`FLAG_Z] <= cpx_result == 0;
                     flags[`FLAG_V] <= cpx_overflow;
                  end
               op_inx, op_dex:
                  begin
                     flags[`FLAG_Z] <= new_regx == 0;
                  end
               op_swi:
                  begin
                     flags[`FLAG_I] <= 1;
                  end
               default:
                  begin
                     flags <= alu_flags;
                  end
            endcase
         end
      end
   end

   // Set register S.
   wire [15:0] next_sp     = sp + 1;
   wire [15:0] prev_regx   = regx - 1;
   wire set_sp_prev    = (op_des & commit) | is_pushing;
   wire set_sp_next    = (op_ins & commit) | is_pulling;
   wire set_sp_operand = op_lds & commit & immediate_mode;
   wire set_sp_regx    = op_txs & commit;
   wire set_sp_bus1    = op_lds & state[`STATE_READ1];
   wire set_sp_bus2    = op_lds & state[`STATE_READ2];
   always @(*) begin: new_sp_logic
      case (1'b1)
         set_sp_prev:      new_sp <= sp - 1;
         set_sp_next:      new_sp <= next_sp;
         set_sp_operand:   new_sp <= operand;
         set_sp_regx:      new_sp <= prev_regx;
         set_sp_bus1:      new_sp <= {bus_io, sp[7:0]};
         set_sp_bus2:      new_sp <= {sp[15:8], bus_io};
         default:          new_sp <= sp;
      endcase
   end
   always @(posedge clk_in) begin
      sp <= new_sp;
   end

   // Set register X.
   wire set_regx_prev      = op_dex & commit;
   wire set_regx_next      = op_inx & commit;
   wire set_regx_operand   = op_ldx & commit & immediate_mode;
   wire set_regx_sp        = op_tsx & commit;
   wire set_regx_bus1      = (op_ldx & state[`STATE_READ1])
                           | state[`STATE_PULL_XH];
   wire set_regx_bus2      = (op_ldx & state[`STATE_READ2])
                           | state[`STATE_PULL_XL];
   always @(*) begin: new_regx_logic
      case (1'b1)
         set_regx_prev:    new_regx <= prev_regx;
         set_regx_next:    new_regx <= regx + 1;
         set_regx_operand: new_regx <= operand;
         set_regx_sp:      new_regx <= next_sp;
         set_regx_bus1:    new_regx <= {bus_io, regx[7:0]};
         set_regx_bus2:    new_regx <= {regx[15:8], bus_io};
         default:          new_regx <= regx;
      endcase
   end
   always @(posedge clk_in) begin
      regx <= new_regx;
   end

   // Compute the first indirect address to use and latch
   // for the second address. The latch is needed for ldx instructions
   // using index mode.
   // Note that we can use operand for direct mode since the top
   // byte is zeroed when we read the one-byte operand.
   reg [15:0] base_ind_addr;
   always @(*) begin
      case (1'b1)
         index_mode:    base_ind_addr <= regx + operand[7:0];
         default:       base_ind_addr <= operand;
      endcase
   end
   always @(posedge clk_in) begin
      base_ind_addr2 <= base_ind_addr + 1;
   end

   // Indirect address.
   reg [15:0] indirect_addr;
   wire set_ind_addr1  = state[`STATE_READ1] | state[`STATE_WRITE1];
   wire set_ind_addr2  = state[`STATE_READ2] | state[`STATE_WRITE2];
   wire set_ind_psp    = is_pulling;
   wire set_ind_swi1   = state[`STATE_INT1] & op_swi;
   wire set_ind_swi2   = state[`STATE_INT2] & op_swi;
   wire set_ind_irq1   = state[`STATE_INT1] & got_irq;
   wire set_ind_irq2   = state[`STATE_INT2] & got_irq;
   wire set_ind_nmi1   = state[`STATE_INT1] & got_nmi;
   wire set_ind_nmi2   = state[`STATE_INT2] & got_nmi;
   wire set_ind_rst1   = state[`STATE_RESET1];
   wire set_ind_rst2   = state[`STATE_RESET2];
   always @(*) begin: ind_addr_logic
      case (1'b1)
         set_ind_addr1:    indirect_addr <= base_ind_addr;
         set_ind_addr2:    indirect_addr <= base_ind_addr2;
         set_ind_psp:      indirect_addr <= next_sp;
         set_ind_swi1:     indirect_addr <= 16'hFFFB;
         set_ind_swi2:     indirect_addr <= 16'hFFFA;
         set_ind_irq1:     indirect_addr <= 16'hFFF9;
         set_ind_irq2:     indirect_addr <= 16'hFFF8;
         set_ind_nmi1:     indirect_addr <= 16'hFFFD;
         set_ind_nmi2:     indirect_addr <= 16'hFFFC;
         set_ind_rst1:     indirect_addr <= 16'hFFFF;
         set_ind_rst2:     indirect_addr <= 16'hFFFE;
         default:          indirect_addr <= sp;
      endcase
   end

   // ALU operation.
   wire alu_adc = op_adca | op_adcb;  
   wire alu_add = op_aba  | op_adda | op_addb;
   wire alu_and = op_anda | op_andb | op_bita | op_bitb;
   wire alu_asl = op_asl  | op_asla | op_aslb;
   wire alu_asr = op_asr  | op_asra | op_asrb;
   wire alu_clr = op_clr  | op_clra | op_clrb;
   wire alu_com = op_com  | op_coma | op_comb;
   wire alu_dec = op_dec  | op_deca | op_decb;
   wire alu_eor = op_eora | op_eorb;
   wire alu_inc = op_inc  | op_inca | op_incb;
   wire alu_lsr = op_lsr  | op_lsra | op_lsrb;
   wire alu_neg = op_neg  | op_nega | op_negb;
   wire alu_or  = op_ora  | op_orb;
   wire alu_rol = op_rol  | op_rola | op_rolb;
   wire alu_ror = op_ror  | op_rora | op_rorb;
   wire alu_sbc = op_sbca | op_sbcb;
   wire alu_sub = op_sba  | op_suba | op_subb | op_cba  | op_cmpa | op_cmpb;
   wire alu_tst = op_tsta | op_tstb | op_tst;
   always @(*) begin: alu_op_logic
      case (1'b1)
         alu_adc:    alu_op <= `ALU_ADC;
         alu_add:    alu_op <= `ALU_ADD;
         alu_and:    alu_op <= `ALU_AND;
         alu_asl:    alu_op <= `ALU_ASL;
         alu_asr:    alu_op <= `ALU_ASR;
         alu_clr:    alu_op <= `ALU_CLR;
         alu_com:    alu_op <= `ALU_COM;
         alu_dec:    alu_op <= `ALU_DEC;
         alu_eor:    alu_op <= `ALU_EOR;
         alu_inc:    alu_op <= `ALU_INC;
         alu_lsr:    alu_op <= `ALU_LSR;
         alu_neg:    alu_op <= `ALU_NEG;
         alu_or:     alu_op <= `ALU_OR;
         alu_rol:    alu_op <= `ALU_ROL;
         alu_ror:    alu_op <= `ALU_ROR;
         alu_sbc:    alu_op <= `ALU_SBC;
         alu_sub:    alu_op <= `ALU_SUB;
         alu_tst:    alu_op <= `ALU_TST;
         op_daa:     alu_op <= `ALU_DAA;
         op_clc:     alu_op <= `ALU_CLC;
         op_cli:     alu_op <= `ALU_CLI;
         op_clv:     alu_op <= `ALU_CLV;
         op_sec:     alu_op <= `ALU_SEC;
         op_sei:     alu_op <= `ALU_SEI;
         op_sev:     alu_op <= `ALU_SEV;
         default:    alu_op <= `ALU_NOP;
      endcase
   end

   // First ALU source.
   wire srca_rega = op_aba  | op_adca | op_adda | op_anda | op_asla
                  | op_asra | op_bita | op_cba  | op_cmpa | op_coma
                  | op_daa  | op_deca | op_eora | op_inca | op_lsra
                  | op_nega | op_ora  | op_psha | op_rola | op_rora
                  | op_sba  | op_sbca | op_staa | op_suba | op_tab
                  | op_tap  | op_tsta | state[`STATE_PUSH_A];
   wire srca_regb = op_adcb | op_addb | op_andb | op_aslb | op_asrb
                  | op_bitb | op_cmpb | op_comb | op_decb | op_eorb
                  | op_incb | op_lsrb | op_negb | op_orb  | op_pshb
                  | op_rolb | op_rorb | op_sbcb | op_stab | op_subb
                  | op_tstb | op_tba  | state[`STATE_PUSH_B];
   wire srca_regc = state[`STATE_PUSH_C] | op_tpa;
   wire srca_xh   = (state[`STATE_WRITE1] & op_stx) | state[`STATE_PUSH_XH];
   wire srca_xl   = (state[`STATE_WRITE2] & op_stx) | state[`STATE_PUSH_XL];
   wire srca_sh   = state[`STATE_WRITE1] & op_sts;
   wire srca_sl   = state[`STATE_WRITE2] & op_sts;
   wire srca_pch  = state[`STATE_PUSH_PCH];
   wire srca_pcl  = state[`STATE_PUSH_PCL];
   always @(*) begin: srca_logic
      case (1'b1)
         srca_rega:  alu_srca <= rega;
         srca_regb:  alu_srca <= regb;
         srca_regc:  alu_srca <= flags;
         srca_xl:    alu_srca <= regx[7:0];
         srca_xh:    alu_srca <= regx[15:8];
         srca_sl:    alu_srca <= sp[7:0];
         srca_sh:    alu_srca <= sp[15:8];
         srca_pcl:   alu_srca <= pc[7:0];
         srca_pch:   alu_srca <= pc[15:8];
         default:
            if (immediate_mode)     alu_srca <= operand[7:0];
            else if (dest_memory)   alu_srca <= bus_latch;
            else                    alu_srca <= bus_io;
      endcase
   end

   // Second ALU source.
   wire srcb_regb = op_aba  | op_cba  | op_sba;
   always @(*) begin: srcb_logic
      case (1'b1)
         srcb_regb:        alu_srcb <= regb;
         immediate_mode:   alu_srcb <= operand[7:0];
         dest_memory:      alu_srcb <= bus_latch;
         default:          alu_srcb <= bus_io;
      endcase
   end

   // Latch the bus.
   // This is needed for instructions that use memory as both a source
   // and a destination.
   always @(posedge clk_in) begin
      bus_latch <= bus_io;
   end

   // Unless we are reading or writing an indirect address,
   // the address we want is the program counter.
   assign address_out = (read_indirect | write_out) ? indirect_addr : pc;
   assign bus_io = write_out ? alu_result : 8'bz;

endmodule

