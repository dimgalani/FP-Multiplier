typedef enum logic [2:0] {
        IEEE_near = 3'b000,  // IEEE round to nearest, even
        IEEE_zero = 3'b001,  // IEEE round towards zero
        IEEE_pinf = 3'b010,  // IEEE round to +Infinity
        IEEE_ninf = 3'b011,  // IEEE round to -Infinity
        near_up  = 3'b100,   // Round to nearest, tie closer to +Infinity
        away_zero = 3'b101   // Round away from zero
    } round_t;

module round_mult (
    input logic [23:0] mantissa_in,          // 24-bit mantissa (leading one + 23-bit normalized mantissa)
    input logic guard_bit,                   // Guard bit
    input logic sticky_bit,                  // Sticky bit
    input logic sign,                        // Calculated sign on first stage of the main module
    input logic [2:0] round,                 // Rounding mode (encoded as 3-bit since i need 3bit for 6 modes)
    output logic [24:0] result,              // 25-bit long result (24-bit mantissa + 1-bit for possible overflow)
    output logic inexact                     // 1-bit inexact signal
);

    logic round_increment;       // Whether to increment the mantissa
    logic [24:0] mantissa_temp;  // Temporary mantissa for calculations 25bit

    always_comb begin
        // Default: no rounding increment
        round_t rounding_mode;
        rounding_mode = round_t'(round);
        round_increment = 1'b0;

        // Determine if rounding increment is needed based on the rounding mode
        unique case (rounding_mode) // ! why unique?
            IEEE_near: round_increment = (guard_bit && (sticky_bit || mantissa_in[0])); // Round to nearest, tie to even
            IEEE_zero: round_increment = 1'b0; // Always truncate towards zero
            IEEE_pinf: round_increment = (sign == 1'b0) && (guard_bit || sticky_bit); // Round towards +Infinity if positive
            IEEE_ninf: round_increment = (sign == 1'b1) && (guard_bit || sticky_bit); // Round towards -Infinity if negative
            near_up: round_increment = guard_bit && (sign == 1'b0 || sticky_bit); // Round to nearest, tie towards +Infinity
            away_zero: round_increment = guard_bit || sticky_bit; // Round away from zero
            default: round_increment = (guard_bit && (sticky_bit || mantissa_in[0])); // Default to IEEE_near behavior
        endcase

        // Calculate the temporary mantissa with potential increment
        mantissa_temp = {1'b0, mantissa_in} + round_increment; // Extend the mantissa to handle overflow (mantissa_in is 24bit, mantissa_temp is 25bit)

        // Determine if the result is inexact, when it loses precision
        inexact = guard_bit || sticky_bit;
        result = mantissa_temp;
    end

endmodule