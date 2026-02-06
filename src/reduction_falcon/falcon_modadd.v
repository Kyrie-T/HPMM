/*
Falcon modular addition for q = 12289

To the extent possible under law, the implementer has waived all copyright
and related or neighboring rights to the source code in this file.
http://creativecommons.org/publicdomain/zero/1.0/
*/

module falcon_modadd(
    input  [13:0] A,
    input  [13:0] B,
    output [13:0] C
);

wire [14:0] R;
wire signed [15:0] Rq;

assign R  = A + B;
assign Rq = R - 15'd12289;

assign C = (Rq[15] == 0) ? Rq[13:0] : R[13:0];

endmodule
