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
// Design Name:    Linear-Feedback Shift Register                                //
// Project Name:   Split-Chip_authentication                                     //
// Language:       Verilog                                                       //
//                                                                               //
// Description:    The LFSR generates pseudo-random numbers on demand. The       //
//                 pseudo-random number sequence is controlled/altered by        //
//                 setting the initial condition (the 'seed'). The 'seed' is     //
//                 captured at the last clock rising edge before reset signal    //
//                 is asserted                                                   //
///////////////////////////////////////////////////////////////////////////////////

`include "__timescale.v"
`include "__parameters.vh"

module LFSR_TIC #(
        parameter CHALLENGE_LENGTH = 32
    )(
        input clk,
        input rst,
        input generateNext,
        input [CHALLENGE_LENGTH-1:0] seed,
        output [CHALLENGE_LENGTH-1:0] out
    );

    wire feedback;
    reg [CHALLENGE_LENGTH-1:0] out_tmp;

    assign feedback = !(out_tmp[CHALLENGE_LENGTH-1] ^ out_tmp[CHALLENGE_LENGTH-3] ^ out_tmp[CHALLENGE_LENGTH-4] ^ out_tmp[10] ^ out_tmp[0]);

    always @ (posedge clk) begin
        if (!rst) begin
            out_tmp <= seed;
        end
        else begin
            if (generateNext) begin
                out_tmp <= {out_tmp[CHALLENGE_LENGTH-2 : 0], feedback};
            end
            else begin
                out_tmp <= out_tmp;
            end
        end
    end

    assign out[CHALLENGE_LENGTH-3:0] = out_tmp[CHALLENGE_LENGTH-3:0];
    assign out[CHALLENGE_LENGTH-1:CHALLENGE_LENGTH-2] = 2'b00;  // ensures that the challenge has always lower value than public key (RSA requirement)

endmodule
