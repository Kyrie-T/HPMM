`timescale 1ns / 1ps

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
wire [10:0] Kred_lower;
assign Kred_upper =  LUT_reduced_reg[18:8] - {2'b0, LUT_reduced_reg[7:0], 3'b0};
assign Kred_lower = {2'b0, LUT_reduced_reg[7:0]} + {LUT_reduced_reg[7:0], 2'b0};
wire [12:0] Kred_result;
assign Kred_result = Kred_upper - Kred_lower;
reg [12:0] Kred_result_reg;
always @(posedge clk) begin
    Kred_result_reg <= Kred_result;
end
//stage 3
wire [12:0] total_sum;
assign total_sum = Kred_result_reg;
wire [12:0] plus_or_zero_q;
assign plus_or_zero_q = (total_sum[12] ? 12'hd01 : 0);
assign c_mod_q = total_sum + plus_or_zero_q;
endmodule


//module butterfly_best_KRED(
//    input clk,
//    input [11:0] a,
//    input [11:0] b,
//    output [11:0] c_mod_q
//);

//// Stage 0
//reg [23:0] high_reg;
//always @(posedge clk) high_reg <= a * b;

//localparam [767:0] LUT_INIT = {
//    64'h9911111133333332,  // LUT11
//    64'haa22266644455554,  // LUT10
//    64'h66777333111888cc,  // LUT9
//    64'h154462ab9dd4662a,  // LUT8
//    64'hd926c93649b24d92,  // LUT7
//    64'h4b4a5a52d29694b4,  // LUT6
//    64'he663331998ccc666,  // LUT5
//    64'h2aad556aab555aaa,  // LUT4
//    64'h7e07f03f01f80fc0,  // LUT3
//    64'h71c70e38f1c70e38,  // LUT2
//    64'h4936c936c936c936,  // LUT1
//    64'h2da5a5a5a5a5a5a4   // LUT0
//};
//// Stage 1
//wire [11:0] LUT_out;
//generate
//genvar i;
//    for (i = 0; i < 12; i = i + 1) begin: LUTS
//        LUT6 #(
//            .INIT(LUT_INIT[i*64 +: 64]) // 预计算的 LUT 值
//        ) LUT6_inst (
//            .O(LUT_out[i]),
//            .I0(high_reg[18]),
//            .I1(high_reg[19]),
//            .I2(high_reg[20]),
//            .I3(high_reg[21]),
//            .I4(high_reg[22]),
//            .I5(high_reg[23])
//        );
//    end
//endgenerate
//wire [12:0] low_sum = high_reg[11:0] + LUT_out; // 低 12 位加法
//wire [6:0] high_sum = high_reg[17:12] + low_sum[12]; // 高 6 位加进位
//wire [18:0] LUT_reduced = {high_sum, low_sum[11:0]}; // 合并结果
//reg [18:0] LUT_reduced_reg;
//always @(posedge clk) LUT_reduced_reg <= LUT_reduced;

//// Stage 2
//wire [13:0] Kred_upper = LUT_reduced_reg[18:8] - (LUT_reduced_reg[7:0] << 3);
//wire [10:0] Kred_lower = (LUT_reduced_reg[7:0] << 2) + {2'b0, LUT_reduced_reg[7:0]};
//wire [13:0] Kred_result = Kred_upper - Kred_lower;
//reg [13:0] Kred_result_reg; // 扩展到 14 位以容纳符号位
//always @(posedge clk) Kred_result_reg <= Kred_result;

//// Stage 3
//wire [13:0] total_sum = Kred_result_reg;
//wire [13:0] r_add = total_sum + 14'hd01; // 3329
//wire [13:0] r_unchanged = total_sum;
//assign c_mod_q = total_sum[13] ? r_add[11:0] : r_unchanged[11:0];

//endmodule

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

// //stage 1的LUT函数
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