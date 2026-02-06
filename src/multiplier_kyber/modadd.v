
// module modadd(input [11:0] A,B,
//               output[11:0] C);

// wire        [12:0] R;
// wire signed [13:0] Rq;

// assign R = A + B;
// assign Rq= R - 13'd3329;

// assign C = (Rq[13] == 0) ? Rq[11:0] : R[11:0];

// endmodule

module modadd #(
    parameter LOGQ       = 12,            // 数据位宽为 12 位（对应 12 位输入输出）
    parameter [LOGQ:0] Q_VALUE = 13'd3329 // 固定模数为 3329（需 13 位存储）
) (
    input  [LOGQ-1:0] a,   // 输入 a（12 位）
    input  [LOGQ-1:0] b,   // 输入 b（12 位）
    output [LOGQ-1:0] c    // 输出 c（12 位）
);

// ------------------------------------------
// 组合逻辑实现（无时钟和寄存器）
// ------------------------------------------
wire [LOGQ:0]   madd;      // 临时加法结果（13 位）
wire signed [LOGQ+1:0] madd_q; // 模减后的有符号结果（14 位）

assign madd = a + b;                // 计算 a + b（13 位）
assign madd_q = madd - Q_VALUE;     // 减去模数 3329（14 位有符号数）

// 结果选择：若 madd_q 非负，取低 12 位；否则保留加法结果
assign c = (madd_q[LOGQ+1] == 0) ? madd_q[LOGQ-1:0] : madd[LOGQ-1:0];

endmodule

//module modadd #(
//    parameter LOGQ       = 12,
//    parameter [LOGQ:0] Q_VALUE = 13'd3329
//) (
//    input  [LOGQ-1:0] a,
//    input  [LOGQ-1:0] b,
//    output [LOGQ-1:0] c
//);

//wire [LOGQ:0] madd = a + b;            // 单一加法
//wire [LOGQ:0] sub_result = (madd >= Q_VALUE) ? madd - Q_VALUE : madd;
//assign c = sub_result[LOGQ-1:0];       // 取低 12 位

//endmodule
