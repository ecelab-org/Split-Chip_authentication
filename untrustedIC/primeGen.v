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
// Design Name:    Prime number generator                                        //
// Project Name:   Split-Chip_authentication                                     //
// Language:       Verilog                                                       //
//                                                                               //
// Description:    Main FSM for generating prime numbers. Requests a new         //
//                 pseudo-random number from the LFSR and uses the primality     //
//                 tester to determine if it is prime. It keeps requesting new   //
//                 numbers until it finds a prime.                               //
///////////////////////////////////////////////////////////////////////////////////

`include "__timescale.v"
`include "__parameters.vh"


module primeGen #(
        parameter KEY_LENGTH = 32,
        parameter integer HALF_KEY_LENGTH = 0.5 * KEY_LENGTH,
        parameter e_WIDTH = 3
    )(
        input clk,
        input rst,
        input [HALF_KEY_LENGTH-1:0] seed,
        input modExp_ready,
        input [511:0] modExp_out,
        output modExp_rst,
        output [511:0] modExp_x,
        output [511+e_WIDTH:0] modExp_y,
        output [9:0] modExp_y_size,
        output [511:0] modExp_m,
        output modExp_start,
        output reg [HALF_KEY_LENGTH-1:0] prime,
        output reg ready
    );

    wire [HALF_KEY_LENGTH-1:0] primeUnderTest;
    reg [HALF_KEY_LENGTH-1:0] primeUnderTest_buf;
    wire isPrime, done;
    reg generateNext_sig, primalityTest_start, rst_buf;

    LFSR_UIC #(.HALF_KEY_LENGTH(HALF_KEY_LENGTH)) LFSR_UIC (
        .clk(clk), 
        .rst(rst), 
        .generateNext(generateNext_sig), 
        .seed(seed), 
        .out(primeUnderTest)
    );

    primalityTest #(.KEY_LENGTH(KEY_LENGTH), .e_WIDTH(e_WIDTH)) primalityTest (
        .clk(clk), 
        .rst(rst), 
        .in(primeUnderTest), 
        .start(primalityTest_start), 
        .modExp_ready(modExp_ready),
        .modExp_out(modExp_out),
        .modExp_rst(modExp_rst),
        .modExp_x(modExp_x),
        .modExp_y(modExp_y),
        .modExp_y_size(modExp_y_size),
        .modExp_m(modExp_m),
        .modExp_start(modExp_start),
        .done(done),
        .isPrime(isPrime)
    );

    always @(*) begin
        if (!rst) begin
            generateNext_sig = 1'b0;
        end
        else begin
            if (done) begin
                generateNext_sig = 1'b1;
            end
            else begin
                generateNext_sig = 1'b0;
            end
        end
    end

    always @ (posedge clk) begin
        rst_buf <= rst;
    end

    always @ (posedge clk) begin
        if (!rst) begin
            prime <= 0;
            ready <= 0;
            primeUnderTest_buf <= 0;
            primalityTest_start <= 1'b0;
        end
        else begin
            primeUnderTest_buf <= primeUnderTest;

            if (done || !rst_buf) begin
                primalityTest_start <= 1'b1;
            end
            else begin
                primalityTest_start <= 1'b0;
            end

            if (done && isPrime) begin
                prime <= primeUnderTest_buf;
                ready <= 1'b1;
            end 
            else begin
                prime <= prime;
                ready <= 1'b0;
            end
        end
    end

endmodule