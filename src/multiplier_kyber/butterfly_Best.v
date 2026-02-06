
// This unit can perform operations below:
// -- CT-based butterfly
// -- GS-based butterfly
// -- Modular add/sub
// -- Modular mul

module butterfly_Best(input clk,rst,
                 input CT,
                 input PWM,
                 input [11:0] A,B,W,
                 output[11:0] E,O,       // butterfly outputs + pwm output
                 output[11:0] MUL,       // modular mult output
                 output[11:0] ADD,SUB);  // modular add/sub outputs

// CT:0 -> GS-based butterfly (take input from A,B,W -- output from E,O)
// CT:1 -> CT-based bu tterfly (take input from A,B,W -- output from E,O)
// CT:0 -> Mod Add/Sub (take input from A,B -- output from ADD/SUB)
// CT:1 -> Mod Mult (take input from B,W -- output from MUL)
// CT:1 + PWM:1 -> PWM operation (take input from B,W -- output from E,O)

// --------- Control signals need to be DFFed.

// 3reg
// Signals
reg  [11:0] Ar0,Ar1,Ar2,Ar3;
wire [11:0] w0,w1;
wire [11:0] w2,w3;
reg  [11:0] w2r0,w3r0;
reg  [11:0] w2r1,w2r2,w2r3,w2r4;
wire [11:0] w2r1d2;
wire [11:0] w4;
reg  [11:0] Wr0;
wire [11:0] Ww;
wire [11:0] w5;
reg  [11:0] w5r0;
wire [11:0] w5r0d2;
wire [11:0] w6;
reg  [11:0] w6r0;
wire [11:0] w7;

// always @(posedge clk or posedge rst) begin
//     if(rst)
//         {Ar0,Ar1} <= 24'd0;
//     else
//         {Ar0,Ar1} <= (PWM) ? {w5r0,Ar0} : {A,Ar0};
// end

always @(posedge clk or posedge rst) begin
    if(rst)
        {Ar0,Ar1,Ar2,Ar3} <= 24'd0;
    else
        {Ar0,Ar1,Ar2,Ar3} <= (PWM) ? {w5r0,Ar0,Ar1,Ar2} : {A,Ar0,Ar1,Ar2};
end

assign w0 = (CT) ? w5r0 : B;
// assign w1 = (CT) ? Ar1  : A;
assign w1 = (CT) ? Ar3  : A;

modadd ma0(w1,w0,w2);
modsub ms0(w1,w0,w3);

always @(posedge clk or posedge rst) begin
    if(rst)
        {w2r0,w3r0} <= 0;
    else
        {w2r0,w3r0} <= {w2,w3};
end

// always @(posedge clk or posedge rst) begin
//     if(rst)
//         {w2r1,w2r2} <= 24'd0;
//     else
//         {w2r1,w2r2} <= {w2r0,w2r1d2};
// end

always @(posedge clk or posedge rst) begin
    if(rst)
        {w2r1,w2r2,w2r3} <= 24'd0;
    else
        {w2r1,w2r2,w2r3} <= {w2r0,w2r1,w2r2};
end

always @(posedge clk or posedge rst) begin
    if(rst)
        w2r4 <= 24'd0;
    else
        w2r4 <= w2r1d2;
end

// div2 d0(w2r1,w2r1d2);
div2 d0(w2r3,w2r1d2);

assign w7 = (CT) ? w2r0 : w2r4;

assign w4 = (CT) ? B : w3r0;

always @(posedge clk or posedge rst) begin
    if(rst)
        Wr0 <= 0;
    else
        Wr0 <= W;
end

assign Ww = (CT) ? W : Wr0;


butterfly_best_KRED Our_reduction(clk,Ww,w4,w5);
// Barrett_reduction Our_reduction(clk,Ww,w4,w5);
// Kred_mod_mult Our_reduction(clk,Ww,w4,w5);

always @(posedge clk or posedge rst) begin
    if(rst)
        w5r0 <= 0;
    else
        w5r0 <= w5;
end

div2 d1(w5r0,w5r0d2);

assign w6 = (CT) ? w3r0 : w5r0d2;

always @(posedge clk or posedge rst) begin
    if(rst)
        w6r0 <= 0;
    else
        w6r0 <= w6;
end

// ---------------------------------------- Final Outputs

assign E = w7;
assign O = w6r0;

assign MUL = w5r0;

assign ADD = w2r0;
assign SUB = w3r0;

endmodule
