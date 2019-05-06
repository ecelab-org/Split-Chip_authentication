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
// Design Name:    Montgomery constant calculator                                //
// Project Name:   Split-Chip_authentication                                     //
// Language:       Verilog                                                       //
//                                                                               //
// Description:    Calculates the montgomery contant (r_c).                      //
//                 r_c = r^2 mod n, where r = 2^(word length*(word count+1)) and //
//                 n is the modulus.                                             //
///////////////////////////////////////////////////////////////////////////////////

`include "__timescale.v"
`include "__parameters.vh"

module montgomery_r_c #(
        parameter MONTGOMERY_MODULE_KEY_LENGTH = 512
    )(
        input clk,
        input rst,
        input [MONTGOMERY_MODULE_KEY_LENGTH-1:0] MOD,
        input start,
        output [MONTGOMERY_MODULE_KEY_LENGTH-1:0] r_c,
        output reg ready
    );

    reg divStart;
    wire divComplete;

    reg [2:0] state, next_state;

    localparam STATE_IDLE = 3'd0;
    localparam STATE_CALC_R_C = 3'd1;
    localparam STATE_READY = 3'd2;

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
                    next_state = STATE_CALC_R_C;
                end
            end

            STATE_CALC_R_C: begin
                if (divComplete) begin
                    next_state = STATE_READY;
                end
            end

            STATE_READY: begin
                next_state = STATE_IDLE;
            end

            default: begin
                if (start) begin
                    next_state = STATE_CALC_R_C;
                end
            end
        endcase
    end

    always @(posedge clk) begin
        case (state)
            STATE_IDLE: begin
                ready <= 0;
                if (next_state == STATE_CALC_R_C) begin
                    divStart <= 1'b1;
                end
                else begin
                    divStart <= 0;
                end
            end

            STATE_CALC_R_C: begin
                ready <= 0;
                divStart <= 0;
            end

            STATE_READY: begin
                ready <= 1'b1;
                divStart <= 0;
            end

            default: begin
                ready <= 0;
                if (start) begin
                    divStart <= 1'b1;
                end
                else begin
                    divStart <= 0;
                end
            end
        endcase
    end

    localparam [1056:0] a = 1'b1 << 1056;

    div_seq #(.a_width(1057), .b_width(MONTGOMERY_MODULE_KEY_LENGTH), .num_cyc(1057)) div_seq (
        .clk(clk), 
        .rst_n(rst), 
        .hold(1'b0), 
        .start(divStart),
        .a(a),
        .b(MOD),
        .complete(divComplete),
        .divide_by_0(),
        .quotient(),
        .remainder(r_c)
    );

endmodule
