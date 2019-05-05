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
// Design Name:    Noise filtering module                                        //
// Project Name:   Split-Chip_authentication                                     //
// Language:       Verilog                                                       //
//                                                                               //
// Description:    Performs filtering of a noisy input 'in', based on            //
//                 quantization and exclusion. Let Z as the outcome of the       //
//                 "filtered" input X (X->Z). If Y is an altered version of X,   //
//                 within a defined range of average "bit-flips", Z will         //
//                 remain the same (Y->Z).                                       //
///////////////////////////////////////////////////////////////////////////////////

`include "__timescale.v"
`include "__parameters.vh"


module noiseFilter #(
    parameter 
        HALF_KEY_LENGTH = 16
    ) (
        input clk,
        input rst,
        input [(16*HALF_KEY_LENGTH)-1 : 0] in,
        output reg [HALF_KEY_LENGTH-1 : 0] out,
        output reg ready
    );

    reg [HALF_KEY_LENGTH-1 : 0] validRegions;
    reg [(5*HALF_KEY_LENGTH)-1 : 0] quantized;

    reg [2:0] state, next_state;

    localparam STATE_OFF = 3'd0;
    localparam STATE_QUANTIZE = 3'd1;
    localparam STATE_MARK_VALID = 3'd2;
    localparam STATE_FINAL = 3'd3;
    localparam STATE_READY = 3'd4;

    localparam EXCLUSION_ZONE_WIDTH = 4;
    localparam integer HALF_EXCLUSION_ZONE_WIDTH = EXCLUSION_ZONE_WIDTH * 0.5;

    integer i;

    always @(posedge clk) begin
        if (!rst) begin
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
                next_state = STATE_QUANTIZE;
            end

            STATE_QUANTIZE: begin
                next_state = STATE_MARK_VALID;
            end

            STATE_MARK_VALID: begin
                next_state = STATE_FINAL;
            end

            STATE_FINAL: begin
                next_state = STATE_READY;
            end

            STATE_READY: begin
                next_state = STATE_READY;
            end

            default: begin
                next_state = STATE_QUANTIZE;
            end
        endcase
        
    end

    always @(*) begin

        case (state)
            STATE_OFF: begin
                quantized = 0;
                validRegions = 0;
                out = 0;
                ready = 0;
            end

            STATE_QUANTIZE: begin
                for (i=0; i<HALF_KEY_LENGTH; i=i+1) begin
                    quantized[(i*5) +: 5] = in[(i*16)+0] + in[(i*16)+1] + in[(i*16)+2] + in[(i*16)+3] + in[(i*16)+4]
                                                   + in[(i*16)+5] + in[(i*16)+6] + in[(i*16)+7] + in[(i*16)+8] + in[(i*16)+9]
                                                   + in[(i*16)+10] + in[(i*16)+11] + in[(i*16)+12] + in[(i*16)+13] + in[(i*16)+14]
                                                   + in[(i*16)+15];
                end
                validRegions = 0;
                out = 0;
                ready = 0;
            end

            STATE_MARK_VALID: begin
                quantized = quantized;
                for (i=0; i<HALF_KEY_LENGTH; i=i+1) begin
                    if ( (quantized[(i*5) +: 5] < 8-(HALF_EXCLUSION_ZONE_WIDTH-1)) || (quantized[(i*5) +: 5] > 8+(HALF_EXCLUSION_ZONE_WIDTH-1)) ) begin
                       validRegions[i] = 1'b1; 
                    end
                    else begin
                       validRegions[i] = 1'b0; 
                    end

                    if ( quantized[(i*5) +: 5] < 8 ) begin
                       out[i] = 1'b0; 
                    end
                    else begin
                       out[i] = 1'b1; 
                    end
                end
                ready = 0;
            end

            STATE_FINAL: begin
                quantized = quantized;
                validRegions = validRegions;
                out = out & validRegions;
                ready = 0;
            end

            STATE_READY: begin
                quantized = quantized;
                validRegions = validRegions;
                out = out;
                ready = 1'b1;
            end

            default: begin
                quantized = 0;
                validRegions = 0;
                out = 0;
                ready = 0;
            end
        endcase
        
    end

endmodule