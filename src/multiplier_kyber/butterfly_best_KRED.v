// 3 reg
module butterfly_best_KRED(
    input clk,
    input [11:0] a,
    input [11:0] b,
    output [11:0] c_mod_q
);
//stage 0
reg [23:0] high_reg;
always @(posedge clk) begin
    high_reg <= a*b;
end
// stage 1
function [63:0] LUT_parameter;
    input [3:0] LUT_index;
    integer i;
    integer full_output;
    begin
    for (i=0; i<64; i=i+1) begin
        full_output = (i << 18) % 3329;
        LUT_parameter[i] = full_output[LUT_index];
    end
    end
endfunction

wire [11:0] LUT_out;
generate
genvar i;
    for (i=0; i<12; i=i+1) begin: LUTS
        LUT6 #(
        .INIT(LUT_parameter(i))  // Specify LUT Contents
        ) LUT6_inst (
        .O(LUT_out[i]),   // LUT general output
        .I0(high_reg[18]), // LUT input
        .I1(high_reg[19]), // LUT input
        .I2(high_reg[20]), // LUT input
        .I3(high_reg[21]), // LUT input
        .I4(high_reg[22]), // LUT input
        .I5(high_reg[23])  // LUT input
        );
    end
endgenerate

wire [18:0] LUT_reduced;
assign LUT_reduced = high_reg[17:0] + LUT_out;
reg [18:0] LUT_reduced_reg;
always @(posedge clk) begin
    LUT_reduced_reg <= LUT_reduced;
end

//stage 2
wire [13:0] Kred_upper;
wire [11:0] Kred_lower;
assign Kred_upper =  LUT_reduced_reg[18:8] - {2'b0, LUT_reduced_reg[7:0], 3'b0};
assign Kred_lower = {2'b0, LUT_reduced_reg[7:0]} + {LUT_reduced_reg[7:0], 2'b0};
wire [12:0] Kred_result;
assign Kred_result = Kred_upper - Kred_lower;

reg [12:0] Kred_result_reg;
always @(posedge clk) begin
    Kred_result_reg <= Kred_result;
end
//stage 3 lazy reduction
wire [12:0] total_sum;
assign total_sum = Kred_result_reg;
wire [12:0] plus_or_zero_q;
assign plus_or_zero_q = {12{total_sum[12]}} & 12'hd01;
assign c_mod_q = total_sum + plus_or_zero_q;
endmodule

// 1 reg
// module butterfly_best_KRED(
//     input clk,
//     input [11:0] a,
//     input [11:0] b,
//     output [11:0] c_mod_q
//     );

// reg [23:0] high_reg;
// always @(posedge clk) begin
//     high_reg <= a * b;
// end

// //stage 1µÄLUTº¯Êý
// function [63:0] LUT_parameter;
//     input [3:0] LUT_index;
//     integer i;
//     integer full_output;
//     begin
//         for (i=0; i<64; i=i+1) begin
//             full_output = (i << 18) % 3329;
//             LUT_parameter[i] = full_output[LUT_index];
//         end
//     end
// endfunction

// wire [11:0] LUT_out;
// generate
//     genvar i;
//     for (i=0; i<12; i=i+1) begin: LUTS
//         LUT6 #(
//             .INIT(LUT_parameter(i))  // Specify LUT Contents
//         ) LUT6_inst (
//             .O(LUT_out[i]),   // LUT general output
//             .I0(high_reg[18]), // LUT input
//             .I1(high_reg[19]), // LUT input
//             .I2(high_reg[20]), // LUT input
//             .I3(high_reg[21]), // LUT input
//             .I4(high_reg[22]), // LUT input
//             .I5(high_reg[23])  // LUT input
//         );
//     end
// endgenerate

// wire [18:0] LUT_reduced;
// assign LUT_reduced = high_reg[17:0] + LUT_out;

// //stage 2
// wire [13:0] Kred_upper;
// wire [10:0] Kred_lower;
// assign Kred_upper =  LUT_reduced[18:8] - {2'b0, LUT_reduced[7:0], 3'b0};
// assign Kred_lower = {2'b0, LUT_reduced[7:0]} + {LUT_reduced[7:0], 2'b0};
// wire [12:0] Kred_result;
// assign Kred_result = Kred_upper - Kred_lower;

// //stage 3
// wire [12:0] total_sum;
// assign total_sum = Kred_result;
// wire [12:0] plus_or_zero_q;
// assign plus_or_zero_q = (total_sum[12] ? 12'hd01 : 0);
// assign c_mod_q = {total_sum + plus_or_zero_q, 8'b0} % 3329;

// endmodule