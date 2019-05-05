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
// Design Name:    Modular exponentiation FSM                                    //
// Project Name:   Split-Chip_authentication                                     //
// Language:       Verilog                                                       //
//                                                                               //
// Description:    Main FSM for modular exponentiation. Performs out = x^y mod m //
//                 In the trusted IC it is required only for encryption, thus    //
//                 'y' has a fixed width.                                        //
///////////////////////////////////////////////////////////////////////////////////

`include "__timescale.v"
`include "__parameters.vh"

module modExp_TIC #(
        parameter MONTGOMERY_MODULE_KEY_LENGTH = 512,
        parameter e_WIDTH = 3
    )(
        input clk,
        input rst,
        input [MONTGOMERY_MODULE_KEY_LENGTH-1:0] x,
        input [e_WIDTH-1:0] y,
        input [MONTGOMERY_MODULE_KEY_LENGTH-1:0] m,
        input start,
        output reg ready,
        output reg [MONTGOMERY_MODULE_KEY_LENGTH-1:0] out
    );

    reg [15:0] rsa_top_x, rsa_top_y, rsa_top_m, rsa_top_r_c;
    wire [MONTGOMERY_MODULE_KEY_LENGTH-1:0] r_c_out_sig;
    wire [15:0] rsa_top_s;
    wire r_c_ready_sig, rsa_top__valid_out_sig;
    reg start_in_sig, valid_in_sig, load_done, unload_done, montgomery_r_c_rst;
    reg [31:0] load_unload_counter;
    wire [4:0] y_size;

    assign y_size = e_WIDTH;

    rsa_top rsa_top (
        .clk(clk), 
        .reset(~rst), 
        .valid_in(valid_in_sig),
        .start_in(start_in_sig),
        .x(rsa_top_x),
        .y(rsa_top_y),
        .m(rsa_top_m),
        .r_c(rsa_top_r_c),
        .s(rsa_top_s),
        .valid_out(rsa_top__valid_out_sig),
        .bit_size({{11{1'b0}},y_size})
    );

    montgomery_r_c #(.MONTGOMERY_MODULE_KEY_LENGTH(MONTGOMERY_MODULE_KEY_LENGTH)) montgomery_r_c (
        .clk(clk), 
        .rst(rst), 
        .MOD(m),
        .start(start_in_sig),
        .r_c(r_c_out_sig),
        .ready(r_c_ready_sig)
    );

    reg [2:0] state, next_state;
    localparam STATE_IDLE = 3'd0;
    localparam STATE_CALCULATE_R_C = 3'd1;
    localparam STATE_LOAD_VALUES = 3'd2;
    localparam STATE_CALCULATE_OUT = 3'd3;
    localparam STATE_UNLOAD_VALUES = 3'd4;
    localparam STATE_READY = 3'd5;

    always @(posedge clk) begin
        if (rst == 0) begin
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
                if ( start ) begin
                    next_state = STATE_CALCULATE_R_C;
                end
            end

            STATE_CALCULATE_R_C: begin
                if ( r_c_ready_sig ) begin
                    next_state = STATE_LOAD_VALUES;
                end
            end

            STATE_LOAD_VALUES: begin
                if ( load_done ) begin
                    next_state = STATE_CALCULATE_OUT;
                end
            end

            STATE_CALCULATE_OUT: begin
                next_state = STATE_UNLOAD_VALUES;
            end

            STATE_UNLOAD_VALUES: begin
                if ( unload_done ) begin
                    next_state = STATE_READY;
                end
            end

            STATE_READY: begin
                next_state = STATE_IDLE;
            end

            default: begin
                if ( start ) begin
                    next_state = STATE_CALCULATE_R_C;
                end
            end
        endcase
    end

    always @(posedge clk) begin

        case (state)
            STATE_IDLE: begin
                ready <= 0;
                valid_in_sig <= 0;
                out <= out;
                load_done <= 0;
                unload_done <= 0;
                load_unload_counter <= 0;
                rsa_top_x <= 0;
                rsa_top_y <= 0;
                rsa_top_r_c <= 0;
                rsa_top_m <= m[15:0];

                if (start) begin
                    start_in_sig <= 1'b1;
                end
                else begin
                    start_in_sig <= 0;
                end
            end

            STATE_CALCULATE_R_C: begin
                start_in_sig <= 1'b0;
                rsa_top_m <= rsa_top_m;
            end

            STATE_LOAD_VALUES: begin
                valid_in_sig <= 1'b1;
                if (next_state == STATE_CALCULATE_OUT) begin
                    valid_in_sig <= 0;
                end

                if (load_unload_counter == 31) begin
                    load_done <= 1'b1;
                    load_unload_counter <= load_unload_counter;
                end
                else begin
                    load_done <= 0;
                    load_unload_counter <= load_unload_counter+1'b1;
                end

                rsa_top_x <= x[(load_unload_counter*16) +: 16];
                rsa_top_y <= y[(load_unload_counter*16) +: 16];
                rsa_top_m <= m[(load_unload_counter*16) +: 16];
                rsa_top_r_c <= r_c_out_sig[(load_unload_counter*16) +: 16];
            end

            STATE_CALCULATE_OUT: begin
                load_done <= 0;
                load_unload_counter <= 0;
            end

            STATE_UNLOAD_VALUES: begin
                if ( rsa_top__valid_out_sig ) begin
                    out[(load_unload_counter*16) +: 16] <= rsa_top_s;
                    if (load_unload_counter == 31) begin
                        unload_done <= 1'b1;
                        load_unload_counter <= 0;
                    end
                    else begin
                        unload_done <= 0;
                        load_unload_counter <= load_unload_counter+1'b1;
                    end
                end
            end

            STATE_READY: begin
                unload_done <= 0;
                ready <= 1'b1;
            end

            default: begin
                ready <= 0;
                valid_in_sig <= 0;
                out <= 0;
                load_done <= 0;
                unload_done <= 0;
                load_unload_counter <= 0;
                rsa_top_x <= 0;
                rsa_top_y <= 0;
                rsa_top_r_c <= 0;

                if (start) begin
                    start_in_sig <= 1'b1;
                    rsa_top_m <= m[15:0];
                end
                else begin
                    start_in_sig <= 0;
                    rsa_top_m <= 0;
                end
            end
        endcase
    end

endmodule