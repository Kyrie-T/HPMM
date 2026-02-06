`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: tanx
// 
// Create Date: 02/06/2026
// Design Name: Falcon NTT Butterfly with K-RED
// Module Name: butterfly_falcon_kred
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Butterfly unit for Falcon NTT with K-RED modular multiplication
//              q = 12289 = 3 * 2^12 + 1, supporting up to 1024 coefficients
//
// Operations supported:
// -- CT-based butterfly (Cooley-Tukey)
// -- GS-based butterfly (Gentleman-Sande)
// -- Modular add/sub
// -- Modular mul (with implicit -3 factor from K-RED)
//
// Note: K-RED outputs (-3 * a * b) mod q. For correct NTT, twiddle factors
//       should be pre-multiplied by (-3)^(-1) mod 12289 = 4096
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module butterfly_falcon_kred(
    input         clk,
    input         rst,
    input         CT,           // 0: GS mode, 1: CT mode
    input         PWM,          // Point-wise multiplication mode
    input  [13:0] A,            // First input coefficient
    input  [13:0] B,            // Second input coefficient
    input  [13:0] W,            // Twiddle factor
    output [13:0] E,            // Even output (butterfly)
    output [13:0] O,            // Odd output (butterfly) + PWM output
    output [13:0] MUL,          // Modular multiplication output
    output [13:0] ADD,          // Modular addition output
    output [13:0] SUB           // Modular subtraction output
);

// CT:0 -> GS-based butterfly (input from A,B,W -- output from E,O)
// CT:1 -> CT-based butterfly (input from A,B,W -- output from E,O)
// CT:0 -> Mod Add/Sub (input from A,B -- output from ADD/SUB)
// CT:1 -> Mod Mult (input from B,W -- output from MUL)
// CT:1 + PWM:1 -> PWM operation (input from B,W -- output from E,O)

//=============================================================================
// Internal signals
//=============================================================================
reg  [13:0] Ar0, Ar1;           // A input pipeline registers
wire [13:0] w0, w1;             // Mux outputs for add/sub inputs
wire [13:0] w2, w3;             // Add/sub results
reg  [13:0] w2r0, w3r0;         // Registered add/sub results
reg  [13:0] w2r1, w2r2;         // Additional pipeline for div2
wire [13:0] w2r1d2;             // div2 output
wire [13:0] w4;                 // Multiplier input selection
reg  [13:0] Wr0;                // W pipeline register
wire [13:0] Ww;                 // Selected twiddle factor
wire [13:0] w5;                 // Multiplier output
reg  [13:0] w5r0;               // Registered multiplier output
wire [13:0] w5r0d2;             // div2 of multiplier output
wire [13:0] w6;                 // Final odd output selection
reg  [13:0] w6r0;               // Registered odd output
wire [13:0] w7;                 // Final even output selection

//=============================================================================
// Input pipeline with PWM feedback
//=============================================================================
always @(posedge clk or posedge rst) begin
    if (rst)
        {Ar0, Ar1} <= 28'd0;
    else
        {Ar0, Ar1} <= (PWM) ? {w5r0, Ar0} : {A, Ar0};
end

//=============================================================================
// Input selection for adder/subtractor
//=============================================================================
assign w0 = (CT) ? w5r0 : B;    // CT: use mult result; GS: use B input
assign w1 = (CT) ? Ar1  : A;    // CT: use delayed A; GS: use A input

//=============================================================================
// Modular addition and subtraction
//=============================================================================
falcon_modadd ma0(
    .A(w1),
    .B(w0),
    .C(w2)
);

falcon_modsub ms0(
    .A(w1),
    .B(w0),
    .C(w3)
);

//=============================================================================
// Add/Sub result pipeline
//=============================================================================
always @(posedge clk or posedge rst) begin
    if (rst)
        {w2r0, w3r0} <= 28'd0;
    else
        {w2r0, w3r0} <= {w2, w3};
end

always @(posedge clk or posedge rst) begin
    if (rst)
        {w2r1, w2r2} <= 28'd0;
    else
        {w2r1, w2r2} <= {w2r0, w2r1d2};
end

//=============================================================================
// Division by 2 for GS butterfly
//=============================================================================
falcon_div2 d0(
    .x(w2r1),
    .y(w2r1d2)
);

//=============================================================================
// Even output selection
//=============================================================================
assign w7 = (CT) ? w2r0 : w2r2;

//=============================================================================
// Multiplier input selection
//=============================================================================
assign w4 = (CT) ? B : w3r0;    // CT: use B directly; GS: use sub result

//=============================================================================
// Twiddle factor pipeline
//=============================================================================
always @(posedge clk or posedge rst) begin
    if (rst)
        Wr0 <= 14'd0;
    else
        Wr0 <= W;
end

assign Ww = (CT) ? W : Wr0;     // CT: use W directly; GS: use delayed W

//=============================================================================
// K-RED Modular Multiplication
// Note: outputs (-3 * Ww * w4) mod q
//=============================================================================
falcon_KRED kred_mult(
    .clk(clk),
    .a(Ww),
    .b(w4),
    .c_mod_q(w5)
);

//=============================================================================
// Multiplier output pipeline
//=============================================================================
always @(posedge clk or posedge rst) begin
    if (rst)
        w5r0 <= 14'd0;
    else
        w5r0 <= w5;
end

//=============================================================================
// Division by 2 for multiplier result (GS mode)
//=============================================================================
falcon_div2 d1(
    .x(w5r0),
    .y(w5r0d2)
);

//=============================================================================
// Odd output selection
//=============================================================================
assign w6 = (CT) ? w3r0 : w5r0d2;

always @(posedge clk or posedge rst) begin
    if (rst)
        w6r0 <= 14'd0;
    else
        w6r0 <= w6;
end

//=============================================================================
// Final outputs
//=============================================================================
assign E   = w7;        // Even butterfly output
assign O   = w6r0;      // Odd butterfly output
assign MUL = w5r0;      // Modular multiplication output
assign ADD = w2r0;      // Modular addition output
assign SUB = w3r0;      // Modular subtraction output

endmodule
