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

module LFSR_UIC #(
        parameter HALF_KEY_LENGTH = 16
    )(
        input clk,
        input rst,
        input generateNext,
        input [HALF_KEY_LENGTH-1:0] seed,
        output [HALF_KEY_LENGTH-1:0] out
    );

    wire feedback;
    reg [HALF_KEY_LENGTH-1:0] out_tmp;

    assign feedback = !(out_tmp[HALF_KEY_LENGTH-1] ^ out_tmp[HALF_KEY_LENGTH-3] ^ out_tmp[HALF_KEY_LENGTH-4] ^ out_tmp[10] ^ out_tmp[0]);

    always @ (posedge clk) begin
        if (!rst) begin
            out_tmp <= seed;
        end
        else begin
            if (generateNext) begin
                out_tmp <= {out_tmp[HALF_KEY_LENGTH-2 : 0], feedback};
            end
            else begin
                out_tmp <= out_tmp;
            end
        end
    end

    assign out[HALF_KEY_LENGTH-1] = 1'b1; // ensures big numbers, but also ensures that the public key is always larger than the challenge
    assign out[HALF_KEY_LENGTH-2 : 0] = {out_tmp[HALF_KEY_LENGTH-2:1], 1'b1}; // only odd numbers

endmodule
