`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: tanx
// 
// Create Date: 02/06/2026
// Design Name: 
// Module Name: butterfly_falcon_kred_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Testbench for Falcon NTT Butterfly with K-RED
//              Tests CT/GS butterfly operations for q = 12289
//              Falcon supports up to 1024 coefficients, primitive root = 7
//
// Important: K-RED outputs (-3 * a * b) mod q
//            Twiddle factors must be pre-multiplied by (-3)^(-1) mod 12289 = 4096
//
// Revision:
// Revision 0.01 - File Created
// Revision 0.02 - Simplified using fixed delay like original butterfly_tb
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module butterfly_falcon_kred_tb_simple();

`define TESTBENCH_SIZE  100          // Falcon max coefficients
`define MODULUS_WIDTH   14            // 14-bit for q=12289
`define NO_OF_TWIDDLES_TESTED 100    // Number of twiddle factors to test

localparam Q = 12289;                 // Falcon modulus
localparam PRIMITIVE_ROOT = 7;        // Primitive 2n-th root of unity (ψ)
localparam KRED_FACTOR = 4096;        // (-3)^(-1) mod 12289

reg clk;
reg CT, PWM, rst;
reg [`MODULUS_WIDTH-1:0] input_a, input_b;
reg [`MODULUS_WIDTH-1:0] expected_output_e, expected_output_o;
wire [`MODULUS_WIDTH-1:0] output_e [`NO_OF_TWIDDLES_TESTED-1:0];
wire [`MODULUS_WIDTH-1:0] output_o [`NO_OF_TWIDDLES_TESTED-1:0];

always #5 clk = ~clk;

//=============================================================================
// Helper functions
//=============================================================================

function [`MODULUS_WIDTH-1:0] modular_pow;
    input [2*`MODULUS_WIDTH-1:0] base;
    input [`MODULUS_WIDTH-1:0] modulus, exponent;
    begin
        if (modulus == 1) begin
            modular_pow = 0;
        end else begin
            modular_pow = 1;
            while (exponent > 0) begin
                if (exponent[0] == 1)
                    modular_pow = ({20'b0, modular_pow} * base) % modulus;
                exponent = exponent >> 1;
                base = (base * base) % modulus;
            end
        end
    end
endfunction

function [`MODULUS_WIDTH-1:0] modular_mult;
    input [2*`MODULUS_WIDTH-1:0] input1;
    input [2*`MODULUS_WIDTH-1:0] input2;
    input [`MODULUS_WIDTH-1:0] modulus;
    begin
        modular_mult = (input1 * input2) % modulus;
    end
endfunction

function [`MODULUS_WIDTH-1:0] modular_div2;
    input [`MODULUS_WIDTH-1:0] x;
    input [`MODULUS_WIDTH-1:0] modulus;
    begin
        if (x[0] == 0)
            modular_div2 = x >> 1;
        else
            // Avoid overflow: (x + modulus) >> 1 = (x >> 1) + ((modulus + 1) >> 1)
            // For modulus = 12289 (odd), (modulus + 1) >> 1 = 6145
            modular_div2 = (x >> 1) + ((modulus + 1) >> 1);
    end
endfunction

// Get twiddle factor pre-multiplied by KRED_FACTOR for DUT input
function [`MODULUS_WIDTH-1:0] get_twiddle_adjusted;
    input [31:0] i;
    reg [`MODULUS_WIDTH-1:0] psi_power;
    begin
        psi_power = modular_pow(PRIMITIVE_ROOT, Q, i);
        get_twiddle_adjusted = modular_mult(psi_power, KRED_FACTOR, Q);
    end
endfunction

//=============================================================================
// Generate butterfly instances for all twiddle factors
//=============================================================================
generate
    genvar i;
    for (i = 0; i < `NO_OF_TWIDDLES_TESTED; i = i + 1) begin: BUTTERFLIES
        butterfly_falcon_kred butterfly_falcon(
            .clk(clk),
            .rst(rst),
            .CT(CT),
            .PWM(PWM),
            .A(input_a),
            .B(input_b),
            .W(modular_mult(KRED_FACTOR, modular_pow(PRIMITIVE_ROOT, Q, i), Q)),
            .E(output_e[i]),
            .O(output_o[i]),
            .MUL(),
            .ADD(),
            .SUB()
        );
    end
endgenerate

//=============================================================================
// Test sequence
//=============================================================================
integer m, test_bench;
integer iterator_ct_e, iterator_ct_o;
integer iterator_gs_e, iterator_gs_o;

initial begin: TEST_BUTTERFLY
    $display("========================================================");
    $display("Falcon Butterfly K-RED Testbench");
    $display("q = %d, primitive root = %d", Q, PRIMITIVE_ROOT);
    $display("K-RED compensation factor = %d", KRED_FACTOR);
    $display("========================================================");
    
    clk = 0;
    rst = 1;
    PWM = 0;
    #10;
    rst = 0;
    iterator_ct_e = 0;
    iterator_ct_o = 0;
    iterator_gs_e = 0;
    iterator_gs_o = 0;
    
    //=========================================================================
    // Test CT Mode
    //=========================================================================
    $display("\n[Test] CT Butterfly Mode...");
    CT = 1;
    #100;
    
    for (test_bench = 0; test_bench < `TESTBENCH_SIZE; test_bench = test_bench + 1) begin
        input_a = (Q - 1);    // Edge case: max value
        input_b = test_bench;
        #100;  // Wait for output to stabilize
        
        for (m = 0; m < `NO_OF_TWIDDLES_TESTED; m = m + 1) begin
            // Expected: E = A + (-3)*W_adj*B = A + W_orig*B (since W_adj = W_orig * 4096)
            // K-RED computes (-3)*W_adj*B, and (-3)*4096 = 1 mod q
            expected_output_e = (input_a + modular_mult(input_b, 
                modular_mult(modular_mult(KRED_FACTOR, modular_pow(PRIMITIVE_ROOT, Q, m), Q), Q - 3, Q), Q)) % Q;
            expected_output_o = (Q + input_a - modular_mult(input_b, 
                modular_mult(modular_mult(KRED_FACTOR, modular_pow(PRIMITIVE_ROOT, Q, m), Q), Q - 3, Q), Q)) % Q;
            
            if (expected_output_e == output_e[m]) begin
                iterator_ct_e = iterator_ct_e + 1;
            end else begin
                $display("CT E: Testbench: %d Index-%d -- Expected: %d, Got: %d", 
                         test_bench, m, expected_output_e, output_e[m]);
            end
            
            if (expected_output_o == output_o[m]) begin
                iterator_ct_o = iterator_ct_o + 1;
            end else begin
                $display("CT O: Testbench: %d Index-%d -- Expected: %d, Got: %d", 
                         test_bench, m, expected_output_o, output_o[m]);
            end
        end
        #100;
    end
    
    //=========================================================================
    // Test GS Mode
    //=========================================================================
    $display("\n[Test] GS Butterfly Mode...");
    CT = 0;
    rst = 1;
    #10;
    rst = 0;
    #100;
    
    for (test_bench = 0; test_bench < `TESTBENCH_SIZE; test_bench = test_bench + 1) begin
        input_a = test_bench;
        input_b = (test_bench * 3) % Q;
        #100;  // Wait for output to stabilize
        
        for (m = 0; m < `NO_OF_TWIDDLES_TESTED; m = m + 1) begin
            // GS: E = (A + B) / 2
            expected_output_e = modular_div2((input_a + input_b) % Q, Q);
            // GS: O = (A - B) * W / 2, where W includes K-RED factor (-3)
            expected_output_o = modular_div2(modular_mult((Q + input_a - input_b) % Q, 
                modular_mult(modular_mult(KRED_FACTOR, modular_pow(PRIMITIVE_ROOT, Q, m), Q), Q - 3, Q), Q), Q);
            
            if (expected_output_e == output_e[m]) begin
                iterator_gs_e = iterator_gs_e + 1;
            end else begin
                $display("GS E: Testbench: %d Index-%d -- Expected: %d, Got: %d", 
                         test_bench, m, expected_output_e, output_e[m]);
            end
            
            if (expected_output_o == output_o[m]) begin
                iterator_gs_o = iterator_gs_o + 1;
            end else begin
                $display("GS O: Testbench: %d Index-%d -- Expected: %d, Got: %d", 
                         test_bench, m, expected_output_o, output_o[m]);
            end
        end
        #100;
    end
    
    //=========================================================================
    // Results
    //=========================================================================
    $display("\n========================================================");
    $display("FINAL RESULTS");
    $display("========================================================");
    
    $display("\nCT Butterfly Mode:");
    if (iterator_ct_e == (`NO_OF_TWIDDLES_TESTED * `TESTBENCH_SIZE))
        $display("  CT E output: CORRECT");
    else
        $display("  CT E output: INCORRECT (%d/%d passed)", iterator_ct_e, `NO_OF_TWIDDLES_TESTED * `TESTBENCH_SIZE);
    
    if (iterator_ct_o == (`NO_OF_TWIDDLES_TESTED * `TESTBENCH_SIZE))
        $display("  CT O output: CORRECT");
    else
        $display("  CT O output: INCORRECT (%d/%d passed)", iterator_ct_o, `NO_OF_TWIDDLES_TESTED * `TESTBENCH_SIZE);
    
    $display("\nGS Butterfly Mode:");
    if (iterator_gs_e == (`NO_OF_TWIDDLES_TESTED * `TESTBENCH_SIZE))
        $display("  GS E output: CORRECT");
    else
        $display("  GS E output: INCORRECT (%d/%d passed)", iterator_gs_e, `NO_OF_TWIDDLES_TESTED * `TESTBENCH_SIZE);
    
    if (iterator_gs_o == (`NO_OF_TWIDDLES_TESTED * `TESTBENCH_SIZE))
        $display("  GS O output: CORRECT");
    else
        $display("  GS O output: INCORRECT (%d/%d passed)", iterator_gs_o, `NO_OF_TWIDDLES_TESTED * `TESTBENCH_SIZE);
    
    if (iterator_ct_e == (`NO_OF_TWIDDLES_TESTED * `TESTBENCH_SIZE) && 
        iterator_ct_o == (`NO_OF_TWIDDLES_TESTED * `TESTBENCH_SIZE) &&
        iterator_gs_e == (`NO_OF_TWIDDLES_TESTED * `TESTBENCH_SIZE) && 
        iterator_gs_o == (`NO_OF_TWIDDLES_TESTED * `TESTBENCH_SIZE)) begin
        $display("\n*** ALL TESTS PASSED! ***");
    end else begin
        $display("\n*** SOME TESTS FAILED! ***");
    end
    
    $display("========================================================\n");
    $stop();
end

endmodule
