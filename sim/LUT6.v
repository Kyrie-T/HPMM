// Behavioral model of Xilinx LUT6 for Verilator simulation
module LUT6 (
    output O,
    input  I0, I1, I2, I3, I4, I5
);
    parameter [63:0] INIT = 64'h0000000000000000;

    wire [5:0] addr = {I5, I4, I3, I2, I1, I0};
    assign O = INIT[addr];
endmodule
