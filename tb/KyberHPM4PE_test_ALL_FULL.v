
// This module tests full polynomial multiplication
// -1st and 2nd polynomials in POLY domain

`timescale 1ns / 1ps
`include "config.vh"

module KyberHPM4PE_test_ALL_FULL();

parameter HP = 5;
parameter FP = (2*HP);

parameter PE_NUMBER=4;

reg                     clk,reset;
reg                     load_a_f,load_a_i;
reg                     load_b_f,load_b_i;
reg                     read_a,read_b;
reg                     start_ab;
reg                     start_fntt,start_pwm2,start_intt;
reg                     start_pos; // note startup sequence
reg  [12*PE_NUMBER-1:0] din;
wire [12*PE_NUMBER-1:0] dout;
wire                    done;

// ---------------------------------------------------------------- CLK

always #HP clk = ~clk;

// ---------------------------------------------------------------- TXT data

reg [11:0] dina [0:255];
reg [11:0] dinb [0:255];
reg [11:0] doua	[0:255];
reg [11:0] posd [0:255];

initial begin
	// ntt
	$readmemh(`KYBER_PE4_DIN0    , dina);
	$readmemh(`KYBER_PE4_DIN1    , dinb);
	$readmemh(`KYBER_PE4_DOUT    , doua);
    $readmemh(`KYBER_PE4_POS_RES ,  posd);
end

// ---------------------------------------------------------------- TEST case

integer k;
integer m;
integer e;

reg [11:0] fout[0:255];

initial begin: CLK_RESET_INIT
	// clk & reset (150 cc)
	clk       = 0;
	reset     = 0;

	#200;
	reset    = 1;
	#200;
	reset    = 0;
	#100;

	#1000;
end

initial begin: LOAD_TEST_DATA
    e          = 0;
    load_a_f   = 0;
    load_a_i   = 0;
    load_b_f   = 0;
    load_b_i   = 0;
    read_a     = 0;
    read_b     = 0;
    start_ab   = 0;
    start_fntt = 0;
    start_pwm2 = 0;
    start_pos = 0;
    start_intt = 0;
    din        = 0;

    #1500;

    // load input data
    load_a_f   = 1;
    #FP;
    load_a_f   = 0;

    // ---- DATA#0
    /*
    Input on txt file      : 0, 1, 2, 3, 4, 5, ...
    Input on memory (BRAMs):
    BR1 BR2 BR3 BR4 BR5 BR6 BR7 BR8
     0  128  1  129  2  130  3  131
     4  132  5  133  6  134  7  135
     8  136  9  137  10 138  11 139
    ... ...
    */
    for(k=0; k<256; k=k+PE_NUMBER) begin
        din = {dina[k+0],
			   dina[k+1],
			   dina[k+2],
			   dina[k+3]};
        #FP;
    end

	#(2*FP);

	// load input data
    load_b_f   = 1;
    #FP;
    load_b_f   = 0;

    // ---- DATA#1
    /*
    Input on txt file      : 0, 1, 2, 3, 4, 5, ...
    Input on memory (BRAMs):
    BR1 BR2 BR3 BR4 BR5 BR6 BR7 BR8
     0  128  1  129  2  130  3  131
     4  132  5  133  6  134  7  135
     8  136  9  137  10 138  11 139
    ... ...
    */
    for(k=0; k<256; k=k+PE_NUMBER) begin
        din = {dinb[k+0],
			   dinb[k+1],
			   dinb[k+2],
			   dinb[k+3]};
        #FP;
    end

	#(2*FP);

    // start FNTT (for 1st polynomial)
	start_fntt = 1; start_ab = 0; #FP;
	start_fntt = 0;	start_ab = 0; #(2*FP);

	while(done == 1'b0) begin
        #FP;
    end

    // start FNTT (for 2nd polynomial)
    start_fntt = 1; start_ab = 1; #FP;
	start_fntt = 0;	start_ab = 0; #(2*FP);

	while(done == 1'b0) begin
        #FP;
    end

    // start pos
    start_pos = 1; start_ab = 0; #FP;
    start_pos = 0;	start_ab = 0;
    for(k=0; k<256; k=k+PE_NUMBER) begin
        din = {posd[k+0],
			   posd[k+1],
			   posd[k+2],
			   posd[k+3]};
        #FP;
    end

//     // start PWM2
//	 start_pwm2 = 1; start_ab = 0; #FP;
//	 start_pwm2 = 0;	start_ab = 0; #(2*FP);

//	 while(done == 1'b0) begin
//         #FP;
//     end

    // start INTT
	start_intt = 1; start_ab = 0; #FP;
	start_intt = 0;	start_ab = 0; #(2*FP);

	while(done == 1'b0) begin
        #FP;
    end

	#(2*FP);

	read_a = 1;
	#FP;
	read_a = 0;
	#(2*FP);

	// Store result
    /*
    Input on txt file      : 0, 1, 2, 3, 4, 5, ...
    Input on memory (BRAMs):
    BR1 BR2 BR3 BR4 BR5 BR6 BR7 BR8
     0  128  1  129  2  130  3  131
     4  132  5  133  6  134  7  135
     8  136  9  137  10 138  11 139
    ... ...
    */
	for(m=0; m<128; m=m+(PE_NUMBER>>1)) begin
        {fout[m+0],fout[m+128],fout[m+1],fout[m+129]} = dout;
        #FP;
    end

    #100;

	// Check result
    for(m=0; m<256; m=m+1) begin
        if(fout[m] == doua[m]) begin
			e = e+1;
        end
		else begin
			$display("Wrong result -- index:%d, expected:%h --> calculated:%h",m,doua[m],fout[m]);
		end
    end

    if(e == 256)
        $display("FULL PMUL -- Correct!");
    else
        $display("FULL PMUL -- Incorrect!");

    $stop;

end

// ---------------------------------------------------------------- UUT

KyberHPM4PE uut (clk,reset,
	             load_a_f,load_a_i,
	             load_b_f,load_b_i,
	             read_a,read_b,
                 start_ab,
                 start_pos,
	             start_fntt,start_pwm2,start_intt,
	             din,
	             dout,
	             done);

endmodule
