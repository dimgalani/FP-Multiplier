module fp_mult (
    input logic [31:0] a,      // 32-bit input a
    input logic [31:0] b,      // 32-bit input b
    input logic [2:0] rnd,     // 3-bit rounding mode
    output logic [31:0] z,     // 32-bit result
    output logic [7:0] status  // 8-bit status flag
);

    // Internal signals
    logic sign_a, sign_b, sign_z;
    logic [7:0] exp_a, exp_b; 
    logic [9:0] exp_sum, exp_norm; // 10-bit exponent
    logic [47:0] prod;
    logic [23:0] mant_a, mant_b; // mantissa with leading one
    logic [22:0] mant_norm; // normalized mantissa
    logic guard_bit, sticky_bit;
    logic [24:0] mant_round; // mantissa after rounding with possible overflow
    logic overflow, underflow, inexact;
    logic zero_f, inf_f, nan_f, tiny_f, huge_f, inexact_f;
    logic [23:0] post_rounding_mantissa;
    logic [9:0] temp;
    logic addition;

    always_comb begin
        // Step 1: Floating point number sign calculation
        sign_a = a[31];
        sign_b = b[31];
        sign_z = sign_a ^ sign_b; // Result sign

        // Step 2: Exponent addition
        exp_a = a[30:23];
        exp_b = b[30:23];
        exp_sum = exp_a + exp_b - 8'd127; // Exponent addition and bias subtraction
        // exp_sum is 2's complement 

        // Step 3: Extract mantissas and add leading one
        mant_a = {1'b1, a[22:0]};
        mant_b = {1'b1, b[22:0]};

        // Step 4: Mantissa multiplication
        prod = mant_a * mant_b;

        addition = (mant_round[24] == 1'b1) ? 1 : 0; // Check if the mantissa has overflowed
        if (addition == 1) begin
            post_rounding_mantissa = mant_round >> 1; // Shift right to remove the overflow //it takes the LSB into post_rounding_mantissa
        end else begin
            post_rounding_mantissa = mant_round; // It takes the LSB into post_rounding_mantissa
        end
        temp = exp_norm + addition; // Add the overflow to the exponent

        // Step 7: Check for exceptions
        // Calculate overflow and underflow
        overflow = ($signed(temp) > $signed(254));
        underflow = ($signed(temp) < $signed(1));

        status = {2'b0, inexact_f, huge_f, tiny_f, nan_f, inf_f, zero_f};
    end

    // Step 5: Truncation and normalization
    normalize_mult norm_mult_inst (
        .P(prod),
        .exponent_sum(exp_sum[9:0]),
        .guard_bit(guard_bit),
        .sticky_bit(sticky_bit),
        .normalized_mantissa(mant_norm),
        .normalized_exponent(exp_norm)
    );

        // Step 6: Rounding

    round_mult round_mult_inst (
        .mantissa_in({1'b1, mant_norm}),
        .guard_bit(guard_bit),
        .sticky_bit(sticky_bit),
        .sign(sign_z),
        .round(rnd),
        .result(mant_round),
        .inexact(inexact)
    );

                // Step 8: Exception handling
    exception_handling exc_handling_inst (
        .a(a),
        .b(b),
        .z_calc({sign_z, temp[7:0], post_rounding_mantissa[22:0]}), // Throw away the leading 1 and the overflow bit of the mantissa
        .overflow(overflow),
        .underflow(underflow),
        .inexact(inexact),
        .round(rnd),
        .z(z),
        .zero_f(zero_f),
        .inf_f(inf_f),
        .nan_f(nan_f),
        .tiny_f(tiny_f),
        .huge_f(huge_f),
        .inexact_f(inexact_f)
    );
endmodule