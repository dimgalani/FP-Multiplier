module exception_handling (
    input logic [31:0] a, // Factor A
    input logic [31:0] b, // Factor B
    input logic [31:0] z_calc, // Result of multiplication
    input logic overflow, // Overflow flag
    input logic underflow, // Underflow flag
    input logic inexact, // Inexact flag
    input logic [2:0] round, // The 'round' input is 3 bits
    output logic [31:0] z, // Result of multiplication with exception handling
    output logic zero_f, 
    output logic inf_f,
    output logic nan_f,
    output logic tiny_f,
    output logic huge_f,
    output logic inexact_f
);
    typedef enum logic [2:0] {
        IEEE_near = 3'b000,  // IEEE round to nearest, even
        IEEE_zero = 3'b001,  // IEEE round towards zero
        IEEE_pinf = 3'b010,  // IEEE round to +Infinity
        IEEE_ninf = 3'b011,  // IEEE round to -Infinity
        near_up  = 3'b100,   // Round to nearest, tie closer to +Infinity
        away_zero = 3'b101   // Round away from zero
    } round_t;
    // Define the enum type for the floating-point categories
    typedef enum logic [2:0] {
        ZERO = 3'b000,
        INF = 3'b001,
        NORM = 3'b010,
        MIN_NORM = 3'b011,
        MAX_NORM = 3'b100
    } interp_t;

    // Function to interpret the floating-point number
    function automatic interp_t num_interp(logic [31:0] value); 
        logic [7:0] exponent;
        begin
            exponent = value[30:23];
            if (exponent == 8'b00000000) begin
                num_interp = ZERO; // Denormals considered as zeros (Denormals: exp = 8'b00000000 and sig > 0)
            end else if (exponent == 8'b11111111) begin
                num_interp = INF; // NaNs also considered as infinities (NaN: exp = 8'b11111111 and sig > 0)
            end else begin
                num_interp = NORM;
            end
        end
    endfunction

    // Function to calculate the floating-point number based on the interpretation
    function automatic logic [30:0] z_num(interp_t interp);
        begin
            unique case (interp) 
                ZERO: z_num = 31'b0; //00000000|00000000000000000000000
                INF: z_num = 31'b1111111100000000000000000000000;// 11111111|00000000000000000000000
                MIN_NORM: z_num = 31'b0000000100000000000000000000000; // 31'b00000001|00000000000000000000000
                MAX_NORM: z_num = 31'b1111111011111111111111111111111; // 31'b11111110|11111111111111111111111
                default: z_num = 31'b0;
            endcase
        end
    endfunction

    interp_t a_type;
    interp_t b_type;
    interp_t z_type;

    round_t round_mode;

    always_comb begin

        // Initialize status flags
        zero_f = 1'b0;
        inf_f = 1'b0;
        nan_f = 1'b0;
        tiny_f = 1'b0;
        huge_f = 1'b0;
        inexact_f = 1'b0;

        round_mode = round_t'(round); // Convert input to enum type

        // Get the type of the input numbers
        a_type = num_interp(a);
        b_type = num_interp(b);
        z_type = num_interp(z_calc);

        // Handle corner cases based on Table 4
        unique case ({a_type, b_type})
            {ZERO, ZERO}, {ZERO, NORM}, {NORM, ZERO}: begin
                // Group {+-Zero, +-Zero} and {+-Zero, +-Norm} and {+-Norm, +-Zero}
                z = {z_calc[31], z_num(ZERO)}; // Sign of z_calc with zero value
                zero_f = 1'b1; // Raise zero flag
            end
            {ZERO, INF}, {INF, ZERO}: begin
                z = {1'b0, z_num(INF)}; // Positive sign with infinity value
                inf_f = 1'b1; // Raise infinity flag
                nan_f = 1'b1; // Raise NaN flag
            end
            {INF, INF}, {INF, NORM}, {NORM, INF}: begin
                // Group {+-Inf, +-Inf} and {+-Inf, +-Norm} and {+-Norm, +-Inf}
                z = {z_calc[31], z_num(INF)}; // Sign of z_calc with infinity value
                inf_f = 1'b1; // Raise infinity flag
            end
            {NORM, NORM}: begin
                if (overflow) begin
                huge_f = 1'b1;    // Raise huge flag
                inexact_f = 1'b1; // Raise inexact flag
                case (round)
                    IEEE_near: begin
                        z = {z_calc[31], z_num(INF)}; // +Infinity or -Infinity based on sign //* a case on ieee
                        inf_f = 1'b1; 
                    end
                    IEEE_zero: z = {z_calc[31], z_num(MAX_NORM)}; // Max Normal based on sign //* b case on ieee
                    IEEE_pinf: if (z_calc[31]) begin
                        z = {z_calc[31], z_num(MAX_NORM)}; // -Max Normal for negative
                    end else begin
                        z = {z_calc[31], z_num(INF)}; // +Infinity for positive
                        inf_f = 1'b1;
                    end
                    IEEE_ninf: if (z_calc[31]) begin
                        z = {z_calc[31], z_num(INF)}; // -Infinity for negative
                        inf_f = 1'b1;
                    end else begin
                        z = {z_calc[31], z_num(MAX_NORM)}; // +Max Normal for positive
                    end
                    near_up: begin
                        z = {z_calc[31], z_num(INF)}; // +Infinity or -Infinity based on sign
                        inf_f = 1'b1;
                    end
                    away_zero: begin
                        z = {z_calc[31], z_num(INF)}; // +Infinity or -Infinity based on sign
                        inf_f = 1'b1;
                    end
                    default: begin
                        z = {z_calc[31], z_num(INF)}; // +Infinity or -Infinity based on sign
                        inf_f = 1'b1;
                    end
                endcase
                end else if (underflow) begin
                tiny_f = 1'b1;
                inexact_f = 1'b1;
                case (round)
                    IEEE_near: begin
                        z = {z_calc[31], z_num(ZERO)}; // Zero
                        zero_f = 1'b1;
                    end
                    IEEE_zero: begin 
                        z = {z_calc[31], z_num(ZERO)};
                        zero_f = 1'b1;
                    end
                    IEEE_pinf: begin
                        if (z_calc[31]) begin
                            z = {z_calc[31], z_num(ZERO)}; // Zero
                            zero_f = 1'b1;
                        end else begin
                            z = {z_calc[31], z_num(MIN_NORM)}; // Min Normal
                        end
                    end
                    IEEE_ninf: begin
                        if (z_calc[31]) begin
                            z = {z_calc[31], z_num(MIN_NORM)}; // Min Normal
                        end else begin
                            z = {z_calc[31], z_num(ZERO)}; // Zero
                            zero_f = 1'b1;
                        end
                    end
                    near_up: begin
                        z = {z_calc[31], z_num(ZERO)}; // Zero
                        zero_f = 1'b1;
                    end
                    away_zero: z = {z_calc[31], z_num(MIN_NORM)}; 
                    default: begin
                        z = {z_calc[31], z_num(ZERO)}; // Zero
                        zero_f = 1'b1;
                    end
                endcase
                end else begin
                z = z_calc;
                inexact_f = inexact;
                end
            end
            default: begin
                z = z_calc; // Default case
                inexact_f = inexact;
            end
        endcase
    end
endmodule