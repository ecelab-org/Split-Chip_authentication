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
// Design Name:    FIFO buffer                                                   //
// Project Name:   Split-Chip_authentication                                     //
// Language:       Verilog                                                       //
//                                                                               //
// Description:    FIFO buffer for the modular exponentiation unit.              //
///////////////////////////////////////////////////////////////////////////////////

`include "__timescale.v"
`include "__parameters.vh"


module Fifo_256_feedback #(
        parameter DATA_WIDTH = 49,
        parameter ADDR_WIDTH = 6
    )(
        input clk,
        input rst,
        input [DATA_WIDTH-1:0] din,
        input wr_en,
        input rd_en,
        output [DATA_WIDTH-1:0] dout,
        output full,
        output empty
    );

    localparam DEPTH = (1 << ADDR_WIDTH);

    wire [DATA_WIDTH-1:0] mem_out;
    reg rd_en_sig;
    reg [ADDR_WIDTH-1:0] wr_pointer;
    reg [ADDR_WIDTH-1:0] rd_pointer;
    reg [ADDR_WIDTH :0] counter;

    assign full = (counter == DEPTH) ? 1'b1 : 1'b0;
    assign empty = (counter == 0) ? 1'b1 : 1'b0;
    assign dout = (rd_en_sig) ? mem_out : 1'b0;

    always @ (posedge clk or posedge rst) begin : write_pointer
        if (rst) begin
            wr_pointer <= 0;
        end 

        else begin
            if (wr_en && (counter != DEPTH)) begin
                wr_pointer <= wr_pointer + 1;
            end

            else begin
                wr_pointer <= wr_pointer;
            end
        end
    end

    always @ (posedge clk or posedge rst) begin : read_pointer
        if (rst) begin
            rd_en_sig <= 0;
            rd_pointer <= 0;
        end 

        else begin 
            if (rd_en && (counter != 0)) begin
                rd_en_sig <= 1'b1;
                rd_pointer <= rd_pointer +1;
            end

            else begin
                rd_en_sig <= 0;
                rd_pointer <= rd_pointer;
            end
        end
    end

    always @ (posedge clk or posedge rst) begin : STATUS_COUNTER
        if (rst) begin
            counter <= 0;
        end 

        else begin
            if (rd_en && !wr_en && (counter != 0)) begin // only read
                counter <= counter - 1;
            end 

            else if (wr_en && !rd_en && (counter != DEPTH)) begin // only write
                counter <= counter + 1;
            end

            else begin
                counter <= counter;
            end
        end
    end 

    wire [DATA_WIDTH-1:0] _unconnected;

    ARM_sram_49x64 ARM_sram_49x64 (
        .QA(mem_out), 
        .QB(_unconnected), 
        .CLK(clk), 
        .CENA(~rd_en), // active low
        .GWENA(1'b1), // active low
        .AA(rd_pointer), 
        .DA({DATA_WIDTH{1'b0}}), 
        .CENB(full), // active low
        .GWENB(~wr_en), // active low
        .AB(wr_pointer), 
        .DB(din), 
        .STOV(1'b0), 
        .STOVAB(1'b0), 
        .EMA(3'b0), 
        .EMAP(1'b0), 
        .EMAW(2'b0), 
        .EMAS(1'b0), 
        .RET1N(1'b1) // active low
    );

endmodule