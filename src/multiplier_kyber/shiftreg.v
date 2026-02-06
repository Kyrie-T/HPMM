
//module shiftreg #(parameter SHIFT = 0, DATA=32)
//   (input         clk,reset,
//    input  [DATA-1:0] data_in,
//    output [DATA-1:0] data_out);

//reg [DATA-1:0] shift_array [SHIFT-1:0];

//always @(posedge clk or posedge reset) begin
//    if(reset)
//        shift_array[0] <= 0;
//    else
//        shift_array[0] <= data_in;
//end

//genvar shft;

//generate
//    for(shft=0; shft < SHIFT-1; shft=shft+1) begin: DELAY_BLOCK
//        always @(posedge clk or posedge reset) begin
//            if(reset)
//                shift_array[shft+1] <= 0;
//            else
//                shift_array[shft+1] <= shift_array[shft];
//        end
//    end
//endgenerate

//assign data_out = shift_array[SHIFT-1];

//endmodule

module shiftreg #(
    parameter SHIFT = 32,  // 移位级数
    parameter DATA  = 32   // 数据位宽
) (
    input              clk, reset,      // 时钟和异步复位
    input  [DATA-1:0]  data_in,         // 输入数据
    output [DATA-1:0]  data_out         // 输出数据
);

generate
    if (SHIFT == 0) begin
        // 延迟为0，直接连接输入到输出
        assign data_out = data_in;
    end 
    else if (SHIFT == 1) begin
        // 延迟为1，只用一个寄存器
        reg [DATA-1:0] shift_reg;
        always @(posedge clk or posedge reset) begin
            if (reset)
                shift_reg <= 0;
            else
                shift_reg <= data_in;
        end
        assign data_out = shift_reg;
    end 
    else begin
        // 延迟大于1，使用SRLC32E实现SHIFT-1级移位，再接一个寄存器
        wire [DATA-1:0] srl_out;
        reg [DATA-1:0] output_reg;

        genvar i;
        for (i = 0; i < DATA; i = i + 1) begin : BIT_SHIFT
            SRLC32E #(
                .INIT(32'h00000000)  // 初始化值
            ) srl_inst (
                .A(SHIFT-2),         // 设置SHIFT-1级移位
                .CE(1'b1),           // 始终使能
                .CLK(clk),           // 时钟
                .D(data_in[i]),      // 输入数据
                .Q(srl_out[i]),      // 移位输出
                .Q31()               // 未使用
            );
        end

        // 输出寄存器捕获SRL输出并支持复位
        always @(posedge clk or posedge reset) begin
            if (reset)
                output_reg <= 0;
            else
                output_reg <= srl_out;
        end

        assign data_out = output_reg;
    end
endgenerate

endmodule

