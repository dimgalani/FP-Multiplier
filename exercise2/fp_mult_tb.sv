`timescale 1ns/1ps
`include "multiplication.sv"

module fp_mult_tb;

  // Signals
  logic clk;
  logic rst;
  logic mismatch; // Signal for detecting mismatches

  logic [31:0] a;
  logic [31:0] b;
  logic [2:0] rnd;

  wire [31:0] z;
  wire [7:0] status;

  logic [31:0] z_real, z1_real, z2_real; // Signals from the wrapper
  integer i, j;

  // Instantiate the Unit Under Test (UUT)
  fp_mult_top uut (.clk(clk), .rst(rst), .a(a), .b(b), .rnd(rnd), .z(z), .status(status));
  //String array for rounding modes
  string rounding_modes_str [0:5] = {"IEEE_near", "IEEE_zero", "IEEE_pinf", "IEEE_ninf", "near_up", "away_zero"};

  initial begin
      clk = 0;
      rst = 1;
      #9 rst = 0;
      mismatch = 0;
      i = 0;
      j = 0;
  end

  always begin
      #7.5 clk = ~clk;
  end

  always @(posedge clk) begin
      if (rst == 1) begin
          // Reset signals
          a <= 32'b0;
          b <= 32'b0;
          rnd <= 3'b0;
          i<=0;
          j<=0;
      end else begin
          // Generate random numbers
          a = $urandom();
          b = $urandom();
          // Define the current rounding mode
          rnd = j[2:0]; // j is the number of the rounding
          // Calculate expected result
          z_real <= multiplication(rounding_modes_str[j], a, b); // Considering the rounding mode j, chooses the correct string
          z1_real <= z_real;
          z2_real <= z1_real;
          // Check for mismatches
          if (z2_real != z) begin
              mismatch <= 1;
          end else begin
              mismatch <= 0;
          end
          // Update indices
          if (i < 9) begin // 10 examples of each rounding mode
              i <= i + 1;
          end else if (j < 5) begin // Change rounding mode 6 rounding modes
              i <= 0;
              j <= j + 1;

          end else begin
              #60;
              $finish;
          end
          end
      end
  endmodule