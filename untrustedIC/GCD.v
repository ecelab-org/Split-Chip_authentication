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
// Design Name:    Greatest Common Divisor unit                                  //
// Project Name:   Split-Chip_authentication                                     //
// Language:       Verilog                                                       //
//                                                                               //
// Description:    Sub-module for the crypto key pair generator. Calculates the  //
//                 GCD (f(n), e), which should equal to 1 for a valid RSA key    //
//                 pair.                                                         //
///////////////////////////////////////////////////////////////////////////////////

`include "__timescale.v"
`include "__parameters.vh"


module GCD #(
        parameter HALF_KEY_LENGTH = 16,
        parameter e_WIDTH = 3
    )(
        input clk,
        input rst,
        input [HALF_KEY_LENGTH-1:0] p1,
        input [HALF_KEY_LENGTH-1:0] p2,
        input [e_WIDTH-1:0] e,
        input start,
        output reg areValid,
        output [2*HALF_KEY_LENGTH-1:0] MOD,
        output [2*HALF_KEY_LENGTH-1:0] f_n,
        output reg ready
    );

    wire [2*HALF_KEY_LENGTH-1:0] MOD_sig;
    reg [2*HALF_KEY_LENGTH-1:0] f_n_sig;
    wire [2:0] modResult;
    reg multStart;
    wire multComplete;
    reg divStart;
    wire divComplete;

    assign MOD = MOD_sig; 
    assign f_n = f_n_sig; 

    reg [2:0] state, next_state;

    localparam STATE_IDLE = 3'd0;
    localparam STATE_CALC_MOD = 3'd1;
    localparam STATE_CALC_FN = 3'd2;
    localparam STATE_MODULUS = 3'd3;
    localparam STATE_READY = 3'd4;

    always @(posedge clk) begin
        if (rst == 1'b0) begin
            state <= STATE_IDLE;
        end
        else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;

        case (state)
            STATE_IDLE: begin
                if (start) begin
                    next_state = STATE_CALC_MOD;
                end
            end

            STATE_CALC_MOD: begin
                if (multComplete) begin
                    next_state = STATE_CALC_FN;
                end
            end

            STATE_CALC_FN: begin
                next_state = STATE_MODULUS;
            end

            STATE_MODULUS: begin
                if (divComplete) begin
                    next_state = STATE_READY;
                end
            end

            STATE_READY: begin
                
            end

            default: begin
                if (start) begin
                    next_state = STATE_CALC_MOD;
                end
            end
        endcase
    end

    always @(posedge clk) begin
        case (state)
            STATE_IDLE: begin
                ready <= 0;
                areValid <= 0;
                divStart <= 0;
                f_n_sig <= 0;
                if (start) begin
                    multStart <= 1'b1;
                end
                else begin
                    multStart <= 0;
                end
            end

            STATE_CALC_MOD: begin
                ready <= 0;
                areValid <= 0;
                multStart <= 0;
                divStart <= 0;
                f_n_sig <= 0;
            end

            STATE_CALC_FN: begin
                ready <= 0;
                areValid <= 0;
                multStart <= 0;
                divStart <= 1'b1;
                f_n_sig <= MOD_sig - p1 - p2 + 1;
            end

            STATE_MODULUS: begin
                ready <= 0;
                areValid <= 0;
                multStart <= 0;
                divStart <= 0;
                f_n_sig <= f_n_sig;
            end

            STATE_READY: begin
                ready <= 1'b1;
                multStart <= 0;
                divStart <= 0;
                f_n_sig <= f_n_sig;
                if (modResult != 0) begin
                    areValid <= 1;
                end
                else begin
                    areValid <= 0;
                end
            end

            default: begin
                ready <= 0;
                areValid <= 0;
                divStart <= 0;
                f_n_sig <= 0;
                if (start) begin
                    multStart <= 1'b1;
                end
                else begin
                    multStart <= 0;
                end
            end
        endcase
    end

    CW_mult_seq #(.a_width(HALF_KEY_LENGTH), .b_width(HALF_KEY_LENGTH), .num_cyc(HALF_KEY_LENGTH)) CW_mult_seq (
        .clk(clk), 
        .rst_n(rst), 
        .hold(1'b0), 
        .start(multStart),
        .a(p1),
        .b(p2),
        .complete(multComplete),
        .product(MOD_sig)
    );

    CW_div_seq #(.a_width(2*HALF_KEY_LENGTH), .b_width(e_WIDTH), .num_cyc(2*HALF_KEY_LENGTH)) CW_div_seq (
        .clk(clk), 
        .rst_n(rst), 
        .hold(1'b0), 
        .start(divStart),
        .a(f_n_sig),
        .b(e),
        .complete(divComplete),
        .divide_by_0(),
        .quotient(),
        .remainder(modResult)
    );

endmodule