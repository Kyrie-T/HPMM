
//module div2(input [11:0] x,
//            output[11:0] y);

//wire [10:0] x0and;

//assign x0and = {11{x[0]}} & 11'd1665;
//assign y     = x[11:1] + x0and;

//endmodule

module div2(input [11:0] x,
            output[11:0] y);

// Optimize: split into shift and conditional add to help synthesis
wire [11:0] x_shifted = {1'b0, x[11:1]};
wire [11:0] x_correction = 12'd1665;

// Use synthesis attribute to optimize critical path
(* use_dsp = "no" *)
assign y = (x[0]) ? (x_shifted + x_correction) : x_shifted;

endmodule

