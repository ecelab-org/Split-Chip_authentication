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
// Design Name:    Primality tester                                              //
// Project Name:   Split-Chip_authentication                                     //
// Language:       Verilog                                                       //
//                                                                               //
// Description:    Tests if a given input number is a prime number. The test is  //
//                 based on the Miller-Rabin algorithm. The upper probability    //
//                 bound of error is defined by the number of repetitions and    //
//                 can be modified by adding or removing test states.            //
///////////////////////////////////////////////////////////////////////////////////

`include "__timescale.v"
`include "__parameters.vh"


module primalityTest #(
        parameter KEY_LENGTH = 32,
        parameter integer HALF_KEY_LENGTH = 0.5 * KEY_LENGTH,
        parameter e_WIDTH = 3
    )(
        input clk,
        input rst,
        input [HALF_KEY_LENGTH-1:0] in,
        input start,
        input modExp_ready,
        input [511:0] modExp_out,
        output reg modExp_rst,
        output [511:0] modExp_x,
        output [511+e_WIDTH:0] modExp_y,
        output [9:0] modExp_y_size,
        output [511:0] modExp_m,
        output reg modExp_start,
        output reg done,
        output reg isPrime
    );

    // Miller and Rabin algorithm
    reg k; //we set k=1 so it can be ignored (it is not used in calculations)
    reg [7:0] a;
    reg [HALF_KEY_LENGTH-1:0] q;
    reg [HALF_KEY_LENGTH-1:0] in_minus1;
    reg qIsOdd; //intermediate signal used only for algorithm debugging (not needed in implementation)

    reg [3:0] count;
    reg [9:0] isPrime_tmp;
    wire [HALF_KEY_LENGTH-1 : 0] MRResult; // Miller-Rabin result: register that will take the result of a^q mod in

    localparam [9:0] MODEXP_Y_SIZE = HALF_KEY_LENGTH;

    assign modExp_x = {{504{1'b0}},a};
    assign modExp_y = {{511+e_WIDTH+1-HALF_KEY_LENGTH{1'b0}},q};
    assign modExp_y_size = MODEXP_Y_SIZE;
    assign modExp_m = {{512-HALF_KEY_LENGTH{1'b0}},in};
    assign MRResult = modExp_out[HALF_KEY_LENGTH-1:0];

    always @* begin
        in_minus1 = in - 1;
        q = in_minus1 >> 1;

        if (q[0] == 0) begin
            qIsOdd = 1'b1;
        end
        else begin
            qIsOdd = 1'b0;
        end
    end

    reg [3:0] state, next_state;
    localparam STATE_IDLE = 4'd0;
    localparam STATE_TEST01 = 4'd1;
    localparam STATE_TEST02 = 4'd2;
    localparam STATE_TEST03 = 4'd3;
    localparam STATE_TEST04 = 4'd4;
    localparam STATE_TEST05 = 4'd5;
    localparam STATE_TEST06 = 4'd6;
    localparam STATE_TEST07 = 4'd7;
    localparam STATE_TEST08 = 4'd8;
    localparam STATE_TEST09 = 4'd9;
    localparam STATE_TEST10 = 4'd10;
    localparam STATE_SUCCESS = 4'd11;

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
                    next_state = STATE_TEST01;
                end
            end

            STATE_TEST01: begin
                if ( modExp_ready ) begin
                    if (MRResult==1 || MRResult==in_minus1) begin
                        next_state = STATE_TEST02;
                    end
                    else begin
                        next_state = STATE_IDLE;
                    end
                end
            end

            STATE_TEST02: begin
                if ( modExp_ready ) begin
                    if (MRResult==1 || MRResult==in_minus1) begin
                        next_state = STATE_TEST03;
                    end
                    else begin
                        next_state = STATE_IDLE;
                    end
                end
            end

            STATE_TEST03: begin
                if ( modExp_ready ) begin
                    if (MRResult==1 || MRResult==in_minus1) begin
                        next_state = STATE_TEST04;
                    end
                    else begin
                        next_state = STATE_IDLE;
                    end
                end
            end

            STATE_TEST04: begin
                if ( modExp_ready ) begin
                    if (MRResult==1 || MRResult==in_minus1) begin
                        next_state = STATE_TEST05;
                    end
                    else begin
                        next_state = STATE_IDLE;
                    end
                end
            end

            STATE_TEST05: begin
                if ( modExp_ready ) begin
                    if (MRResult==1 || MRResult==in_minus1) begin
                        next_state = STATE_TEST06;
                    end
                    else begin
                        next_state = STATE_IDLE;
                    end
                end
            end

            STATE_TEST06: begin
                if ( modExp_ready ) begin
                    if (MRResult==1 || MRResult==in_minus1) begin
                        next_state = STATE_TEST07;
                    end
                    else begin
                        next_state = STATE_IDLE;
                    end
                end
            end

            STATE_TEST07: begin
                if ( modExp_ready ) begin
                    if (MRResult==1 || MRResult==in_minus1) begin
                        next_state = STATE_TEST08;
                    end
                    else begin
                        next_state = STATE_IDLE;
                    end
                end
            end

            STATE_TEST08: begin
                if ( modExp_ready ) begin
                    if (MRResult==1 || MRResult==in_minus1) begin
                        next_state = STATE_TEST09;
                    end
                    else begin
                        next_state = STATE_IDLE;
                    end
                end
            end

            STATE_TEST09: begin
                if ( modExp_ready ) begin
                    if (MRResult==1 || MRResult==in_minus1) begin
                        next_state = STATE_TEST10;
                    end
                    else begin
                        next_state = STATE_IDLE;
                    end
                end
            end

            STATE_TEST10: begin
                if ( modExp_ready ) begin
                    if (MRResult==1 || MRResult==in_minus1) begin
                        next_state = STATE_SUCCESS;
                    end
                    else begin
                        next_state = STATE_IDLE;
                    end
                end
            end

            STATE_SUCCESS: begin
                next_state = STATE_IDLE;
            end

            default: begin
                if ( start ) begin
                    next_state = STATE_TEST01;
                end
            end
        endcase
    end


    always @(posedge clk) begin

        case (state)
            STATE_IDLE: begin
                a <= 8'h40;
                done <= 0;
                isPrime <= 0;
                modExp_start <= 0;
                modExp_rst <= 0;

                if (next_state == STATE_TEST01) begin
                    modExp_start <= 1'b1;
                    modExp_rst <= 1'b1;
                end
            end

            STATE_TEST01: begin
                a <= 8'h40;
                modExp_start <= 0;

                if (next_state == STATE_IDLE) begin
                    done <= 1'b1;
                end
                else if (next_state == STATE_TEST02) begin
                    done <= 0;
                    modExp_start <= 1'b1;
                end
                else begin
                    done <= 0;
                end
            end

            STATE_TEST02: begin
                a <= 8'h73;
                modExp_start <= 0;

                if (next_state == STATE_IDLE) begin
                    done <= 1'b1;
                end
                else if (next_state == STATE_TEST03) begin
                    done <= 0;
                    modExp_start <= 1'b1;
                end
                else begin
                    done <= 0;
                end
            end

            STATE_TEST03: begin
                a <= 8'h6c;
                modExp_start <= 0;

                if (next_state == STATE_IDLE) begin
                    done <= 1'b1;
                end
                else if (next_state == STATE_TEST04) begin
                    done <= 0;
                    modExp_start <= 1'b1;
                end
                else begin
                    done <= 0;
                end
            end

            STATE_TEST04: begin
                a <= 8'h57;
                modExp_start <= 0;

                if (next_state == STATE_IDLE) begin
                    done <= 1'b1;
                end
                else if (next_state == STATE_TEST05) begin
                    done <= 0;
                    modExp_start <= 1'b1;
                end
                else begin
                    done <= 0;
                end
            end

            STATE_TEST05: begin
                a <= 8'hcd;
                modExp_start <= 0;

                if (next_state == STATE_IDLE) begin
                    done <= 1'b1;
                end
                else if (next_state == STATE_TEST06) begin
                    done <= 0;
                    modExp_start <= 1'b1;
                end
                else begin
                    done <= 0;
                end
            end

            STATE_TEST06: begin
                a <= 8'hdc;
                modExp_start <= 0;

                if (next_state == STATE_IDLE) begin
                    done <= 1'b1;
                end
                else if (next_state == STATE_TEST07) begin
                    done <= 0;
                    modExp_start <= 1'b1;
                end
                else begin
                    done <= 0;
                end
            end

            STATE_TEST07: begin
                a <= 8'h15;
                modExp_start <= 0;

                if (next_state == STATE_IDLE) begin
                    done <= 1'b1;
                end
                else if (next_state == STATE_TEST08) begin
                    done <= 0;
                    modExp_start <= 1'b1;
                end
                else begin
                    done <= 0;
                end
            end

            STATE_TEST08: begin
                a <= 8'h4e;
                modExp_start <= 0;

                if (next_state == STATE_IDLE) begin
                    done <= 1'b1;
                end
                else if (next_state == STATE_TEST09) begin
                    done <= 0;
                    modExp_start <= 1'b1;
                end
                else begin
                    done <= 0;
                end
            end

            STATE_TEST09: begin
                a <= 8'hed;
                modExp_start <= 0;

                if (next_state == STATE_IDLE) begin
                    done <= 1'b1;
                end
                else if (next_state == STATE_TEST10) begin
                    done <= 0;
                    modExp_start <= 1'b1;
                end
                else begin
                    done <= 0;
                end
            end

            STATE_TEST10: begin
                a <= 8'hdb;
                modExp_start <= 0;

                if (next_state == STATE_IDLE) begin
                    done <= 1'b1;
                end
                else begin
                    done <= 0;
                end
            end

            STATE_SUCCESS: begin
                done <= 1'b1;
                isPrime <= 1'b1;
                modExp_rst <= 0;
            end

            default: begin
                a <= 8'h40;
                done <= 0;
                isPrime <= 0;
                modExp_start <= 0;
                modExp_rst <= 0;

                if (next_state == STATE_TEST01) begin
                    modExp_start <= 1'b1;
                    modExp_rst <= 1'b1;
                end
            end
        endcase
    end

    `ifdef J_SIMULATION
        reg [1024:0] clk_counter, numbersTested_counter;
        integer output_file1, numbersTested_pass_counter;
        initial begin
            clk_counter = 0;
            numbersTested_counter = 0;
            numbersTested_pass_counter = 0;
        end

        always @(posedge clk) begin
            clk_counter = clk_counter + 1'd1;
        end

        always @(posedge done) begin
            numbersTested_counter = numbersTested_counter + 1'd1;
            if (isPrime) begin
                numbersTested_pass_counter = numbersTested_pass_counter + 1'd1;
                output_file1 = $fopen("numbersTested_pass.txt","a");
                $fwrite(output_file1, "numbers tested: %0d\n", numbersTested_counter);
                $fwrite(output_file1, "pass:           %0d\n", numbersTested_pass_counter);
                $fwrite(output_file1, "clock counter:  %0d\n\n", clk_counter);
                $fclose(output_file1);
            end
        end
    `endif


endmodule
