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
// Design Name:    SPI-custom slave                                             //
// Project Name:   Split-Chip_authentication                                     //
// Language:       Verilog                                                       //
//                                                                               //
// Description:    This is the slave module of a custom SPI interface,           //
//                 achieving full duplex synchronous serial communication using  //
//                 only 3 wires. In contrast to typical SPI implementation, the  //
//                 slave (this module) can send any amount of data to its paired //
//                 master at any time — i.e., no predefined slave-to-master time //
//                 windows, or extra wires are needed.                           //
///////////////////////////////////////////////////////////////////////////////////

`include "__timescale.v"
`include "__parameters.vh"

module SPISlave #(
        parameter KEY_LENGTH = 32
    )(
        input clk,
        input rst,
        input [KEY_LENGTH-1:0] dataToSend,
        input send,
        input MOSI,
        input SCLK,
        output reg MISO,
        output [KEY_LENGTH-1:0] dataReceived,
        output reg dataReceived_ready
    );

    reg [KEY_LENGTH:0] dataToSend_buf;
    wire [KEY_LENGTH:0] dataReceived_internal;
    reg send_buf, send_delayed, send_trigger, sending;
    integer SCLK_counter_receive, SCLK_counter_send;

    assign dataReceived = dataReceived_internal[KEY_LENGTH-1:0];

    // Shift register for capturing input
        wire shift_in;

        reg [KEY_LENGTH:0] data;
        wire [KEY_LENGTH:0] data_next;

        always @(posedge rst) begin
            SCLK_counter_receive <= 0;
            dataReceived_ready <= 0;
        end

        always @(posedge SCLK) begin
            if (!rst) begin
                data <= 0;
            end
            else begin
                data <= data_next;
                if (SCLK_counter_receive == KEY_LENGTH) begin
                    SCLK_counter_receive <= 0;
                    dataReceived_ready <= 1'b1;
                end
                else begin
                    SCLK_counter_receive <= SCLK_counter_receive + 1;
                    dataReceived_ready <= 1'b0;
                end
            end
        end	

        assign shift_in = MOSI;
        assign dataReceived_internal = data;

        assign data_next = {shift_in, data[KEY_LENGTH:1]};
    // End of shift register

    always @(posedge clk) begin
        send_buf <= send;
        send_delayed <= send_buf;
        if (send_buf && !send_delayed) begin  // posedge triggered
            send_trigger <= 1'b1;
        end
        else begin
            send_trigger <= 0;
       end
    end

    always @(posedge rst) begin
        send_buf <= 0;
        send_delayed <= 0;
        dataToSend_buf <= 0;
        MISO <= 0;
        SCLK_counter_send <= 0;
        sending <= 0;
    end

    always @(posedge send_trigger or negedge SCLK) begin
        if (send_trigger) begin
            if (!sending) begin
                MISO <= 1'b1;
                dataToSend_buf <= dataToSend;
                SCLK_counter_send <= 0;
                sending <= 1'b1;
            end
            else begin
                MISO <= MISO;
                dataToSend_buf <= dataToSend_buf;
                SCLK_counter_send <= SCLK_counter_send;
                sending <= 1'b1;
            end
        end
        else begin
            if (SCLK_counter_send == KEY_LENGTH) begin
                SCLK_counter_send <= 0;
                sending <= 0;
                MISO <= 0;
            end
            else begin
                SCLK_counter_send <= SCLK_counter_send + 1;
                sending <= sending;
                MISO <= dataToSend_buf[SCLK_counter_send];
            end
            dataToSend_buf <= dataToSend_buf;
        end
    end

endmodule