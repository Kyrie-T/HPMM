/*
 * div2.v - divide by 2 with rounding for Kyber modulus 3329
 *
 * Note: This module performs (x + 1665) >> 1 when x is odd, and x >> 1 when x is even.
 *       This effectively computes round(x / 2) mod 3329, since 1665 = (3329 - 1) / 2.
 *
 *       The correction term of 1665 is added to ensure correct rounding when x is odd.
 *       For even x, no correction is needed since the division by 2 is exact.
 *
 *       This module assumes that the input x is in the range [0, 3328], which is valid for Kyber's modulus.
 */

module div2(input [11:0] x,
            output[11:0] y);

// Optimize: split into shift and conditional add to help synthesis
wire [11:0] x_shifted = {1'b0, x[11:1]};
wire [11:0] x_correction = 12'd1665;

// Use synthesis attribute to optimize critical path
(* use_dsp = "no" *)
assign y = (x[0]) ? (x_shifted + x_correction) : x_shifted;

endmodule

