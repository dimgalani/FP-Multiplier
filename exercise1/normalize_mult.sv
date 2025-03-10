module normalize_mult (
    input logic [47:0] P,                    // 48-bit long multiplication result
    input logic [9:0] exponent_sum,          // 10-bit long sum of exponents subtracted by the bias
    output logic guard_bit,                  // Guard bit
    output logic sticky_bit,                 // Sticky bit
    output logic [22:0] normalized_mantissa, // 23-bit long normalized mantissa
    output logic [9:0] normalized_exponent   // 10-bit normalized exponent
);

    logic msb;        // Most significant bit of P
    logic [22:0] mantissa_temp; // Temporary mantissa storage for normalization
    logic [21:0] sticky_source; // Source bits for sticky calculation

    always_comb begin
        msb = P[47];

        if (msb == 1'b1) begin
            // MSB is the leading 1
            // MSB is 1, shift left
            // 47 46  45 44 ... -shift-> 47 46  45 44 --> change exponent
            // 1  1 . 0  1  ... -------> 1 . 1  0  1

            normalized_exponent = exponent_sum + 10'b0000000001;
            normalized_mantissa = P[46:24];
            guard_bit = P[23];
            sticky_source = P[22:0];
        end else begin
            // MSB is 0, no shift needed
            // 47 46  45 44 ...
            // 0  1 . 0  1  ...
            normalized_exponent = exponent_sum;
            normalized_mantissa = P[45:23];
            guard_bit = P[22];
            sticky_source = P[21:0];
        end
        sticky_bit = |sticky_source; // OR reduction to calculate sticky bit
    end
endmodule