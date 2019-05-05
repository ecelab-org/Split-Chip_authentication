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
// Design Name:    Memory wrapper                                                //
// Project Name:   Split-Chip_authentication                                     //
// Language:       Verilog                                                       //
//                                                                               //
// Description:    Wrapper for one of the memories of the modular exponentiation //
//                 unit.                                                         //
///////////////////////////////////////////////////////////////////////////////////

`include "__timescale.v"
`include "__parameters.vh"


module Mem_b (
        input clka,
        input wea,
        input [5:0] addra,
        input [15:0] dina,
        output [15:0] douta
    );

    wire wea_sig;

    ARM_sram_16x64 Mem_b_wrapper (
        .QA(douta), 
        .QB(), 
        .CLK(clka), 
        .CENA(1'b0), // active low
        .GWENA(wea_sig), 
        .AA(addra), 
        .DA(dina), 
        .CENB(1'b1), // active low
        .GWENB(1'b1), // active low
        .AB(6'b0), 
        .DB(16'b0), 
        .STOV(1'b0), 
        .STOVAB(1'b0), 
        .EMA(3'b0), 
        .EMAP(1'b0), 
        .EMAW(2'b0), 
        .EMAS(1'b0), 
        .RET1N(1'b1) // active low
    );


    assign wea_sig = ~wea;


endmodule