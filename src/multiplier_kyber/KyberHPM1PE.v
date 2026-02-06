
/*
-- I/O Ports
* load_a_f   : HIGH for 1 cc, then 1st polynomial is loaded for FNTT operation
* load_a_i   : HIGH for 1 cc, then 1st polynomial is loaded for INTT operation
* load_b_f   : HIGH for 1 cc, then 2nd polynomial is loaded for FNTT operation
* load_b_i   : HIGH for 1 cc, then 2nd polynomial is loaded for INTT operation
* read_a     : HIGH for 1 cc, then read 1st polynomial (A)
* read_b     : HIGH for 1 cc, then read 2nd polynomial (B)
* start_ab   : HIGH for operation on 1st polynomial, LOW for operation on 2nd polynomial (with one of other start signals below)
* start_fntt : HIGH for 1 cc, then FNTT operation starts
* start_pwm2 : HIGH for 1 cc, then Coeff-wise Mult. operation starts
* start_intt : HIGH for 1 cc, then INTT operation starts
* din        : Input coefficients
* dout       : Output coefficients
* done       : HIGH for 1 cc, after operation is finished. Then, resulting coefficients are read
*/

module KyberHPM1PE #(parameter PE_NUMBER=1,
                               FNTT_CC=10'd908, // [修改] 908→915, CT_reg adds 1 cycle per stage (+7 cycles total)
                               PWM2_CC=10'd649,
//                               PWM2_CC=10'd521,
                               INTT_CC=10'd908, // [修改] 908→915, CT_reg adds 1 cycle per stage (+7 cycles total)
                               POS_CC=10'd256)
                  (input                         clk,reset,
                   input                         load_a_f,load_a_i,
                   input                         load_b_f,load_b_i,
                   input                         read_a,read_b,
                   input                         start_ab,
                   input                         start_pos,
                   input                         start_fntt,start_pwm2,start_intt,
                   input      [12*PE_NUMBER-1:0] din,
                   output reg [12*PE_NUMBER-1:0] dout, 
                   output reg                    done
               );
// ---------------------------------------------------------------- connections

// parameters & control
/*
We have 8 states:
-- 0 : OP_IDLE        --> Idle state, waiting for input
-- 1 : OP_LOAD_DATA   --> loading input polynomial A or B for (ntt or intt)
-- 2 : OP_FNTT        --> performing FNTT operation
-- 3 : OP_PWM2        --> performing PWM2 operation
-- 4 : OP_INTT        --> performing INTT operation
-- 5 : OP_PRE_SUM        --> no-operation-defined (can be added later) pre-sum (a0 + a1)
-- 6 : OP_NULL        --> no-operation-defined (can be added later)
-- 7 : OP_READ_DATA   --> reading out output polynomial
*/

parameter OP_IDLE        = 3'd0;
parameter OP_LOAD_DATA   = 3'd1;
parameter OP_FNTT        = 3'd2;
parameter OP_PWM2        = 3'd3;
parameter OP_INTT        = 3'd4;
parameter OP_POS         = 3'd5; // pre-sum (a0 + a1)
parameter OP_NULL2       = 3'd6; // no-operation-defined
parameter OP_READ_DATA   = 3'd7;

reg [2:0]  curr_state,next_state;

reg [7:0]  di_cntr;  // counter for OP_LOAD_DATA/B state
reg [8:0]  do_cntr;  // counter for OP_READ_DATA/B state
reg [9:0]  op_cntr;  // counter for FNTT,INTT,PWM2, PRE_SUM operations

reg        op_out_a; // where is output for A?
reg        op_out_b; // where is output for B?

reg        load_type;// 0 for FNTT, 1 for INTT

reg        load_ab;  // 0 for A, 1 for B
reg        read_ab;  // 0 for A, 1 for B
reg        exec_ab;  // 0 for A, 1 for B

// bram signals for input polynomial
// 第1个多项式
reg [11:0] di0 [2*PE_NUMBER-1:0]; //蝴蝶操作输出，输入进BRAM
wire[11:0] do0 [2*PE_NUMBER-1:0]; //蝴蝶操作输入，从BRAM输出
reg [7:0]  dw0 [2*PE_NUMBER-1:0]; //写入BRAM的地址
reg [7:0]  dr0 [2*PE_NUMBER-1:0]; //从BRAM读出的地址
reg        de0 [2*PE_NUMBER-1:0]; //使能

//第2个多项式
reg [11:0] di1 [2*PE_NUMBER-1:0];
wire[11:0] do1 [2*PE_NUMBER-1:0];
reg [7:0]  dw1 [2*PE_NUMBER-1:0];
reg [7:0]  dr1 [2*PE_NUMBER-1:0];
reg        de1 [2*PE_NUMBER-1:0];

// signals before going to brams
reg [11:0] di2 [2*PE_NUMBER-1:0];
reg [7:0]  dw2 [2*PE_NUMBER-1:0];
reg [7:0]  dr2 [2*PE_NUMBER-1:0];
reg        de2 [2*PE_NUMBER-1:0];

//// 点乘时存系数对A的和
//reg [11:0] di3 [2*PE_NUMBER-1:0];
//wire[11:0] do3 [2*PE_NUMBER-1:0];
//reg [7:0]  dw3 [2*PE_NUMBER-1:0];
//reg [7:0]  dr3 [2*PE_NUMBER-1:0];
//reg        de3 [2*PE_NUMBER-1:0];

//// 点乘时存系数对B的和
//reg [11:0] di4 [2*PE_NUMBER-1:0];
//wire[11:0] do4 [2*PE_NUMBER-1:0];
//reg [7:0]  dw4 [2*PE_NUMBER-1:0];
//reg [7:0]  dr4 [2*PE_NUMBER-1:0];
//reg        de4 [2*PE_NUMBER-1:0];

// bram signals for twiddle factors
wire[12*PE_NUMBER-1:0] to;
reg [8:0]              tr;

// control unit signals (from control unit to top module)
wire       c_ct;
wire       c_pwm;
wire [7:0] raddr0,raddr1;
wire [7:0] waddr0,waddr1;
wire       wen0  ,wen1  ;
wire       brsel0,brsel1;
wire       brselen0,brselen1;
wire [2:0] stage_count;
wire [2:0] stage_count_pwm;
wire [6:0] c_loop_pwm;
wire [7:0] c_loop_pos;
wire [6:0] raddr_b;
wire [8:0] raddr_tw;

// signals for BFU blocks
reg        CT;
reg        PWM;
reg [11:0] A;
reg [11:0] B;
reg [11:0] W;
wire[11:0] E;
wire[11:0] O;
wire[11:0] MUL;
wire[11:0] ADD;
wire[11:0] SUB;

// ---------------------------------------------------------------- load_type & op_out/load/read/exec

always @(posedge clk or posedge reset) begin
    if(reset)
        load_type <= 0;
    else begin
        if(load_a_i || load_b_i)
            load_type <= 1;
        else if(curr_state == OP_LOAD_DATA)
            load_type <= load_type;
        else
            load_type <= 0;
    end
end

always @(posedge clk or posedge reset) begin
    if(reset)
        op_out_a <= 0;
    else begin
        if(start_fntt && ~start_ab)
            op_out_a <= 1; // Doing FNTT (output will be at address 1)
        else if(start_pwm2 && ~start_ab)
            op_out_a <= 1; // Doing PWM2 (output will be at address 1)
        // else if(start_pos && ~start_ab)
        //     op_out_a <= 1; // Doing POS (output will be at address 1)    
        else if(start_intt && ~start_ab)
            op_out_a <= 0; // Doing INTT (output will be at address 0)
        else
            op_out_a <= op_out_a;
    end
end

always @(posedge clk or posedge reset) begin
    if(reset)
        op_out_b <= 0;
    else begin
        if(start_fntt && start_ab)
            op_out_b <= 1; // Doing FNTT (output will be at address 1)
        else if(start_pwm2 && start_ab)
            op_out_b <= 1; // Doing PWM2 (output will be at address 1)
        // else if(start_pos && start_ab)
        //     op_out_b <= 1; // Doing POS (output will be at address 1)
        else if(start_intt && start_ab)
            op_out_b <= 0; // Doing INTT (output will be at address 0)
        else
            op_out_b <= op_out_b;
    end
end

always @(posedge clk or posedge reset) begin
    if(reset) begin
        load_ab <= 0;
        read_ab <= 0;
        exec_ab <= 0;
    end
    else begin
        // load
        if(load_a_f || load_a_i)
            load_ab <= 0;
        else if(load_b_f || load_b_i)
            load_ab <= 1;
        else if(curr_state == OP_IDLE)
            load_ab <= 0;
        else
            load_ab <= load_ab;
        // read
        if(read_a)
            read_ab <= 0;
        else if(read_b)
            read_ab <= 1;
        else if(curr_state == OP_IDLE)
            read_ab <= 0;
        else
            read_ab <= read_ab;
        // exec
        if(start_fntt || start_pwm2 || start_intt)
            exec_ab <= start_ab;
        else if(start_pos)
            exec_ab <= start_ab;
        else if(curr_state == OP_IDLE)
            exec_ab <= 0;
        else
            exec_ab <= exec_ab;
    end
end

// ---------------------------------------------------------------- FSM

/*
-- 0 : OP_IDLE        --> Idle state, waiting for input
-- 1 : OP_LOAD_DATA   --> loading input polynomial A or B for (ntt or intt)
-- 2 : OP_FNTT        --> performing FNTT operation
-- 3 : OP_PWM2        --> performing PWM2 operation
-- 4 : OP_INTT        --> performing INTT operation
-- 5 : OP_NULL        --> no-operation-defined (can be added later)
-- 6 : OP_NULL        --> no-operation-defined (can be added later)
-- 7 : OP_READ_DATA   --> reading out output polynomial
*/

always @(posedge clk or posedge reset) begin
    if(reset)
        curr_state <= 0;
    else
        curr_state <= next_state;
end

always @(*) begin
    case(curr_state)
    OP_IDLE: begin
        if(load_a_f || load_a_i || load_b_f || load_b_i)
            next_state = OP_LOAD_DATA;
        else if(start_fntt)
            next_state = OP_FNTT;
        else if(start_pwm2)
            next_state = OP_PWM2;
        else if(start_intt)
            next_state = OP_INTT;
        else if(start_pos)
            next_state = OP_POS;
        else if(read_a || read_b)
            next_state = OP_READ_DATA;
        else
            next_state = OP_IDLE;
    end
    OP_LOAD_DATA: begin
        next_state = (di_cntr == 8'd255) ? OP_IDLE : OP_LOAD_DATA;
    end
    OP_FNTT: begin
        next_state = (op_cntr == (FNTT_CC-10'd1)) ? OP_IDLE : OP_FNTT;
    end
    OP_POS: begin
        next_state = (op_cntr == (POS_CC-10'd1)) ? OP_IDLE : OP_POS;
    end
    OP_PWM2: begin
        next_state = (op_cntr == (PWM2_CC-10'd1)) ? OP_IDLE : OP_PWM2;
    end
    OP_INTT: begin
        next_state = (op_cntr == (INTT_CC-10'd1)) ? OP_IDLE : OP_INTT;
    end
    OP_READ_DATA: begin
        next_state = (do_cntr == 9'd257) ? OP_IDLE : OP_READ_DATA;
    end
    default: next_state = OP_IDLE;
    endcase
end

// ---------------------------------------------------------------- di_cntr,do_cntr（为什么258）,op_cntr

always @(posedge clk or posedge reset) begin
    if(reset) begin
        di_cntr <= 0;
        do_cntr <= 0;
        op_cntr <= 0;
    end
    else begin
        if (curr_state == OP_LOAD_DATA)
            di_cntr <= (di_cntr == 8'd255) ? 0 : (di_cntr + 8'd1);

        if (curr_state == OP_READ_DATA)
            do_cntr <= (do_cntr == 9'd257) ? 0 : (do_cntr + 8'd1);

        case(curr_state)
        OP_FNTT: op_cntr <= (op_cntr == (FNTT_CC-10'd1)) ? 0 : (op_cntr+10'd1);
        OP_POS: op_cntr <= (op_cntr == (POS_CC-10'd1)) ? 0 : (op_cntr+10'd1);
        OP_PWM2: op_cntr <= (op_cntr == (PWM2_CC-10'd1)) ? 0 : (op_cntr+10'd1);
        OP_INTT: op_cntr <= (op_cntr == (INTT_CC-10'd1)) ? 0 : (op_cntr+10'd1);
        default: op_cntr <= op_cntr;
        endcase
    end
end

// ---------------------------------------------------------------- BRAM signals
// ---------------------------------------------------------------- data, tw, ntt

// twiddle (read)
always @(posedge clk or posedge reset) begin
    if(reset)
        tr <= 0;
    else
        tr <= raddr_tw;
end

// data (write & read)
always @(*) begin
    case(curr_state)
    OP_LOAD_DATA: begin
        {di2[0],di2[1]} = {din,din};
        {dw2[0],dw2[1]} = (load_type == 1'd0) ? {2{1'b0,di_cntr[6:0]}} : {2{1'b1,di_cntr[7:1]}};
        {dr2[0],dr2[1]} = 0;
        {de2[0],de2[1]} = (load_type == 1'd0) ? {~di_cntr[7],di_cntr[7]} : {~di_cntr[0],di_cntr[0]};
    end
    OP_FNTT: begin
        // ------------------------------------------------------ READ
        {dr2[0],dr2[1]} = {raddr0,raddr1};
        // ------------------------------------------------------ WRITE
        case(stage_count)
        3'd0,3'd1,3'd2,3'd3,3'd4,3'd5: begin
            if(brselen0) begin
                if(brsel0 == 1'd0) begin
                    di2[0] = E;
                    dw2[0] = waddr0;
                    de2[0] = wen0;
                end
                else begin // brsel0 == 1
                    di2[0] = O;
                    dw2[0] = waddr1;
                    de2[0] = wen1;
                end
            end
            else begin
                di2[0] = 0;
                dw2[0] = 0;
                de2[0] = 0;
            end

            if(brselen1) begin
                if(brsel1 == 1'd0) begin
                    di2[1] = E;
                    dw2[1] = waddr0;
                    de2[1] = wen0;
                end
                else begin // brsel1 == 1
                    di2[1] = O;
                    dw2[1] = waddr1;
                    de2[1] = wen1;
                end
            end
            else begin
                di2[1] = 0;
                dw2[1] = 0;
                de2[1] = 0;
            end
        end
        3'd6: begin
            {di2[0],di2[1]} = {E,O};
            {dw2[0],dw2[1]} = {waddr0,waddr1};
            {de2[0],de2[1]} = {wen0,wen1};
        end
        default: begin
            {di2[0],di2[1]} = 0;
            {dw2[0],dw2[1]} = 0;
            {de2[0],de2[1]} = 0;
        end
        endcase
    end
    OP_POS: begin
        {di2[0],di2[1]} = {din,din};
        if(op_cntr[1]) begin // bram 01   (op_cntr / 2) % 2
            {dw2[0],dw2[1]} = {2{8'd128 + (op_cntr[7:1] & 7'b1111110) + op_cntr[0]}};
        end
        else begin  // bram 00
            {dw2[0],dw2[1]} = {2{8'd128 + op_cntr[7:1] + op_cntr[0]}};                       
        end
        {de2[0],de2[1]} = {~op_cntr[1],op_cntr[1]};
        {dr2[0],dr2[1]} = 0;     
    end
    OP_PWM2: begin
       if(c_loop_pwm[0] == 1'b1) begin
           // write to first BRAM
           {di2[0],di2[1]} = {E,E};
           {dw2[0],dw2[1]} = {waddr1,waddr1};
           {dr2[0],dr2[1]} = {raddr1,raddr1};
           {de2[0],de2[1]} = {wen1|wen0,1'b0};
       end
       else begin
           // write to second BRAM
           {di2[0],di2[1]} = {E,E};
           {dw2[0],dw2[1]} = {waddr1,waddr1};
           {dr2[0],dr2[1]} = {raddr1,raddr1};
           {de2[0],de2[1]} = {1'b0,wen1|wen0};
       end
   end
    OP_INTT: begin
        // ------------------------------------------------------ READ
        {dr2[0],dr2[1]} = {raddr0,raddr1};
        // ------------------------------------------------------ WRITE
        case(stage_count)
        3'd6: begin
            {di2[0],di2[1]} = {E,O};
            {dw2[0],dw2[1]} = {waddr0,waddr1};
            {de2[0],de2[1]} = {wen0,wen1};
        end
        default: begin
            if(brselen0) begin
                if(brsel0 == 1'd0) begin
                    di2[0] = E;
                    dw2[0] = waddr0;
                    de2[0] = wen0;
                end
                else begin // brsel0 == 1
                    di2[0] = O;
                    dw2[0] = waddr1;
                    de2[0] = wen1;
                end
            end
            else begin
                di2[0] = 0;
                dw2[0] = 0;
                de2[0] = 0;
            end

            if(brselen1) begin
                if(brsel1 == 1'd0) begin
                    di2[1] = E;
                    dw2[1] = waddr0;
                    de2[1] = wen0;
                end
                else begin // brsel1 == 1
                    di2[1] = O;
                    dw2[1] = waddr1;
                    de2[1] = wen1;
                end
            end
            else begin
                di2[1] = 0;
                dw2[1] = 0;
                de2[1] = 0;
            end
        end
        endcase
    end
    OP_READ_DATA: begin
        {di2[0],di2[1]} = 0;
        {dw2[0],dw2[1]} = 0;
        {dr2[0],dr2[1]} = (read_ab == 1'b0) ? {2{op_out_a,do_cntr[7:1]}} : {2{op_out_b,do_cntr[7:1]}};
        {de2[0],de2[1]} = 0;
    end
    default: begin
        {di2[0],di2[1]} = 0;
        {dw2[0],dw2[1]} = 0;
        {dr2[0],dr2[1]} = 0;
        {de2[0],de2[1]} = 0;
    end
    endcase
end

// brams
always @(*) begin
    // read
    {dr0[0],dr0[1]} = {dr2[0],dr2[1]};
    {dr1[0],dr1[1]} = (curr_state == OP_PWM2) ? {2{1'b1,raddr_b}} : {dr2[0],dr2[1]};
    // write
    {dw0[0],dw0[1]} = {dw2[0],dw2[1]};
    {dw1[0],dw1[1]} = {dw2[0],dw2[1]};
    // input
    {di0[0],di0[1]} = {di2[0],di2[1]};
    {di1[0],di1[1]} = {di2[0],di2[1]};
    // enable
    {de0[0],de0[1]} = (load_ab || read_ab || exec_ab) ? 0 : {de2[0],de2[1]};
    {de1[0],de1[1]} = (load_ab || read_ab || exec_ab) ? {de2[0],de2[1]}: 0;
end

// ---------------------------------------------------------------- DONE, DOUT

// ntt unit
always @(posedge clk or posedge reset) begin
    if(reset) begin
        A   <= 0;
        B   <= 0;
        W   <= 0;
        CT  <= 0;
        PWM <= 0;
    end
    else begin
        case(curr_state)
        OP_FNTT,OP_INTT: begin
            A   <= (exec_ab == 1'b0) ? do0[0] : do1[0];
            B   <= (exec_ab == 1'b0) ? do0[1] : do1[1];
            W   <= to;
            CT  <= c_ct;
            PWM <= c_pwm;
        end
        OP_PWM2: begin // ？stage_count_pwm什么意思
            case(stage_count_pwm)
            3'd0: begin
                A <= 0;
                B <= (c_loop_pwm[0]==1'b0) ? do0[0] : do0[1];
                W <= (c_loop_pwm[0]==1'b0) ? do1[0] : do1[1];
            end
            3'd1: begin
                A <= 0;
                B <= (c_loop_pwm[0]==1'b0) ? do0[0] : do0[1];
                W <= (c_loop_pwm[0]==1'b0) ? do1[0] : do1[1];
            end
            3'd2: begin
                A <= 0;
                B <= (c_loop_pwm[0]==1'b0) ? do0[0] : do0[1];
                W <= (c_loop_pwm[0]==1'b0) ? do1[0] : do1[1];
            end
            3'd3: begin
                A <= MUL;
                B <= (c_loop_pwm[0]==1'b0) ? do0[0] : do0[1];
                W <= (c_loop_pwm[0]==1'b0) ? do1[0] : do1[1];
            end
            3'd4: begin
                A <= 0;
                B <= MUL;
                W <= to;
            end
            default: begin
                A <= 0;
                B <= 0;
                W <= 0;
            end
            endcase
            CT  <= c_ct;
            PWM <= c_pwm;
        end
        default: begin
            A   <= A;
            B   <= B;
            W   <= W;
            CT  <= CT;
            PWM <= PWM;
        end
        endcase
    end
end

// ---------------------------------------------------------------- DONE, DOUT

// done
always @(posedge clk or posedge reset) begin
    if(reset)
        done <= 0;
    else begin
        case(curr_state)
        OP_FNTT: done <= (op_cntr == (FNTT_CC-10'd1)) ? 1'b1 : 1'b0;
        OP_INTT: done <= (op_cntr == (INTT_CC-10'd1)) ? 1'b1 : 1'b0;
        OP_PWM2: done <= (op_cntr == (PWM2_CC-10'd1)) ? 1'b1 : 1'b0;
        OP_POS: done <= (op_cntr == (POS_CC-10'd1)) ? 1'b1 : 1'b0;
        default: done <= 1'b0;
        endcase
    end
end

// dout
always @(posedge clk or posedge reset) begin
    if(reset) begin
        dout <= 0;
    end
    else begin
        if(curr_state == OP_READ_DATA) begin
            if(do_cntr > 9'd0)
                dout <= (do_cntr[0] == 1'd1) ? ((read_ab == 1'd0) ? do0[0] : do1[0]) : ((read_ab == 0) ? do0[1] : do1[1]);
                // do_cntr[0]区分一次蝴蝶操作输出上下，交替读取  read_ab区分第1 2个多项式
        end
        else begin
            dout <= 0;
        end
    end
end

// ---------------------------------------------------------------- CONTROL UNIT

addressgenerator ag(clk,reset,
                    start_fntt,start_pwm2,start_intt,
                    c_ct,
                    c_pwm,
                    raddr0,raddr1,
                    waddr0,waddr1,
                    wen0  ,wen1  ,
                    brsel0,brsel1,
                    brselen0,brselen1,
                    stage_count,
                    stage_count_pwm,
                    c_loop_pwm,
                    raddr_b,
                    raddr_tw
                    );

// ---------------------------------------------------------------- BRAMs

BRAM bd00(clk,de0[0],dw0[0],di0[0],dr0[0],do0[0]);
BRAM bd01(clk,de0[1],dw0[1],di0[1],dr0[1],do0[1]);

BRAM bd10(clk,de1[0],dw1[0],di1[0],dr1[0],do1[0]);
BRAM bd11(clk,de1[1],dw1[1],di1[1],dr1[1],do1[1]);

//BRAM #(.LENBR(127)) bd3 (clk,de3[0],dw3[0],di3[0],dr3[0],do3[0]);
// ---------------------------------------------------------------- BROMs

BROM_PRE bt00(clk,tr,to);
//BROM bt00(clk,tr,to);

// ---------------------------------------------------------------- BUTTERFLY UNIT

//butterfly btfu(clk,reset,
//               CT,
//               PWM,
//	           A,B,W,
//		       E,O,
//		       MUL,
//		       ADD,SUB);

//butterfly_Best_merge btfu(clk,reset,
//               CT,
//               PWM,
//	           A,B,W,
//		       E,O,
//		       MUL,
//		       ADD,SUB);

butterfly_Best btfu(clk,reset,
               CT,
               PWM,
	           A,B,W,
		       E,O,
		       MUL,
		       ADD,SUB);

//butterfly_lut_k_reg btfu(clk,reset,
//               CT,
//               PWM,
//	           A,B,W,
//		       E,O,
//		       MUL,
//		       ADD,SUB);

//butterfly_xing btfu(clk,reset,
//               CT,
//               PWM,
//	           A,B,W,
//		       E,O,
//		       MUL,
//		       ADD,SUB);

//butterfly_Ni btfu(clk,reset,
//               CT,
//               PWM,
//	           A,B,W,
//		       E,O,
//		       MUL,
//		       ADD,SUB);

// ----------------------------------------------------------------

endmodule
