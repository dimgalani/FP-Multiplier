`timescale 1ns/1ps
`include "multiplication.sv"

module fp_mult_tb_corner;

  // Clock and reset signals
  logic clk;
  logic rst;
  // Signal for detecting mismatches
  logic mismatch;

  // Input signals
  logic [31:0] a;
  logic [31:0] b;
  logic [2:0] rnd;

  // Output signals
  wire [31:0] z;
  wire [7:0] status;

  // Real signals for comparison
  logic [31:0] z_real, z1_real, z2_real;

  logic [31:0] corner_values [11:0];
  integer i, j, k;

  // Instantiate the Unit Under Test (UUT) with different rounding modes
  fp_mult_top uut (.clk(clk), .a(a), .b(b), .rnd(rnd), .z(z), .status(status));
  string rounding_modes_str [0:5] = {"IEEE_near", "IEEE_zero", "IEEE_pinf", "IEEE_ninf", "near_up", "away_zero"};

  // Enumeration for corner cases
  typedef enum logic [3:0] {
    pos_inf = 4'b0000,
    neg_inf = 4'b0001,
    pos_zero = 4'b0010,
    neg_zero = 4'b0011,
    pos_snan = 4'b0100,
    neg_snan = 4'b0101,
    pos_qnan = 4'b0110,
    neg_qnan = 4'b0111,
    pos_normal = 4'b1000,
    neg_normal = 4'b1001,
    pos_denormal = 4'b1010,
    neg_denormal = 4'b1011
  } corner_case_t;

  // Function to match corner cases to their values
  function automatic logic [31:0] num_match(corner_case_t corner_case);
      case (corner_case)
          pos_inf: num_match =      32'b01111111100000000000000000000000;
          neg_inf: num_match =      32'b11111111100000000000000000000000;
          pos_zero: num_match =     32'b0;
          neg_zero: num_match =     32'b10000000000000000000000000000000;
          pos_snan: num_match =     32'b01111111100000000000000000000001; // Signaling NaN one bit in mantissa is 1 other than MSB
          neg_snan: num_match =     32'b11111111100000000000000000000001;
          pos_qnan: num_match =     32'b01111111110000000000000000000000; // Quiet NaN MSB is 1
          neg_qnan: num_match =     32'b11111111110000000000000000000000;
          pos_normal: num_match =   32'b01111111000000000000000000000001; // Big positive number
          neg_normal: num_match =   32'b11111111000000000000000000000001;
          pos_denormal: num_match = 32'b00000000000000000000000000000001; // Smallest positive denormal
          neg_denormal: num_match = 32'b10000000000000000000000000000001; // Smallest negative denormal
      endcase
  endfunction

  initial begin
    clk = 0;
    rst = 1;
    #15 rst = 0;
  end

  // Clock generation
  always begin
    #7.5 clk = ~clk;
  end

  // Testbench logic
  initial begin
    corner_values = '{num_match(pos_inf), num_match(neg_inf), num_match(pos_zero), num_match(neg_zero), num_match(pos_snan), num_match(neg_snan), num_match(pos_qnan), num_match(neg_qnan), num_match(pos_normal), num_match(neg_normal), num_match(pos_denormal), num_match(neg_denormal)};
  end

  // Always block to iterate through corner cases on posedge
  always @(posedge clk) begin
    if (rst) begin
      i <= 0;
      j <= 0;
      k <= 0;
    end else begin
      // Set rounding mode
      rnd = k[2:0];

      // Set a and b values based on current indices
      a = corner_values[i];
      b = corner_values[j];

      // Calculate expected result
      z_real <= multiplication(rounding_modes_str[k], a, b);
      z1_real <= z_real;
      z2_real <= z1_real;

      // Check for mismatches
      if (z2_real != z) begin
        mismatch <= 1;
      end else begin
        mismatch <= 0;
      end

      // Update indices
      if (j < 11) begin
        j <= j + 1;
      end else if (i < 11) begin
        j <= 0;
        i <= i + 1;
      end else if (k < 5) begin
        j <= 0;
        i <= 0;
        k <= k + 1;
      end else begin
        #60;
        $finish;
      end
    end
    end
endmodule
