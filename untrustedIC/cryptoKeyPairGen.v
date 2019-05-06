// Copyright 2018 Ioannis Karageorgos, Carnegie Mellon University.
// Copyright and related rights are licensed under the Solderpad Hardware 
// License, Version 2.0 (the "License"); you may not use this file except in 
// compliance with the License. You may obtain a copy of the License at 
// <http://solderpad.org/licenses/SHL-2.0>. Unless required by applicable law 
// or agreed to in writing, software, hardware and materials distributed under 
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR 
// CONDITIONS OF ANY KIND, either express or implied. See the License for the 
// specific language governing permissions and limitations under the License.

///////////////////////////////////////////////////////////////////////////////////
// Engineer:       Ioannis Karageorgos <ioannis.karageorgos@yale.edu>            //
//                                                                               //
// Design Name:    Crypto key pair generator                                     //
// Project Name:   Split-Chip_authentication                                     //
// Language:       Verilog                                                       //
//                                                                               //
// Description:    Top level module of the RSA key pair generation mechanism.    //
//                 When 'ready' output gets high, 'MOD' holds the modulus (n)    //
//                 and 'privateKey' holds the modular multiplicative inverse of  //
//                 e(mod f(n)), which is the private key.                        //
///////////////////////////////////////////////////////////////////////////////////

`include "__timescale.v"
`include "__parameters.vh"

module cryptoKeyPairGen #(
        parameter KEY_LENGTH = 32,
        parameter integer HALF_KEY_LENGTH = 0.5 * KEY_LENGTH,
        parameter e_WIDTH = 3  // set minimum of 3
    )(
        input clk,
        input rst,
        input [(8*KEY_LENGTH)-1 : 0] noisyIn, // 16*HALF_KEY_LENGTH
        input [e_WIDTH-1:0] e,
        input modExp_ready,
        input [511:0] modExp_out,
        output modExp_rst,
        output [511:0] modExp_x,
        output [511+e_WIDTH:0] modExp_y,
        output [9:0] modExp_y_size,
        output [511:0] modExp_m,
        output modExp_start,
        output reg ready,
        output reg [KEY_LENGTH-1:0] MOD,
        output reg [KEY_LENGTH+e_WIDTH:0] privateKey
    );

    wire [HALF_KEY_LENGTH-1:0] prime;
    reg [HALF_KEY_LENGTH-1:0] p1_sig, p2_sig;
    wire [KEY_LENGTH+e_WIDTH:0] privateKey_sig;
    wire newPrimeReady;
    reg primesReady;
    reg GCDStart;
    wire GCDReady;
    wire [KEY_LENGTH-1:0] GCDMODOut;
    wire [KEY_LENGTH-1:0] GCDF_nOut;
    reg [KEY_LENGTH-1:0] f_n_sig;
    reg privateKeyGenStart;
    wire privateKeyGenReady;
    wire primesValid_sig;
    reg noiseFilter_rst;
    reg primeGen_rst;
    reg GCD_rst;
    reg privateKeyGen_rst;
    wire [HALF_KEY_LENGTH-1:0] noiseFilterOut;
    wire noiseFilterReady;

    noiseFilter #(.HALF_KEY_LENGTH(HALF_KEY_LENGTH)) noiseFilter (
        .clk(clk), 
        .rst(noiseFilter_rst), 
        .in(noisyIn), 
        .out(noiseFilterOut),
        .ready(noiseFilterReady)
    );

    primeGen #(.KEY_LENGTH(KEY_LENGTH), .e_WIDTH(e_WIDTH)) primeGen (
        .clk(clk), 
        .rst(primeGen_rst), 
        .seed(noiseFilterOut), 
        .modExp_ready(modExp_ready),
        .modExp_out(modExp_out),
        .modExp_rst(modExp_rst),
        .modExp_x(modExp_x),
        .modExp_y(modExp_y),
        .modExp_y_size(modExp_y_size),
        .modExp_m(modExp_m),
        .modExp_start(modExp_start),
        .prime(prime),
        .ready(newPrimeReady)
    );

    GCD #(.HALF_KEY_LENGTH(HALF_KEY_LENGTH), .e_WIDTH(e_WIDTH)) GCD (
        .clk(clk), 
        .rst(GCD_rst), 
        .p1(p1_sig),
        .p2(p2_sig),
        .e(e),
        .start(GCDStart),
        .areValid(primesValid_sig),
        .MOD(GCDMODOut),
        .f_n(GCDF_nOut),
        .ready(GCDReady)
    );

    privateKeyGen #(.HALF_KEY_LENGTH(HALF_KEY_LENGTH), .e_WIDTH(e_WIDTH)) privateKeyGen (
        .clk(clk), 
        .rst(privateKeyGen_rst), 
        .f_n(f_n_sig),
        .e(e),
        .start(privateKeyGenStart),
        .ready(privateKeyGenReady),
        .privateKey(privateKey_sig)
    );

    reg [2:0] state, next_state;
    localparam STATE_OFF = 3'd0;
    localparam STATE_NOISE_FILTER = 3'd1;
    localparam STATE_PRIME_GENERATOR = 3'd2;
    localparam STATE_GCD = 3'd3;
    localparam STATE_PRIVATE_KEY_GENERATOR = 3'd4;
    localparam STATE_READY = 3'd5;

    always @(posedge clk) begin
        if (rst == 0) begin
            state <= STATE_OFF;
        end
        else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;

        case (state)
            STATE_OFF: begin
                next_state = STATE_NOISE_FILTER;
            end

            STATE_NOISE_FILTER: begin
                if ( noiseFilterReady ) begin
                    next_state = STATE_PRIME_GENERATOR;
                end
            end

            STATE_PRIME_GENERATOR: begin
                if ( primesReady ) begin
                    next_state = STATE_GCD;
                end
            end

            STATE_GCD: begin
                if (GCDReady) begin
                    if (primesValid_sig) begin
                        next_state = STATE_PRIVATE_KEY_GENERATOR;
                    end
                    else begin
                        next_state = STATE_PRIME_GENERATOR;
                    end
                end
            end

            STATE_PRIVATE_KEY_GENERATOR: begin
                if (privateKeyGenReady) begin
                    next_state = STATE_READY;
                end
            end

            STATE_READY: begin
                
            end

            default: begin
                next_state = STATE_NOISE_FILTER;
            end
        endcase
    end

    always @(posedge clk) begin
        case (state)
            STATE_OFF: begin
                ready <= 0;
                MOD <= 0;
                privateKey <= 0;

                p1_sig <= 0;
                p2_sig <= 0;
                primesReady <= 0;
                GCDStart <= 0;
                privateKeyGenStart <= 0;
                f_n_sig <= 0;

                noiseFilter_rst <= 0;
                primeGen_rst <= 0;
                GCD_rst <= 0;
                privateKeyGen_rst <= 0;
            end

            STATE_NOISE_FILTER: begin
                ready <= 0;
                MOD <= 0;
                privateKey <= 0;

                p1_sig <= 0;
                p2_sig <= 0;
                primesReady <= 0;
                GCDStart <= 0;
                privateKeyGenStart <= 0;
                f_n_sig <= 0;

                noiseFilter_rst <= 1'b1;
                primeGen_rst <= 0;
                GCD_rst <= 0;
                privateKeyGen_rst <= 0;
            end

            STATE_PRIME_GENERATOR: begin
                if (newPrimeReady) begin
                    p1_sig <= prime;
                    p2_sig <= p1_sig;
                    if (|p1_sig) begin
                        primesReady <= 1'b1;
                    end
                    else begin
                        primesReady <= primesReady;
                    end
                end
                else begin
                    p1_sig <= p1_sig;
                    p2_sig <= p2_sig;
                    primesReady <= 0;
                end

                if (next_state == STATE_GCD) begin
                    GCDStart <= 1'b1;
                    GCD_rst <= 1'b1;
                end
                else begin
                    GCDStart <= 0;
                    GCD_rst <= 0;
                end

                ready <= 0;
                MOD <= 0;
                privateKey <= 0;

                privateKeyGenStart <= 0;
                f_n_sig <= 0;

                noiseFilter_rst <= 1'b1;
                primeGen_rst <= 1'b1;
                privateKeyGen_rst <= 0;
            end

            STATE_GCD: begin
                ready <= 0;
                MOD <= GCDMODOut;
                privateKey <= 0;

                p1_sig <= p1_sig;
                p2_sig <= p2_sig;
                primesReady <= primesReady;
                GCDStart <= 0;
                f_n_sig <= GCDF_nOut;

                noiseFilter_rst <= 1'b1;
                primeGen_rst <= 1'b1;
                GCD_rst <= 1'b1;

                if (next_state == STATE_PRIVATE_KEY_GENERATOR) begin
                    privateKeyGenStart <= 1'b1;
                    privateKeyGen_rst <= 1'b1;
                end
                else begin
                    privateKeyGenStart <= 0;
                    privateKeyGen_rst <= 0;
                end
            end

            STATE_PRIVATE_KEY_GENERATOR: begin
                ready <= 0;
                MOD <= MOD;
                privateKey <= privateKey_sig;

                p1_sig <= 0;
                p2_sig <= 0;
                primesReady <= 0;
                GCDStart <= 0;
                privateKeyGenStart <= 0;
                f_n_sig <= f_n_sig;

                noiseFilter_rst <= 0;
                primeGen_rst <= 0;
                GCD_rst <= 1'b1;
                privateKeyGen_rst <= 1'b1;
            end

            STATE_READY: begin
                ready <= 1'b1;
                MOD <= MOD;
                privateKey <= privateKey;

                p1_sig <= 0;
                p2_sig <= 0;
                primesReady <= 0;
                GCDStart <= 0;
                privateKeyGenStart <= 0;
                f_n_sig <= 0;

                noiseFilter_rst <= 0;
                primeGen_rst <= 0;
                GCD_rst <= 0;
                privateKeyGen_rst <= 0;
            end

            default: begin
                ready <= 0;
                MOD <= 0;
                privateKey <= 0;

                p1_sig <= 0;
                p2_sig <= 0;
                primesReady <= 0;
                GCDStart <= 0;
                privateKeyGenStart <= 0;
                f_n_sig <= 0;

                noiseFilter_rst <= 0;
                primeGen_rst <= 0;
                GCD_rst <= 0;
                privateKeyGen_rst <= 0;
            end
        endcase
    end

endmodule
