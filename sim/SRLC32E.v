// Behavioral model of Xilinx SRLC32E for Verilator simulation
module SRLC32E (
    output Q,
    output Q31,
    input  [4:0] A,
    input  CE,
    input  CLK,
    input  D
);
    parameter [31:0] INIT = 32'h00000000;

    reg [31:0] shift_reg;

    initial begin
        shift_reg = INIT;
    end

    always @(posedge CLK) begin
        if (CE)
            shift_reg <= {shift_reg[30:0], D};
    end

    assign Q   = shift_reg[A];
    assign Q31 = shift_reg[31];
endmodule
