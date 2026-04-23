
module modadd #(
    parameter LOGQ       = 12,            // Bit width of input/output operands
    parameter [LOGQ:0] Q_VALUE = 13'd3329 // Fixed modulus 3329 stored in 13 bits
) (
    input  [LOGQ-1:0] a,   // Input a (12-bit when LOGQ=12)
    input  [LOGQ-1:0] b,   // Input b (12-bit when LOGQ=12)
    output [LOGQ-1:0] c    // Output c (12-bit when LOGQ=12)
);

// ------------------------------------------
// Combinational logic (no clock/register)
// ------------------------------------------
wire [LOGQ:0]   madd;      // Intermediate sum (13-bit)
wire signed [LOGQ+1:0] madd_q; // Sum minus modulus (signed 14-bit)

assign madd = a + b;                // Compute a + b
assign madd_q = madd - Q_VALUE;     // Subtract modulus 3329

// If madd_q is non-negative, use reduced value; otherwise keep raw sum
assign c = (madd_q[LOGQ+1] == 0) ? madd_q[LOGQ-1:0] : madd[LOGQ-1:0];

endmodule

