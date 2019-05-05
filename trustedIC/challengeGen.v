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
// Design Name:    Challenge generator                                           //
// Project Name:   Split-Chip_authentication                                     //
// Language:       Verilog                                                       //
//                                                                               //
// Description:    Generates a random challenge to be used in the handshaking    //
//                 routine with the untrusted IC.                                //
///////////////////////////////////////////////////////////////////////////////////

`include "__timescale.v"
`include "__parameters.vh"


module challengeGen #(
        parameter CHALLENGE_LENGTH = 32
    )(
        input clk,
        input rst,
        input pause,
        output [CHALLENGE_LENGTH-1:0] out
    );

    reg LFSR_generateNext;
    wire [CHALLENGE_LENGTH-1:0] LFSR_out;
    wire [CHALLENGE_LENGTH-1:0] LFSR_seed;

    // in implementation the LFSR should be replaced with a true random number generator 
    LFSR_TIC #(.CHALLENGE_LENGTH(CHALLENGE_LENGTH)) LFSR_TIC (
        .clk(clk), 
        .rst(rst), 
        .generateNext(~pause),
        .seed(LFSR_seed),
        .out(out)
    );

    always @ (posedge clk) begin
        if (!rst) begin
            LFSR_generateNext <= 0;
        end
        else begin
            if (pause) begin
                LFSR_generateNext <= 0;
            end
            else begin
                LFSR_generateNext <= 1'b1;
            end
        end
    end

    assign LFSR_seed = {{CHALLENGE_LENGTH-32{1'b0}}, 32'h7394_a654};

endmodule
