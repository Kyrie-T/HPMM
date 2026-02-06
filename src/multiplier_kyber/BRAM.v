
// read latency is 1 cc

module BRAM #(
    parameter LENBR = 255
) (input             clk,
            input             wen,
            input      [7:0]  waddr,
            input      [11:0] din,
            input      [7:0]  raddr,
            output reg [11:0] dout);
// bram
(* ram_style="block" *) reg [11:0] blockram [0:LENBR];

// write operation
always @(posedge clk) begin
    if(wen)
        blockram[waddr] <= din;
end

// read operation
always @(posedge clk) begin
    dout <= blockram[raddr];
end

endmodule
