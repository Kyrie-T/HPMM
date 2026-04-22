
//module modsub(input [11:0] A,B,
//              output[11:0] C);

//wire signed [12:0] R;
//wire signed [12:0] Rq;

//assign R = A - B;
//assign Rq= R + 13'd3329;

//assign C = (R[12] == 0) ? R[11:0] : Rq[11:0];

//endmodule

module modsub #(
    parameter LOGQ       = 12,            // 数据位宽为 12 位
    parameter [LOGQ:0] Q_VALUE = 13'd3329 // 固定模数为 3329
) (
    input  [LOGQ-1:0] a,   // 输入 a（12 位）
    input  [LOGQ-1:0] b,   // 输入 b（12 位）
    output [LOGQ-1:0] c    // 输出 c（12 位）
);

// ------------------------------------------
// 组合逻辑实现（无时钟和寄存器）
// ------------------------------------------
wire signed [LOGQ:0]   msub;      // 临时减法结果（13 位有符号数）
wire signed [LOGQ:0] msub_q; // 加上模数后的有符号结果（13 位有符号数）

assign msub = a + ~b + 1;                // 计算 a - b（13 位有符号数）
assign msub_q = msub + Q_VALUE;     // 加上模数 3329（13 位有符号数）

// 结果选择：若 msub 非负，取减法结果；否则加上模数结果
assign c = (msub[LOGQ] == 0) ? msub[LOGQ-1:0] : msub_q[LOGQ-1:0];

endmodule
