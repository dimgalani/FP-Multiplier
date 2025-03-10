`timescale 1ns / 1ps

// Part 1: Immediate Assertions
module test_status_bits(
  input logic clk,
  input logic [7:0] status
);
always @(posedge clk) begin
    if (status!== 8'bx) begin
        zero_infinity:   assert (!(status[0] && status[1])) $display("PASS-IMMEDIATE"); else $display("FAIL: Zero and Infinity flags both asserted.");
        zero_invalid:    assert (!(status[0] && status[2])) $display("PASS-IMMEDIATE"); else $display("FAIL: Zero and Invalid flags both asserted.");
        zero_huge:       assert (!(status[0] && status[4])) $display("PASS-IMMEDIATE"); else $display("FAIL: Zero and Huge flags both asserted.");
        infinity_tiny:   assert (!(status[1] && status[3])) $display("PASS-IMMEDIATE"); else $display("FAIL: Infinity and Tiny flags both asserted.");
        invalid_tiny:    assert (!(status[2] && status[3])) $display("PASS-IMMEDIATE"); else $display("FAIL: Tiny and Invalid flags both asserted.");   
        invalid_huge:    assert (!(status[2] && status[4])) $display("PASS-IMMEDIATE"); else $display("FAIL: Huge and Invalid flags both asserted.");
        invalid_inexact: assert (!(status[2] && status[5])) $display("PASS-IMMEDIATE"); else $display("FAIL: Inexact and Invalid flags both asserted.");
        tiny_huge:       assert (!(status[3] && status[4])) $display("PASS-IMMEDIATE"); else $display("FAIL: Tiny and Huge flags both asserted.");
    end
end
endmodule

// Part 2: Concurrent Assertions
module test_status_z_combinations (
    input logic clk,
    input logic [7:0] status,      // 8-bit status input
    input logic [31:0] z,
    input logic [31:0] a,
    input logic [31:0] b
);

    logic [7:0] exponent_z, exponent_a, exponent_b;
    logic [22:0] mantissa_z;
  // Extract exponents and mantissas
  always_comb begin
    exponent_z = z[30:23];
    exponent_a = a[30:23];
    exponent_b = b[30:23];
    mantissa_z = z[22:0];
  end

  // If the 'zero' status bit asserts to 1 then at the same cycle all the bits of the exponent of 'z' must be equal to 0.
  property zero_exponent_zero;
    @(posedge clk)
      (status[0] |-> (exponent_z === 8'b00000000));
  endproperty
  assert property (zero_exponent_zero) $display("PASS -- CONCURRENT --"); else $display("FAIL: Exponent's bits of 'z' are not all zeros when 'zero' is asserted.");

  // If the 'inf' status bit asserts to 1 then at the same cycle all the bits of the exponent of 'z' must be equal to 1.
  property inf_exponent_all_ones;
    @(posedge clk)
      (status[1] |-> (exponent_z === 8'b11111111));
  endproperty
  assert property (inf_exponent_all_ones) $display("PASS -- CONCURRENT --"); else $display("FAIL: Exponent's bits of 'z' are not all ones when 'inf' is asserted.");

  // If the 'invalid', 'nan', status bit asserts to 1 then 2 cycles before all the bits of the exponent of 'a' must be equal to 0
  // and the bits of the exponent of 'b' must be equal to 1 or the opposite.
  property nan_exponent_check;
    @(posedge clk) 
      (status[2] |-> ($past(exponent_a, 2) === 8'b00000000 && $past(exponent_b, 2) === 8'b11111111) || ($past(exponent_a, 2) === 8'b11111111 && $past(exponent_b, 2) === 8'b00000000));
  endproperty
  assert property (nan_exponent_check) $display("PASS -- CONCURRENT --"); else $display("FAIL: Exponent condition for 'a' and 'b' not met 2 cycles before 'invalid' is asserted.");

  // If the 'huge' status bit asserts to 1 then at the same cycle all the bits of the exponent of 'z' must be equal to 1,
  // or all the bits of the exponent of 'z' except the LSB must be equal to 1, the LSB must be 0, and all the bits of the mantissa of 'z' to be equal to 1 (maxNormal case).
  property huge_exponent_check;
    @(posedge clk)
      (status[4] |-> ((exponent_z === 8'b11111111) || ((exponent_z === 8'b11111110) && (mantissa_z === 23'b11111111111111111111111))));
  endproperty
  assert property (huge_exponent_check) $display("PASS -- CONCURRENT --"); else $display("FAIL: 'z' is not in expected state when 'huge' is asserted.");

  // If the 'tiny' status bit asserts to 1 then at the same cycle all the bits of the exponent of 'z' must be equal to 0,
  // or all the bits of the exponent of 'z' except the LSB must be equal to 0, the LSB must be 1, and all the bits of the mantissa of 'z' to be equal to 0 (minNormal case).
  property tiny_exponent_check;
    @(posedge clk)
      (status[3] |-> ((exponent_z === 8'b00000000) || ((exponent_z === 8'b00000001) && (mantissa_z === 23'b00000000000000000000000))));
  endproperty
  assert property (tiny_exponent_check) $display("PASS -- CONCURRENT --"); else $display("FAIL: 'z' is not in expected state when 'tiny' is asserted.");

endmodule

module assertions_test();
    logic clk;
    logic rst;
    logic [7:0] status;
    logic [31:0] z;
    logic [31:0] a;
    logic [31:0] b;
    logic rnd;

    fp_mult_top mymult(.clk(clk), .rst(rst), .rnd(rnd), .a(a), .b(b), .z(z), .status(status));

    bind mymult test_status_z_combinations test_status_z_combinations_DUT(.clk(clk), .status(status), .z(z), .a(a), .b(b));
    bind mymult test_status_bits test_status_bits_DUT(.clk(clk), .status(status));
    initial begin
        clk = 0;
        rst = 1;
        rnd = 3'b000;
        #10 rst = 0;
    end

    always begin
        #7.5 clk = ~clk;
    end

    always @(posedge clk) begin
        a = $urandom();
        b = $urandom();
    end
endmodule