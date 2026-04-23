
module modsub #(
    parameter LOGQ       = 12,            // Data width: 12 bits
    parameter [LOGQ:0] Q_VALUE = 13'd3329 // Fixed modulus: 3329
) (
    input  [LOGQ-1:0] a,   // Input a (12 bits)
    input  [LOGQ-1:0] b,   // Input b (12 bits)
    output [LOGQ-1:0] c    // Output c (12 bits)
);

// ------------------------------------------
// Combinational implementation (no clock or registers)
// ------------------------------------------
wire signed [LOGQ:0]   msub;      // Temporary subtraction result (13-bit signed)
wire signed [LOGQ:0] msub_q; // Signed result after adding modulus (13-bit signed)

assign msub = a + ~b + 1;                // Compute a - b (13-bit signed)
assign msub_q = msub + Q_VALUE;     // Add modulus 3329 (13-bit signed)

// Select result: if msub is non-negative, use msub; otherwise use msub_q
assign c = (msub[LOGQ] == 0) ? msub[LOGQ-1:0] : msub_q[LOGQ-1:0];

endmodule

