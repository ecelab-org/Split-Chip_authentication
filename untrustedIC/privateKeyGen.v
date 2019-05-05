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
// Design Name:    Private key generator                                         //
// Project Name:   Split-Chip_authentication                                     //
// Language:       Verilog                                                       //
//                                                                               //
// Description:    Calculates the modular multiplicative inverse of e(mod f(n)). //
//                 This is the RSA private key.                                  //
///////////////////////////////////////////////////////////////////////////////////

`include "__timescale.v"
`include "__parameters.vh"


module privateKeyGen #(
        parameter HALF_KEY_LENGTH = 16,
        parameter e_WIDTH = 3 // if e_WIDTH=17 then line 165 should be commented out
    )(
        input clk,
        input rst,
        input [2*HALF_KEY_LENGTH-1:0] f_n,
        input [e_WIDTH-1:0] e,
        input start,
        output reg ready,
        output [(2*HALF_KEY_LENGTH)+e_WIDTH:0] privateKey
    );

    wire [((2*HALF_KEY_LENGTH)+17)-1:0] f_n_times_X;
    reg [(2*HALF_KEY_LENGTH)+e_WIDTH:0] f_n_times_X_plus_one;   // has one more bit in case of overflow due to +1
    wire [2:0] modResult;
    reg multStart;
    wire multComplete;
    reg divStart;
    wire divComplete;
    reg [e_WIDTH-1:0] X;
    reg [e_WIDTH-1:0] tmpX;

    reg [2:0] state, next_state;

    localparam STATE_IDLE = 3'd0;
    localparam STATE_CALC_FN_TIMES_X = 3'd1;
    localparam STATE_DIV_BY_E = 3'd2;
    localparam STATE_READY = 3'd3;

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
                    next_state = STATE_CALC_FN_TIMES_X;
                end
            end

            STATE_CALC_FN_TIMES_X: begin
                if (multComplete) begin
                    next_state = STATE_DIV_BY_E;
                end
            end

            STATE_DIV_BY_E: begin
                if (divComplete) begin
                    if (modResult == 0) begin
                        next_state = STATE_READY;
                    end
                    else begin
                        next_state = STATE_CALC_FN_TIMES_X;
                    end
                end
            end

            STATE_READY: begin

            end

            default: begin
                if (start) begin
                    next_state = STATE_CALC_FN_TIMES_X;
                end
            end
        endcase
    end

    always @(posedge clk) begin
        case (state)
            STATE_IDLE: begin
                ready <= 0;
                divStart <= 0;
                tmpX <= 1'b1;
                X <= 1'b1;
                f_n_times_X_plus_one <= 0;
                if (start) begin
                    multStart <= 1'b1;
                end
                else begin
                    multStart <= 0;
                end
            end

            STATE_CALC_FN_TIMES_X: begin
                ready <= 0;
                multStart <= 0;
                X <= X;
                tmpX <= X;
                if (multComplete) begin
                    f_n_times_X_plus_one <= f_n_times_X[0 +: (2*HALF_KEY_LENGTH)+e_WIDTH] + 1;
                    divStart <= 1'b1;
                end
                else begin
                    f_n_times_X_plus_one <= 0;
                    divStart <= 0;
                end
            end

            STATE_DIV_BY_E: begin
                ready <= 0;
                divStart <= 0;
                tmpX <= tmpX;
                f_n_times_X_plus_one <= f_n_times_X_plus_one;
                if (next_state == STATE_CALC_FN_TIMES_X) begin
                    X <= tmpX + 1'b1;
                    multStart <= 1'b1;
                end
                else begin
                    X <= X;
                    multStart <= 0;
                end
            end

            STATE_READY: begin
                ready <= 1;
                multStart <= 0;
                divStart <= 0;
                X <= X;
                tmpX <= tmpX;
                f_n_times_X_plus_one <= f_n_times_X_plus_one;
            end

            default: begin
                ready <= 0;
                divStart <= 0;
                tmpX <= 1'b1;
                X <= 1'b1;
                f_n_times_X_plus_one <= 0;
                if (start) begin
                    multStart <= 1'b1;
                end
                else begin
                    multStart <= 0;
                end
            end
        endcase
    end

    wire [17-1:0] concatenatedX;
    assign concatenatedX[17-1:e_WIDTH] = {17-e_WIDTH{1'b0}};  //if e_WIDTH=17 then this line should be commented out
    assign concatenatedX[e_WIDTH-1:0] = X;

    CW_mult_seq #(.a_width(17), .b_width(2*HALF_KEY_LENGTH), .num_cyc(17)) CW_mult_seq (
        .clk(clk), 
        .rst_n(rst), 
        .hold(1'b0), 
        .start(multStart),
        .a(concatenatedX),
        .b(f_n),
        .complete(multComplete),
        .product(f_n_times_X)
    );

    CW_div_seq #(.a_width(((2*HALF_KEY_LENGTH)+e_WIDTH)+1), .b_width(e_WIDTH), .num_cyc(((2*HALF_KEY_LENGTH)+e_WIDTH)+1)) CW_div_seq (
        .clk(clk), 
        .rst_n(rst), 
        .hold(1'b0), 
        .start(divStart),
        .a(f_n_times_X_plus_one),
        .b(e),
        .complete(divComplete),
        .divide_by_0(),
        .quotient(privateKey),
        .remainder(modResult)
    );

endmodule