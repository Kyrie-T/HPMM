
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

/*
[0]     [1]     [2]     [0]
[47:36] [35:24] [23:12] [11:0]
*/

module KyberHPM4PE #(parameter PE_NUMBER=4,
                               FNTT_CC=8'd234,
                               PWM2_CC=8'd169,
                               INTT_CC=8'd235,
                               POS_CC=10'd64
                            //    FNTT_CC=8'd232,
                            //    PWM2_CC=8'd167,
                            //    INTT_CC=8'd233
                            )
                  (input                         clk,reset,
                   input                         load_a_f,load_a_i,
                   input                         load_b_f,load_b_i,
                   input                         read_a,read_b,
                   input                         start_ab,
                   input                         start_pos,
                   input                         start_fntt,start_pwm2,start_intt,
                   input      [12*PE_NUMBER-1:0] din,  // 0,1,2,3
                   output reg [12*PE_NUMBER-1:0] dout, // 0,1,2,3
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
parameter OP_POS         = 3'd5; // no-operation-defined
parameter OP_NULL2       = 3'd6; // no-operation-defined
parameter OP_READ_DATA   = 3'd7;

reg [2:0]  curr_state,next_state;

reg [5:0]  di_cntr;  // counter for OP_LOAD_DATA/B state
reg [6:0]  do_cntr;  // counter for OP_READ_DATA/B state
reg [7:0]  op_cntr;  // counter for FNTT,INTT,PWM2 operations

reg        op_out_a; // where is output for A?
reg        op_out_b; // where is output for B?

reg        load_type; // 0 for FNTT, 1 for INTT

reg        load_ab; // 0 for A, 1 for B
reg        read_ab; // 0 for A, 1 for B
reg        exec_ab; // 0 for A, 1 for B

// bram signals for input polynomial
reg [11:0] di0 [2*PE_NUMBER-1:0];
wire[11:0] do0 [2*PE_NUMBER-1:0];
reg [5:0]  dw0 [2*PE_NUMBER-1:0];
reg [5:0]  dr0 [2*PE_NUMBER-1:0];
reg             de0 [2*PE_NUMBER-1:0];

reg [11:0] di1 [2*PE_NUMBER-1:0];
wire[11:0] do1 [2*PE_NUMBER-1:0];
reg [5:0]  dw1 [2*PE_NUMBER-1:0];
reg [5:0]  dr1 [2*PE_NUMBER-1:0];
reg             de1 [2*PE_NUMBER-1:0];

// signals before going to brams
reg [11:0] di2 [2*PE_NUMBER-1:0];
reg [5:0]  dw2 [2*PE_NUMBER-1:0];
reg [5:0]  dr2 [2*PE_NUMBER-1:0];
reg        de2 [2*PE_NUMBER-1:0];

// bram signals for twiddle factors
wire[12*PE_NUMBER-1:0] to;
reg [7:0]              tr;

// control unit signals (from control unit to top module)
wire       c_ct;
wire       c_pwm;
wire [5:0] raddr0,raddr1;
wire [5:0] waddr0,waddr1;
wire       wen0  ,wen1  ;
wire       brsel0,brsel1;
wire       brselen0,brselen1;
wire [2:0] stage_count;
wire [2:0] stage_count_pwm;
wire [7:0] raddr_tw;

// signals for PU blocks
reg        CT  [PE_NUMBER-1:0];
reg        PWM [PE_NUMBER-1:0];
reg [11:0] A   [PE_NUMBER-1:0];
reg [11:0] B   [PE_NUMBER-1:0];
reg [11:0] W   [PE_NUMBER-1:0];
wire[11:0] E   [PE_NUMBER-1:0];
wire[11:0] O   [PE_NUMBER-1:0];
wire[11:0] MUL [PE_NUMBER-1:0];
wire[11:0] ADD [PE_NUMBER-1:0];
wire[11:0] SUB [PE_NUMBER-1:0];

// ---------------------------------------------------------------- defines
// -- Data
`define dic_0 {di2[0],di2[2],di2[4],di2[6]}
`define dwc_0 {dw2[0],dw2[2],dw2[4],dw2[6]}
`define drc_0 {dr2[0],dr2[2],dr2[4],dr2[6]}
`define dec_0 {de2[0],de2[2],de2[4],de2[6]}

`define dic_1 {di2[1],di2[3],di2[5],di2[7]}
`define dwc_1 {dw2[1],dw2[3],dw2[5],dw2[7]}
`define drc_1 {dr2[1],dr2[3],dr2[5],dr2[7]}
`define dec_1 {de2[1],de2[3],de2[5],de2[7]}

`define dic_2 {di2[0],di2[1],di2[2],di2[3],di2[4],di2[5],di2[6],di2[7]}
`define dwc_2 {dw2[0],dw2[1],dw2[2],dw2[3],dw2[4],dw2[5],dw2[6],dw2[7]}
`define drc_2 {dr2[0],dr2[1],dr2[2],dr2[3],dr2[4],dr2[5],dr2[6],dr2[7]}
`define dec_2 {de2[0],de2[1],de2[2],de2[3],de2[4],de2[5],de2[6],de2[7]}

// -- Data A
`define dia_2 {di0[0],di0[1],di0[2],di0[3],di0[4],di0[5],di0[6],di0[7]}
`define doa_2 {do0[0],do0[1],do0[2],do0[3],do0[4],do0[5],do0[6],do0[7]}
`define dwa_2 {dw0[0],dw0[1],dw0[2],dw0[3],dw0[4],dw0[5],dw0[6],dw0[7]}
`define dra_2 {dr0[0],dr0[1],dr0[2],dr0[3],dr0[4],dr0[5],dr0[6],dr0[7]}
`define dea_2 {de0[0],de0[1],de0[2],de0[3],de0[4],de0[5],de0[6],de0[7]}

// -- Data B
`define dib_2 {di1[0],di1[1],di1[2],di1[3],di1[4],di1[5],di1[6],di1[7]}
`define dob_2 {do1[0],do1[1],do1[2],do1[3],do1[4],do1[5],do1[6],do1[7]}
`define dwb_2 {dw1[0],dw1[1],dw1[2],dw1[3],dw1[4],dw1[5],dw1[6],dw1[7]}
`define drb_2 {dr1[0],dr1[1],dr1[2],dr1[3],dr1[4],dr1[5],dr1[6],dr1[7]}
`define deb_2 {de1[0],de1[1],de1[2],de1[3],de1[4],de1[5],de1[6],de1[7]}

// ---------------------------------------------------------------- op_type & load_type & op_out

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
        else if(start_pos && ~start_ab)
            op_out_a <= 1; // Doing POS (output will be at address 1)
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
        else if(start_pos && start_ab)
            op_out_b <= 1; // Doing POS (output will be at address 1)
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
        else if(read_a)
            next_state = OP_READ_DATA;
        else
            next_state = OP_IDLE;
    end
    OP_LOAD_DATA: begin
        next_state = (di_cntr == 6'd63) ? OP_IDLE : OP_LOAD_DATA;
    end
    OP_FNTT: begin
        next_state = (op_cntr == (FNTT_CC-8'd1)) ? OP_IDLE : OP_FNTT;
    end
    OP_POS: begin
        next_state = (op_cntr == (POS_CC-10'd1)) ? OP_IDLE : OP_POS;
    end
    OP_PWM2: begin
        next_state = (op_cntr == (PWM2_CC-8'd1)) ? OP_IDLE : OP_PWM2;
    end
    OP_INTT: begin
        next_state = (op_cntr == (INTT_CC-8'd1)) ? OP_IDLE : OP_INTT;
    end
    OP_READ_DATA: begin
        next_state = (do_cntr == 7'd65) ? OP_IDLE : OP_READ_DATA;
    end
    default: next_state = OP_IDLE;
    endcase
end

// ---------------------------------------------------------------- di_cntr,do_cntr,op_cntr

always @(posedge clk or posedge reset) begin
    if(reset) begin
        di_cntr <= 0;
        do_cntr <= 0;
        op_cntr <= 0;
    end
    else begin
        if (curr_state == OP_LOAD_DATA)
            di_cntr <= (di_cntr == 6'd63) ? 0 : (di_cntr + 6'd1);

        if (curr_state == OP_READ_DATA)
            do_cntr <= (do_cntr == 7'd65) ? 0 : (do_cntr + 7'd1);

        case(curr_state)
        OP_FNTT: op_cntr <= (op_cntr == (FNTT_CC-8'd1)) ? 0 : (op_cntr+8'd1);
        OP_POS: op_cntr <= (op_cntr == (POS_CC-10'd1)) ? 0 : (op_cntr+10'd1);
        OP_PWM2: op_cntr <= (op_cntr == (PWM2_CC-8'd1)) ? 0 : (op_cntr+8'd1);
        OP_INTT: op_cntr <= (op_cntr == (INTT_CC-8'd1)) ? 0 : (op_cntr+8'd1);
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
        `dic_2 = (load_type == 1'd0) ? {{2{din[47:36]}},{2{din[35:24]}},{2{din[23:12]}},{2{din[11:0]}}} : {din,din};
        `dwc_2 = (load_type == 1'd0) ? {8{1'b0,di_cntr[4:0]}} : {8{1'b1,di_cntr[5:1]}};
        `drc_2 = 0;
        `dec_2 = (load_type == 1'd0) ? {4{~di_cntr[5],di_cntr[5]}} : {{4{~di_cntr[0]}},{4{di_cntr[0]}}};
    end
    OP_FNTT: begin
        // ------------------------------------------------------ READ
        `drc_2 = {4{raddr0,raddr1}};
        // ------------------------------------------------------ WRITE
        case(stage_count)
        3'd0,3'd1,3'd2,3'd3,3'd4: begin
            if(brselen0) begin
                if(brsel0 == 1'd0) begin
                    `dic_0 = {E[0],E[1],E[2],E[3]};
                    `dwc_0 = {4{waddr0}};
                    `dec_0 = {4{wen0}};
                end
                else begin // brsel0 == 1
                    `dic_0 = {O[0],O[1],O[2],O[3]};
                    `dwc_0 = {4{waddr1}};
                    `dec_0 = {4{wen1}};
                end
            end
            else begin
                `dic_0 = 0;
                `dwc_0 = 0;
                `dec_0 = 0;
            end

            if(brselen1) begin
                if(brsel1 == 1'd0) begin
                    `dic_1 = {E[0],E[1],E[2],E[3]};
                    `dwc_1 = {4{waddr0}};
                    `dec_1 = {4{wen0}};
                end
                else begin // brsel1 == 1
                    `dic_1 = {O[0],O[1],O[2],O[3]};
                    `dwc_1 = {4{waddr1}};
                    `dec_1 = {4{wen1}};
                end
            end
            else begin
                `dic_1 = 0;
                `dwc_1 = 0;
                `dec_1 = 0;
            end
        end
        3'd5: begin
            `dic_2 = {E[0],E[2],E[1],E[3],SUB[0],SUB[2],SUB[1],SUB[3]};
            `dwc_2 = {8{waddr0}};
            `dec_2 = {8{wen0}};
        end
        default: begin // 3'd6
            `dic_2 = {E[0],E[1],SUB[0],SUB[1],E[2],E[3],SUB[2],SUB[3]};
            `dwc_2 = {8{waddr0}};
            `dec_2 = {8{wen0}};
        end
        endcase
    end
    OP_POS: begin
        `dwc_2 = {8{1'b1,op_cntr[5:1]}};
        if(op_cntr[0]) begin
            `dic_2 = {{4{12'b0}},{{din[47:36]},{din[23:12]},{din[35:24]},{din[11:0]}}};
            `dec_2 = {{4{1'b0}},{4{1'b1}}};
        end
        else begin
            `dic_2 = {{{din[47:36]},{din[23:12]},{din[35:24]},{din[11:0]}},{4{12'b0}}};
            `dec_2 = {{4{1'b1}},{4{1'b0}}};
        end
        `drc_2 = 0;
        // `dec_2 = {4{~di_cntr[5],di_cntr[5]}};
    end
    OP_PWM2: begin
        `drc_2 = {8{raddr0}};
        `dic_2 = {E[0],E[1],E[0],E[1],E[2],E[3],E[2],E[3]};
        `dwc_2 = {2{waddr1,waddr1,waddr0,waddr0}};
        `dec_2 = {2{wen1,wen1,wen0,wen0}};
    end
    OP_INTT: begin
        // ------------------------------------------------------ READ
        `drc_2 = {4{raddr0,raddr1}};
        // ------------------------------------------------------ WRITE
        case(stage_count)
        3'd0: begin
            `dic_2 = {E[0],E[2],E[1],E[3],O[0],O[2],O[1],O[3]};
            `dwc_2 = {{4{waddr0}},{4{waddr1}}};
            `dec_2 = {{4{wen0}},{4{wen1}}};
        end
        3'd6: begin
            `dic_2 = {E[0],O[0],E[1],O[1],E[2],O[2],E[3],O[3]};
            `dwc_2 = {4{waddr0,waddr1}};
            `dec_2 = {4{wen0,wen1}};
        end
        default: begin
            if(brselen0) begin
                if(brsel0 == 1'd0) begin
                    `dic_0 = {E[0],E[1],E[2],E[3]};
                    `dwc_0 = {4{waddr0}};
                    `dec_0 = {4{wen0}};
                end
                else begin // brsel0 == 1
                    `dic_0 = {O[0],O[1],O[2],O[3]};
                    `dwc_0 = {4{waddr1}};
                    `dec_0 = {4{wen1}};
                end
            end
            else begin
                `dic_0 = 0;
                `dwc_0 = 0;
                `dec_0 = 0;
            end

            if(brselen1) begin
                if(brsel1 == 1'd0) begin
                    `dic_1 = {E[0],E[1],E[2],E[3]};
                    `dwc_1 = {4{waddr0}};
                    `dec_1 = {4{wen0}};
                end
                else begin // brsel1 == 1
                    `dic_1 = {O[0],O[1],O[2],O[3]};
                    `dwc_1 = {4{waddr1}};
                    `dec_1 = {4{wen1}};
                end
            end
            else begin
                `dic_1 = 0;
                `dwc_1 = 0;
                `dec_1 = 0;
            end
        end
        endcase
    end
    OP_READ_DATA: begin
        `dic_2 = 0;
        `dwc_2 = 0;
        `drc_2 = (read_ab == 1'b0) ? {8{op_out_a,do_cntr[5:1]}} : {8{op_out_b,do_cntr[5:1]}};
        `dec_2 = 0;
    end
    default: begin
        `dic_2 = 0;
        `dwc_2 = 0;
        `drc_2 = 0;
        `dec_2 = 0;
    end
    endcase
end

// brams
always @(*) begin
    // read
    `dra_2 = `drc_2;
    `drb_2 = (curr_state == OP_PWM2) ? {8{1'b1,raddr0[4:0]}} : `drc_2;
    // write
    `dwa_2 = `dwc_2;
    `dwb_2 = `dwc_2;
    // input
    `dia_2 = `dic_2;
    `dib_2 = `dic_2;
    // enable
    `dea_2 = (load_ab || read_ab || exec_ab) ? 0 : `dec_2;
    `deb_2 = (load_ab || read_ab || exec_ab) ? `dec_2 : 0;
end

// ---------------------------------------------------------------- DONE, DOUT

// ntt unit
integer ntt_loop = 0;

always @(posedge clk or posedge reset) begin
    for(ntt_loop = 0; ntt_loop<PE_NUMBER; ntt_loop=ntt_loop+1) begin
        if(reset) begin
            A[ntt_loop]   <= 0;
            B[ntt_loop]   <= 0;
            W[ntt_loop]   <= 0;
            CT[ntt_loop]  <= 0;
            PWM[ntt_loop] <= 0;
        end
        else begin
            case(curr_state)
            OP_FNTT,OP_INTT: begin
                A[ntt_loop]   <= (exec_ab == 1'b0) ? do0[2*ntt_loop+0] : do1[2*ntt_loop+0];
                B[ntt_loop]   <= (exec_ab == 1'b0) ? do0[2*ntt_loop+1] : do1[2*ntt_loop+1];
                W[ntt_loop]   <= to[12*(3-ntt_loop)+:12];
                CT[ntt_loop]  <= c_ct;
                PWM[ntt_loop] <= c_pwm;
            end
            OP_PWM2: begin
                case(stage_count_pwm)
                3'd0: begin
                    A[ntt_loop] <= 0;
                    B[ntt_loop] <= do0[2*ntt_loop+1];
                    W[ntt_loop] <= do1[2*ntt_loop+0];
                end
                3'd1: begin
                    A[ntt_loop] <= 0;
                    B[ntt_loop] <= do0[2*ntt_loop+1];
                    W[ntt_loop] <= do1[2*ntt_loop+1];
                end
                3'd2: begin
                    A[ntt_loop] <= 0;
                    B[ntt_loop] <= do0[2*ntt_loop+0];
                    W[ntt_loop] <= do1[2*ntt_loop+0];
                end
                3'd3: begin
                    A[ntt_loop] <= MUL[ntt_loop];
                    B[ntt_loop] <= do0[2*ntt_loop+0];
                    W[ntt_loop] <= do1[2*ntt_loop+1];
                end
                3'd4: begin
                    A[ntt_loop] <= 0;
                    B[ntt_loop] <= MUL[ntt_loop];
                    W[ntt_loop] <= to[12*(3-ntt_loop)+:12];
                end
                default: begin
                    A[ntt_loop] <= 0;
                    B[ntt_loop] <= 0;
                    W[ntt_loop] <= 0;
                end
                endcase
                CT[ntt_loop]  <= c_ct;
                PWM[ntt_loop] <= c_pwm;
            end
            default: begin
                A[ntt_loop]   <= A[ntt_loop];
                B[ntt_loop]   <= B[ntt_loop];
                W[ntt_loop]   <= W[ntt_loop];
                CT[ntt_loop]  <= CT[ntt_loop];
                PWM[ntt_loop] <= PWM[ntt_loop];
            end
            endcase
        end
    end
end

// ---------------------------------------------------------------- DONE, DOUT

// done
always @(posedge clk or posedge reset) begin
    if(reset)
        done <= 0;
    else begin
        case(curr_state)
        OP_FNTT: done <= (op_cntr == (FNTT_CC-8'd1)) ? 1'b1 : 1'b0;
        OP_INTT: done <= (op_cntr == (INTT_CC-8'd1)) ? 1'b1 : 1'b0;
        OP_PWM2: done <= (op_cntr == (PWM2_CC-8'd1)) ? 1'b1 : 1'b0;
        // OP_POS: done <= (op_cntr == (POS_CC-10'd1)) ? 1'b1 : 1'b0;
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
            if(do_cntr > 7'd0)
                dout <= (do_cntr[0] == 1'd1) ? ((read_ab == 1'd0) ? {do0[0],do0[1],do0[2],do0[3]} : {do1[0],do1[1],do1[2],do1[3]}) :
                                               ((read_ab == 1'd0) ? {do0[4],do0[5],do0[6],do0[7]} : {do1[4],do1[5],do1[6],do1[7]});
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
                    raddr_tw
                    );

// ---------------------------------------------------------------- BRAMs

generate
	genvar k;

    for(k=0; k<PE_NUMBER ;k=k+1) begin: BRAM1_GEN_BLOCK
        BRAM bd00(clk,de0[2*k+0],dw0[2*k+0],di0[2*k+0],dr0[2*k+0],do0[2*k+0]);
        BRAM bd01(clk,de0[2*k+1],dw0[2*k+1],di0[2*k+1],dr0[2*k+1],do0[2*k+1]);
    end
endgenerate

generate
	genvar j;

    for(j=0; j<PE_NUMBER ;j=j+1) begin: BRAM2_GEN_BLOCK
        BRAM bd10(clk,de1[2*j+0],dw1[2*j+0],di1[2*j+0],dr1[2*j+0],do1[2*j+0]);
        BRAM bd11(clk,de1[2*j+1],dw1[2*j+1],di1[2*j+1],dr1[2*j+1],do1[2*j+1]);
    end
endgenerate

// ---------------------------------------------------------------- BROMs

BROM_PRE bt00(clk,tr,to);

// ---------------------------------------------------------------- BUTTERFLY UNIT

generate
	genvar m;

    for(m=0; m<PE_NUMBER ;m=m+1) begin: BTF_GEN_BLOCK
//        butterfly btfu(clk,reset,
//                       CT[m],
//                       PWM[m],
//			           A[m],B[m],W[m],
//				       E[m],O[m],
//				       MUL[m],
//				       ADD[m],SUB[m]);
				       
		// butterfly_xing btfu(clk,reset,
        //                CT[m],
        //                PWM[m],
		// 	           A[m],B[m],W[m],
		// 		       E[m],O[m],
		// 		       MUL[m],
		// 		       ADD[m],SUB[m]);

        butterfly_Best btfu(clk,reset,
                       CT[m],
                       PWM[m],
			           A[m],B[m],W[m],
				       E[m],O[m],
				       MUL[m],
				       ADD[m],SUB[m]);
    end
endgenerate

// ----------------------------------------------------------------

endmodule
