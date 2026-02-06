module addressgenerator (input             clk,reset,
                         input             start_fntt,start_pwm2,start_intt,
                         output reg        ct,
                         output reg        pwm,
                         output reg [7:0]  raddr0,raddr1,
                         output reg [7:0]  waddr0,waddr1,
                         output reg        wen0  ,wen1  ,
                         output reg        brsel0,brsel1,
                         output reg        brselen0,brselen1,
                         output reg [2:0]  stage_count,
                         output reg [2:0]  stage_count_pwm,
                         output reg [6:0]  c_loop_pwm,
                         output reg [6:0]  raddr_b,
                         output reg [8:0]  raddr_tw);

// ---------------------------------------------------------------------------

// Control signals
// 计数器
reg [2:0] c_stage;
reg [6:0] c_loop;
reg [2:0] c_pwm;
reg [8:0] c_tw;     // 指数

// ---------------------------------------------------------------------------
// FSM
/*
FSM:

-- IDLE
-- NTT
-- PWM
-- INTT

*/

parameter IDLE = 2'b00;
parameter FNTT = 2'b01;
parameter PWM2 = 2'b10;
parameter INTT = 2'b11;

reg [1:0] curr_state,next_state;

always @(posedge clk or posedge reset) begin
    if(reset)
        curr_state <= 0;
    else
        curr_state <= next_state;
end

always @(*) begin
    case(curr_state)
	// ---------------------------------------- IDLE
	IDLE: begin
        if(start_fntt)
            next_state = FNTT;
        else if(start_pwm2)
            next_state = PWM2;
        else if(start_intt)
            next_state = INTT;
        else
            next_state = IDLE;
    end
    // ---------------------------------------- FNTT
    FNTT: begin
        if((c_stage == 3'd6) && (c_loop == 7'd127))
            next_state = IDLE;
        else
            next_state = FNTT;
    end
    // ---------------------------------------- PWM2
    PWM2: begin
        if((c_pwm == 3'd4) && (c_loop == 7'd127))
            next_state = IDLE;
        else
            next_state = PWM2;
    end
    // ---------------------------------------- INTT
    INTT: begin
        if((c_stage == 3'd6) && (c_loop == 7'd127))
            next_state = IDLE;
        else
            next_state = INTT;
    end
    // ---------------------------------------- Default
    default: begin
        next_state = IDLE;
    end
    endcase
end

// ---------------------------------------------------------------------------
// Control operations

// counters (NTT)
always @(posedge clk or posedge reset) begin
    if(reset) begin
        c_stage <= 0;
        c_loop  <= 0;
        c_pwm   <= 0;
        c_tw    <= 0;
    end
    else begin
        if(start_fntt || start_pwm2 || start_intt) begin
            c_stage <= 0;
            c_loop  <= 0;
            c_pwm   <= 0;
            c_tw    <= (start_intt) ? 9'd127 : ((start_pwm2) ? 9'd254 : 0);
        end
        else if(curr_state == FNTT) begin
            // ------------------------------- c_stage
            if(c_loop == 7'd127)
                c_stage <= (c_stage == 3'd6) ? 3'd6 : (c_stage + 3'd1);
            else
                c_stage <= c_stage;
            // ------------------------------- c_loop
            if(c_loop == 7'd127)
                c_loop <= 7'd0;
            else
                c_loop <= c_loop + 7'd1;
            // ------------------------------- c_tw
            if (c_loop == 7'd127) begin
                c_tw <= c_tw+9'd1;
            end
            else begin
                case(c_stage)
                3'd0: begin c_tw <= c_tw; end
                3'd1: begin c_tw <= (c_loop[5:0] == 6'd63) ? (c_tw+9'd1) : c_tw; end
                3'd2: begin c_tw <= (c_loop[4:0] == 5'd31) ? (c_tw+9'd1) : c_tw; end
                3'd3: begin c_tw <= (c_loop[3:0] == 4'd15) ? (c_tw+9'd1) : c_tw; end
                3'd4: begin c_tw <= (c_loop[2:0] == 3'd7)  ? (c_tw+9'd1) : c_tw; end
                3'd5: begin c_tw <= (c_loop[1:0] == 2'd3)  ? (c_tw+9'd1) : c_tw; end
                3'd6: begin c_tw <= (c_loop[0:0] == 1'd1)  ? (c_tw+9'd1) : c_tw; end
                endcase
            end
        end
        else if(curr_state == PWM2) begin
            c_stage <= 0;
            c_loop  <= (c_pwm == 3'd4) ? (c_loop+7'd1) : c_loop;
            c_pwm   <= (c_pwm == 3'd4) ? 3'd0 : (c_pwm+3'd1);
            c_tw    <= (c_pwm == 3'd4) ? (c_tw+9'd1) : c_tw;
        end
        else if(curr_state == INTT) begin
            // ------------------------------- c_stage
            if(c_loop == 7'd127)
                c_stage <= (c_stage == 3'd6) ? 3'd6 : (c_stage + 3'd1);
            else
                c_stage <= c_stage;
            // ------------------------------- c_loop
            if(c_loop == 7'd127)
                c_loop <= 7'd0;
            else
                c_loop <= c_loop + 7'd1;
            // ------------------------------- c_tw
            if (c_loop == 7'd127) begin
                c_tw <= c_tw+9'd1;
            end
            else begin
                case(c_stage)
                0: begin c_tw <= (c_loop[0] == 1'b0) ? (c_tw+9'd1) : (c_tw-9'd1 + ((c_loop[1:0]==2'd3)<<1)); end
                1: begin c_tw <= (c_loop[0] == 1'b0) ? (c_tw+9'd1) : (c_tw-9'd1 + ((c_loop[2:0]==3'd7)<<1)); end
                2: begin c_tw <= (c_loop[0] == 1'b0) ? (c_tw+9'd1) : (c_tw-9'd1 + ((c_loop[3:0]==4'd15)<<1)); end
                3: begin c_tw <= (c_loop[0] == 1'b0) ? (c_tw+9'd1) : (c_tw-9'd1 + ((c_loop[4:0]==5'd31)<<1)); end
                4: begin c_tw <= (c_loop[0] == 1'b0) ? (c_tw+9'd1) : (c_tw-9'd1 + ((c_loop[5:0]==6'd63)<<1)); end
                5: begin c_tw <= (c_loop[0] == 1'b0) ? (c_tw+9'd1) : (c_tw-9'd1 + ((c_loop[6:0]==7'd127)<<1)); end
                6: begin c_tw <= c_tw; end
                endcase
            end
        end
        else begin // curr_state == IDLE
            c_stage <= 0;
            c_loop  <= 0;
            c_pwm   <= 0;
            c_tw    <= 0;
        end
    end
end


// --------------------------------------------------------------------------- signals

reg [7:0] raddr;
reg [7:0] waddre,waddro;
reg       wen;
reg       brsel;
reg       brselen;

// --------------------------------------------------------------------------- raddr (c_loop)
always @(posedge clk or posedge reset) begin
    if(reset) begin
        raddr[7] <= 0; // alternating addressing between stages
    end
    else begin
        if(start_fntt || start_pwm2 || start_intt) begin
            raddr[7] <= (start_fntt) ? 0 : 1;
        end
        else if((raddr[6:0] == 7'd127) && ((curr_state == FNTT) || (curr_state == INTT))) begin
            // negate for next stage
            raddr[7] <= ~raddr[7];
        end
        else begin
            // otherwise, keep it
            raddr[7] <= raddr[7];
        end
    end
end

always @(posedge clk or posedge reset) begin
    if(reset) begin
        raddr[6:0] <= 0;
    end
    else begin
        if(start_fntt || start_pwm2 || start_intt) begin
            raddr[6:0] <= 0;
        end
        else if(curr_state == FNTT) begin
            if(c_stage == 3'd6)
                raddr[6:0] <= c_loop;
            else begin
                raddr[6:0] <= ((c_loop>>1) & ((1<<(3'd6-c_stage))-1))
                            + (c_loop[0] << (3'd6-c_stage))
                            + ((c_loop>>(3'd7-c_stage)) << (3'd7-c_stage));
            end
        end
        else if(curr_state == PWM2) begin
            raddr[6:0] <= (c_pwm<2) + ((c_loop>>1)<<1);
        end
        else if(curr_state == INTT) begin
            if(c_stage == 3'd6)
                raddr[6:0] <= c_loop;
            else begin
                raddr[6:0] <= ((c_loop>>1) & ((1<<(c_stage+3'd1))-1))
                            + (c_loop[0] << (c_stage+3'd1))
                            + ((c_loop>>(c_stage+3'd2)) << (c_stage+3'd2));
            end
        end
        else begin
            raddr[6:0] <= 0;
        end
    end
end

// --------------------------------------------------------------------------- raddr_b
reg [6:0] raddr_b_w;

always @(posedge clk or posedge reset) begin
    if(reset) begin
        raddr_b_w <= 0;
    end
    else begin
        if(curr_state == PWM2) begin
            raddr_b_w <= c_pwm[0] + ((c_loop>>1)<<1);
        end
        else begin
            raddr_b_w <= 0;
        end
    end
end

// --------------------------------------------------------------------------- waddr,wen,brsel (c_loop)

always @(posedge clk or posedge reset) begin
    if(reset) begin
        waddre[7] <= 0;
        waddro[7] <= 0;
    end
    else begin
        if(start_fntt || start_pwm2 || start_intt) begin
            waddre[7] <= (start_fntt || start_pwm2) ? 1 : 0;
            waddro[7] <= (start_fntt || start_pwm2) ? 1 : 0;
        end
        else if((waddro[6:0] == 7'd127) && (c_loop == 7'd0) && ((curr_state == FNTT) || (curr_state == INTT))) begin
            // negate for next stage
            waddre[7] <= ~waddre[7];
            waddro[7] <= ~waddro[7];
        end
        else begin
            // otherwise, keep it
            waddre[7] <= waddre[7];
            waddro[7] <= waddro[7];
        end
    end
end

always @(posedge clk or posedge reset) begin
    if(reset) begin
        waddre[6:0] <= 0;
        waddro[6:0] <= 0;
        wen         <= 0;
        brsel       <= 0;
        brselen     <= 0;
    end
    else begin
        if(start_fntt || start_pwm2 || start_intt) begin
            waddre[6:0] <= 0;
            waddro[6:0] <= 0;
            wen         <= 0;
            brsel       <= 0;
            brselen     <= 0;
        end
        else if (curr_state == FNTT)begin
            if(c_stage == 3'd6) begin
                waddre[6:0] <= c_loop;
                waddro[6:0] <= c_loop;
            end
            else begin
                waddre[6:0] <= (c_loop>>1) + ((c_loop>>(3'd7-c_stage)) << (3'd6-c_stage));
                waddro[6:0] <= (c_loop>>1) + ((c_loop>>(3'd7-c_stage)) << (3'd6-c_stage)) + (1 << (3'd6-c_stage));
            end
            wen         <= 1;
            brsel       <= c_loop[0];
            brselen     <= 1;
        end
        else if (curr_state == PWM2) begin
            waddre[6:0] <= ((0<c_pwm) && (c_pwm<3)) + ((c_loop>>1)<<1);
            waddro[6:0] <= ((0<c_pwm) && (c_pwm<3)) + ((c_loop>>1)<<1);
            wen         <= (c_pwm == 3'd3) ? 1 : 0; 
            brsel       <= 0;
            brselen     <= 0;
        end
        else if (curr_state == INTT) begin
            if(c_stage == 3'd6) begin
                waddre[6:0] <= c_loop;
                waddro[6:0] <= c_loop;
            end
            else begin
                waddre[6:0] <= (c_loop>>1) + ((c_loop>>(c_stage+3'd2)) << (c_stage+3'd1));
                waddro[6:0] <= (c_loop>>1) + ((c_loop>>(c_stage+3'd2)) << (c_stage+3'd1)) + (1 << (c_stage+3'd1));
            end
            wen         <= 1;
            brsel       <= c_loop[0];
            brselen     <= 1;
        end
        else begin
            waddre[6:0] <= 0;
            waddro[6:0] <= 0;
            wen         <= 0;
            brsel       <= 0;
            brselen     <= 0;
        end
    end
end

reg b_ct;
reg b_pwm;

// --------------------------------------------------------------------------- ct, pwm
always @(posedge clk or posedge reset) begin
    if(reset) begin
        b_ct  <= 0;
        b_pwm <= 0;
    end
    else begin
        if((curr_state == FNTT) || (curr_state == PWM2))
            b_ct <= 1;
        else if(curr_state == INTT)
            b_ct <= 0;
        else
            b_ct <= b_ct;

        if(curr_state == PWM2)
            b_pwm <= (c_pwm == 3'd4) ? 1 : 0;
        else
            b_pwm <= 0;
    end
end

// --------------------------------------------------------------------------- delays

wire       ctd0;
wire       pwmd0;
wire [7:0] waddrd0;
wire [7:0] waddrd1;
wire       wend0;
wire       wend1;
wire       brseld0;
wire       brseld1;
wire       brselend0;
wire       brselend1;
wire [2:0] stage_countd0;
wire [2:0] stage_count_pwmd0;
wire [6:0] c_loop_pwmd0;
wire [6:0] raddr_b_wd0;
wire [8:0] raddr_twd0;

// init li's ise
// shiftreg #(.SHIFT(1),.DATA(1)) sre00(clk,reset,b_ct   ,ctd0);
// shiftreg #(.SHIFT(1),.DATA(1)) sre01(clk,reset,b_pwm  ,pwmd0);
// shiftreg #(.SHIFT(5),.DATA(8)) sre02(clk,reset,waddre ,waddrd0);
// shiftreg #(.SHIFT(6),.DATA(8)) sre03(clk,reset,waddro ,waddrd1);
// shiftreg #(.SHIFT(5),.DATA(1)) sre04(clk,reset,wen    ,wend0);
// shiftreg #(.SHIFT(6),.DATA(1)) sre05(clk,reset,wen    ,wend1);
// shiftreg #(.SHIFT(5),.DATA(1)) sre06(clk,reset,brsel  ,brseld0);
// shiftreg #(.SHIFT(6),.DATA(1)) sre07(clk,reset,brsel  ,brseld1);
// shiftreg #(.SHIFT(5),.DATA(1)) sre08(clk,reset,brselen,brselend0);
// shiftreg #(.SHIFT(6),.DATA(1)) sre09(clk,reset,brselen,brselend1);
// shiftreg #(.SHIFT(6),.DATA(3)) sre10(clk,reset,c_stage,stage_countd0);
// shiftreg #(.SHIFT(2),.DATA(3)) sre11(clk,reset,c_pwm,  stage_count_pwmd0);
// shiftreg #(.SHIFT(2),.DATA(7)) sre12(clk,reset,c_loop ,c_loop_pwmd0);
// shiftreg #(.SHIFT(1),.DATA(7)) sre13(clk,reset,raddr_b_w,raddr_b_wd0);
// shiftreg #(.SHIFT(1),.DATA(9)) sre14(clk,reset,c_tw   ,raddr_twd0);

// k-red    加两个寄存器 bertels  Ni 6 cycles (OLD - without CT_reg optimization)
shiftreg #(.SHIFT(1),.DATA(1)) sre00(clk,reset,b_ct   ,ctd0);   
shiftreg #(.SHIFT(1),.DATA(1)) sre01(clk,reset,b_pwm  ,pwmd0);
shiftreg #(.SHIFT(7),.DATA(8)) sre02(clk,reset,waddre ,waddrd0); 
shiftreg #(.SHIFT(8),.DATA(8)) sre03(clk,reset,waddro ,waddrd1); 
shiftreg #(.SHIFT(7),.DATA(1)) sre04(clk,reset,wen    ,wend0); 
shiftreg #(.SHIFT(8),.DATA(1)) sre05(clk,reset,wen    ,wend1); 
shiftreg #(.SHIFT(7),.DATA(1)) sre06(clk,reset,brsel  ,brseld0); 
shiftreg #(.SHIFT(8),.DATA(1)) sre07(clk,reset,brsel  ,brseld1); 
shiftreg #(.SHIFT(7),.DATA(1)) sre08(clk,reset,brselen,brselend0); 
shiftreg #(.SHIFT(8),.DATA(1)) sre09(clk,reset,brselen,brselend1); 
shiftreg #(.SHIFT(8),.DATA(3)) sre10(clk,reset,c_stage,stage_countd0); 
shiftreg #(.SHIFT(2),.DATA(3)) sre11(clk,reset,c_pwm,  stage_count_pwmd0);
shiftreg #(.SHIFT(2),.DATA(7)) sre12(clk,reset,c_loop ,c_loop_pwmd0);
shiftreg #(.SHIFT(1),.DATA(7)) sre13(clk,reset,raddr_b_w,raddr_b_wd0); 
shiftreg #(.SHIFT(1),.DATA(9)) sre14(clk,reset,c_tw   ,raddr_twd0); 

// k-red with CT_reg optimization (+1 cycle): CT butterfly 7 cycles, GS butterfly 8 cycles
//  shiftreg #(.SHIFT(1),.DATA(1)) sre00(clk,reset,b_ct   ,ctd0);   
//  shiftreg #(.SHIFT(1),.DATA(1)) sre01(clk,reset,b_pwm  ,pwmd0);
//  shiftreg #(.SHIFT(8),.DATA(8)) sre02(clk,reset,waddre ,waddrd0);  // [修改] 7→8, E路径写地址
//  shiftreg #(.SHIFT(9),.DATA(8)) sre03(clk,reset,waddro ,waddrd1);  // [修改] 8→9, O路径写地址
//  shiftreg #(.SHIFT(8),.DATA(1)) sre04(clk,reset,wen    ,wend0);    // [修改] 7→8, 写使能0
//  shiftreg #(.SHIFT(9),.DATA(1)) sre05(clk,reset,wen    ,wend1);    // [修改] 8→9, 写使能1
//  shiftreg #(.SHIFT(8),.DATA(1)) sre06(clk,reset,brsel  ,brseld0);  // [修改] 7→8, BRAM选择0
//  shiftreg #(.SHIFT(9),.DATA(1)) sre07(clk,reset,brsel  ,brseld1);  // [修改] 8→9, BRAM选择1
//  shiftreg #(.SHIFT(8),.DATA(1)) sre08(clk,reset,brselen,brselend0);// [修改] 7→8, BRAM选择使能0
//  shiftreg #(.SHIFT(9),.DATA(1)) sre09(clk,reset,brselen,brselend1);// [修改] 8→9, BRAM选择使能1
//  shiftreg #(.SHIFT(9),.DATA(3)) sre10(clk,reset,c_stage,stage_countd0); // [修改] 8→9, 级数计数
//  shiftreg #(.SHIFT(2),.DATA(3)) sre11(clk,reset,c_pwm,  stage_count_pwmd0);
//  shiftreg #(.SHIFT(2),.DATA(7)) sre12(clk,reset,c_loop ,c_loop_pwmd0);
//  shiftreg #(.SHIFT(1),.DATA(7)) sre13(clk,reset,raddr_b_w,raddr_b_wd0); 
//  shiftreg #(.SHIFT(1),.DATA(9)) sre14(clk,reset,c_tw   ,raddr_twd0);

// 加 3 reg
// shiftreg #(.SHIFT(1),.DATA(1)) sre00(clk,reset,b_ct   ,ctd0);   // 不要改
// shiftreg #(.SHIFT(1),.DATA(1)) sre01(clk,reset,b_pwm  ,pwmd0);
// shiftreg #(.SHIFT(8),.DATA(8)) sre02(clk,reset,waddre ,waddrd0); // 不动
// shiftreg #(.SHIFT(9),.DATA(8)) sre03(clk,reset,waddro ,waddrd1); // 不动
// shiftreg #(.SHIFT(8),.DATA(1)) sre04(clk,reset,wen    ,wend0); // 不动
// shiftreg #(.SHIFT(9),.DATA(1)) sre05(clk,reset,wen    ,wend1); // 不动
// shiftreg #(.SHIFT(8),.DATA(1)) sre06(clk,reset,brsel  ,brseld0); // 不动
// shiftreg #(.SHIFT(9),.DATA(1)) sre07(clk,reset,brsel  ,brseld1); // 不动
// shiftreg #(.SHIFT(8),.DATA(1)) sre08(clk,reset,brselen,brselend0); // 不动
// shiftreg #(.SHIFT(9),.DATA(1)) sre09(clk,reset,brselen,brselend1); // 不动
// shiftreg #(.SHIFT(9),.DATA(3)) sre10(clk,reset,c_stage,stage_countd0); // 不动
// shiftreg #(.SHIFT(2),.DATA(3)) sre11(clk,reset,c_pwm,  stage_count_pwmd0);
// shiftreg #(.SHIFT(2),.DATA(7)) sre12(clk,reset,c_loop ,c_loop_pwmd0);
// shiftreg #(.SHIFT(1),.DATA(7)) sre13(clk,reset,raddr_b_w,raddr_b_wd0); // 不动
// shiftreg #(.SHIFT(1),.DATA(9)) sre14(clk,reset,c_tw   ,raddr_twd0); // 不动

// xing    barret 加四个寄存器
//shiftreg #(.SHIFT(1),.DATA(1)) sre00(clk,reset,b_ct   ,ctd0);   // 不要改
//shiftreg #(.SHIFT(1),.DATA(1)) sre01(clk,reset,b_pwm  ,pwmd0);
//shiftreg #(.SHIFT(9),.DATA(8)) sre02(clk,reset,waddre ,waddrd0); // 不动
//shiftreg #(.SHIFT(10),.DATA(8)) sre03(clk,reset,waddro ,waddrd1); // 不动
//shiftreg #(.SHIFT(9),.DATA(1)) sre04(clk,reset,wen    ,wend0); // 不动
//shiftreg #(.SHIFT(10),.DATA(1)) sre05(clk,reset,wen    ,wend1); // 不动
//shiftreg #(.SHIFT(5),.DATA(1)) sre06(clk,reset,brsel  ,brseld0); // 不动
//shiftreg #(.SHIFT(6),.DATA(1)) sre07(clk,reset,brsel  ,brseld1); // 不动
//shiftreg #(.SHIFT(5),.DATA(1)) sre08(clk,reset,brselen,brselend0); // 不动
//shiftreg #(.SHIFT(6),.DATA(1)) sre09(clk,reset,brselen,brselend1); // 不动
//shiftreg #(.SHIFT(10),.DATA(3)) sre10(clk,reset,c_stage,stage_countd0); // 不动
//shiftreg #(.SHIFT(2),.DATA(3)) sre11(clk,reset,c_pwm,  stage_count_pwmd0);
//shiftreg #(.SHIFT(2),.DATA(7)) sre12(clk,reset,c_loop ,c_loop_pwmd0);
//shiftreg #(.SHIFT(1),.DATA(7)) sre13(clk,reset,raddr_b_w,raddr_b_wd0); // 不动
//shiftreg #(.SHIFT(1),.DATA(9)) sre14(clk,reset,c_tw   ,raddr_twd0); // 不动

// --------------------------------------------------------------------------- outputs
// raddr (tw)
always @(posedge clk or posedge reset) begin
    if(reset) begin
        ct              <= 0;
        pwm             <= 0;
        raddr0          <= 0;
        raddr1          <= 0;
        waddr0          <= 0;
        waddr1          <= 0;
        wen0            <= 0;
        wen1            <= 0;
        brsel0          <= 0;
        brsel1          <= 0;
        brselen0        <= 0;
        brselen1        <= 0;
        stage_count     <= 0;
        stage_count_pwm <= 0;
        c_loop_pwm      <= 0;
    end
    else begin
        ct              <= ctd0;
        pwm             <= pwmd0;
        raddr0          <= raddr;
        raddr1          <= raddr;
        waddr0          <= waddrd0;
        waddr1          <= waddrd1;
        wen0            <= wend0;
        wen1            <= wend1;
        brsel0          <= brseld0;
        brsel1          <= brseld1;
        brselen0        <= brselend0;
        brselen1        <= brselend1;
        stage_count     <= stage_countd0;
        stage_count_pwm <= stage_count_pwmd0;
        c_loop_pwm      <= c_loop_pwmd0;
    end
end

always @(*) begin
    raddr_b  = raddr_b_wd0;
    raddr_tw = raddr_twd0;
end

endmodule