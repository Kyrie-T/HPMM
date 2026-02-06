/*
Falcon division by 2 modulo q = 12289

Computes: y = x * 2^(-1) mod 12289
where 2^(-1) mod 12289 = 6145

For even x: y = x / 2
For odd x:  y = (x + q) / 2 = x/2 + 6145 (integer arithmetic)

To the extent possible under law, the implementer has waived all copyright
and related or neighboring rights to the source code in this file.
http://creativecommons.org/publicdomain/zero/1.0/
*/

module falcon_div2(
    input  [13:0] x,
    output [13:0] y
);

// 2^(-1) mod 12289 = 6145
// If x is odd: y = x[13:1] + 6145
// If x is even: y = x[13:1]
// Note: Must use 14-bit arithmetic to avoid overflow
wire [13:0] x0and;

assign x0and = {14{x[0]}} & 14'd6145;
assign y     = {1'b0, x[13:1]} + x0and;

endmodule
