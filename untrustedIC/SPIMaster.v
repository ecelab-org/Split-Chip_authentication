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
// Design Name:    SPI-custom master                                             //
// Project Name:   Split-Chip_authentication                                     //
// Language:       Verilog                                                       //
//                                                                               //
// Description:    This is the master module of a custom SPI interface,          //
//                 achieving full duplex synchronous serial communication using  //
//                 only 3 wires. In contrast to typical SPI implementation, the  //
//                 paired slave of this module can send any amount of data to    //
//                 the master (this module) at any time — i.e., no predefined    //
//                 slave-to-master time windows, or extra wires are needed.      //
///////////////////////////////////////////////////////////////////////////////////

`include "__timescale.v"
`include "__parameters.vh"


module SPIMaster #(
        parameter KEY_LENGTH = 32,
        parameter SCLK_PERIOD_AS_CLK_MULTIPLE = 10
    )(
        input clk,
        input rst,
        input [KEY_LENGTH-1:0] dataToSend,
        input start,
        input MISO,
        output reg SCLK,
        output reg MOSI,
        output [KEY_LENGTH-1:0] dataReceived
    );

    localparam integer SCLK_SEMI_PERIOD = 0.5 * SCLK_PERIOD_AS_CLK_MULTIPLE;

    reg start_buf, start_delayed, data_interval, done; // done signal for future use
    wire [KEY_LENGTH:0] dataToSend_internal, dataReceived_internal; // wires extended by 1 bit and msb set to 0 in to facilitate correct communication with 
                                                                    // slave. Slave expects one extra SCLK pulse after the transmission of the last bit.
    integer data_counter;
    integer clk_counter;

    assign dataToSend_internal = {1'b0, dataToSend[KEY_LENGTH-1:0]};
    assign dataReceived = dataReceived_internal[KEY_LENGTH-1:0];

    // Shift register for capturing input
        wire shift_in;

        reg [KEY_LENGTH:0] data;
        wire [KEY_LENGTH:0] data_next;

        always @(posedge SCLK) begin
            if (!rst) begin
                data <= 0;
            end
            else begin
                data <= data_next;
            end
        end    

        assign shift_in = MISO;
        assign dataReceived_internal = data;

        assign data_next = {shift_in, data[KEY_LENGTH:1]};
    // End of shift register

    always @(posedge clk) begin
        if (!rst) begin
            start_buf <= 0;
            start_delayed <= 0;
        end
        else begin
            start_buf <= start;
            start_delayed <= start_buf;
        end
    end

    reg state, next_state;
    localparam STATE_IDLE = 1'd0;
    localparam STATE_SEND_RECEIVE = 1'd1;

    always @(posedge clk) begin
        if (!rst) begin
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
                if (start_buf && !start_delayed) begin  // posedge triggered
                    next_state = STATE_SEND_RECEIVE;
                end
            end

            STATE_SEND_RECEIVE: begin
                if (data_counter == KEY_LENGTH+1 && clk_counter == SCLK_SEMI_PERIOD-1) begin    // "KEY_LENGTH+1" because slave expects one 
                                                                                                // extra SCLK pulse after the transmission of 
                                                                                                // the last bit.
                    next_state = STATE_IDLE;
                end
            end

            default: begin
                if (start_buf && !start_delayed) begin  // posedge triggered
                    next_state = STATE_SEND_RECEIVE;
                end
            end
        endcase
    end

    always @(posedge clk) begin

        case (state)
            STATE_IDLE: begin
                done <= 0;
                clk_counter <= 0;
                SCLK <= 1'b1;
                MOSI <= MOSI;
                data_counter <= 0;
                data_interval <= 0;
            end

            STATE_SEND_RECEIVE: begin
                if (clk_counter == SCLK_SEMI_PERIOD-1) begin
                    SCLK <= ~SCLK;
                    data_interval <= ~data_interval;
                    clk_counter <= 0;
                    if (!data_interval) begin
                        MOSI <= dataToSend_internal[data_counter];
                        data_counter <= data_counter + 1'b1;
                    end
                    else begin
                        MOSI <= MOSI;
                        data_counter <= data_counter;
                    end
                end
                else begin
                    SCLK <= SCLK;
                    data_interval <= data_interval;
                    clk_counter <= clk_counter + 1'b1;
                    MOSI <= MOSI;
                    data_counter <= data_counter;
                end

                if (next_state == STATE_IDLE) begin
                    done <= 1'b1;
                end
                else begin
                    done <= 0;
                end
            end

            default: begin
                done <= 0;
                clk_counter <= 0;
                SCLK <= 1'b1;
                MOSI <= 0;
                data_counter <= 0;
                data_interval <= 0;
            end
        endcase
    end

endmodule