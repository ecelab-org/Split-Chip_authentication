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
// Design Name:    Top level module                                              //
// Project Name:   Split-Chip_authentication                                     //
// Language:       Verilog                                                       //
//                                                                               //
// Description:    Top level module of the trusted IC.                           //
///////////////////////////////////////////////////////////////////////////////////

`include "__timescale.v"
`include "__parameters.vh"


module top_trustedIC #(
        parameter KEY_LENGTH = 512,
        parameter e_WIDTH = 3
    )(
        input clk,
        input rst,
        input SPI_SCLK,
        input SPI_MOSI,
        output SPI_MISO
    );

    reg readPK_ready, challengeGen_pause, modExp_rst, modExp_start, SPI_send, SPI_dataReceived_ready_buf, SPI_dataReceived_ready_delayed, sent_done;
    reg [511:0] modExp_x, modExp_m;
    reg [e_WIDTH-1:0] modExp_y;
    wire [511:0] modExp_out;
    reg [KEY_LENGTH-1:0] SPI_dataToSend, publicKeyReceived, challenge;
    wire SPI_dataReceived_ready, SPI_dataReceived_ready_sync_pulse, modExp_ready;
    wire [KEY_LENGTH-1:0] storedPK, SPI_dataReceived, challengeGen_out;

    wire [e_WIDTH-1:0] publicExponent;

    challengeGen #(.CHALLENGE_LENGTH(KEY_LENGTH)) challengeGen (
        .clk(clk), 
        .rst(rst), 
        .pause(challengeGen_pause),
        .out(challengeGen_out)
    );

    SPISlave #(.KEY_LENGTH(KEY_LENGTH)) SPISlave (
        .clk(clk), 
        .rst(rst), 
        .dataToSend(SPI_dataToSend),
        .send(SPI_send),
        .MOSI(SPI_MOSI),
        .SCLK(SPI_SCLK),
        .MISO(SPI_MISO),
        .dataReceived(SPI_dataReceived),
        .dataReceived_ready(SPI_dataReceived_ready)
    );

    modExp_TIC #(.MONTGOMERY_MODULE_KEY_LENGTH(512), .e_WIDTH(e_WIDTH)) modExp_TIC (   // designed to work only for 512
        .clk(clk), 
        .rst(modExp_rst), 
        .x(modExp_x),
        .y(modExp_y),
        .m(modExp_m),
        .start(modExp_start),
        .ready(modExp_ready),
        .out(modExp_out)
    );

    // set stored public key with 'assign' for simulations; a one-time programmable non volatile memory should be considered in implementation.
    assign storedPK = 512'ha6653a5134cbc8421844d78b27c226206c6e7e77cadd58d9123bb5d2f09599e5a21b1199295eeaa53a9e47a3db992c0142e550f54e6fad2d8859d9307047d97b; // 512 bit
    // assign storedPK = 32'h67b98cd1;  //32 bit
    assign publicExponent = 3'b011; 

    assign SPI_dataReceived_ready_sync_pulse = SPI_dataReceived_ready_buf && !SPI_dataReceived_ready_delayed;

    reg [3:0] state, next_state;
    localparam STATE_IDLE = 4'd0;
    localparam STATE_READ_STORED_PK = 4'd1;
    localparam STATE_READY = 4'd2;
    localparam STATE_COMPARE_RECEIVED_PK = 4'd3;
    localparam STATE_ENCRYPT_CHALLENGE = 4'd4;
    localparam STATE_SEND_CHALLENGE = 4'd5;
    localparam STATE_COMPARE_RESPONSE = 4'd6;
    localparam STATE_LOCK = 4'd7;
    localparam STATE_AUTHENTICATED = 4'd8;
    localparam STATE_RESERVED = 4'd9;

    always @(posedge clk) begin
        if (!rst) begin
            readPK_ready = 1'b1;
            SPI_dataReceived_ready_buf <= 0;
            SPI_dataReceived_ready_delayed = 0;
        end
        else begin
            readPK_ready = 1'b1;
            SPI_dataReceived_ready_buf <= SPI_dataReceived_ready;
            SPI_dataReceived_ready_delayed = SPI_dataReceived_ready_buf;
        end
    end

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
                next_state = STATE_READ_STORED_PK;
            end

            STATE_READ_STORED_PK: begin
                if (readPK_ready) begin
                    next_state = STATE_READY;
                end
            end

            STATE_READY: begin
                if (SPI_dataReceived_ready) begin
                    next_state = STATE_COMPARE_RECEIVED_PK;
                end
            end

            STATE_COMPARE_RECEIVED_PK: begin
                if (SPI_dataReceived == storedPK) begin
                    next_state = STATE_ENCRYPT_CHALLENGE;
                end
                else begin
                    next_state = STATE_LOCK;
                end
            end

            STATE_ENCRYPT_CHALLENGE: begin
                if (modExp_ready) begin
                    next_state = STATE_SEND_CHALLENGE;
                end
            end

            STATE_SEND_CHALLENGE: begin
                if (SPI_dataReceived_ready_sync_pulse && sent_done) begin
                    next_state = STATE_COMPARE_RESPONSE;
                end
            end

            STATE_COMPARE_RESPONSE: begin
                if (SPI_dataReceived == challenge) begin
                    next_state = STATE_AUTHENTICATED;
                end
                else begin
                    next_state = STATE_LOCK;
                end
            end

            STATE_LOCK: begin
            end

            STATE_AUTHENTICATED: begin
            end

            STATE_RESERVED: begin
            end

            default: begin
                next_state = STATE_READ_STORED_PK;
            end
        endcase
    end

    always @(posedge clk) begin

        case (state)
            STATE_IDLE: begin
                challengeGen_pause <= 0;
                publicKeyReceived <= 0;
                challenge <= 0;
                modExp_rst <= 0;
                modExp_start <= 0;
                modExp_x <= 0;
                modExp_y <= 0;
                modExp_m <= 0;
                SPI_dataToSend <= 0;
                SPI_send <= 0;
                sent_done <= 0;
            end

            STATE_READ_STORED_PK: begin
                challengeGen_pause <= 0;
                publicKeyReceived <= 0;
                challenge <= 0;
                modExp_rst <= 0;
                modExp_start <= 0;
                modExp_x <= 0;
                modExp_y <= 0;
                modExp_m <= 0;
                SPI_dataToSend <= 0;
                SPI_send <= 0;
                sent_done <= 0;
            end

            STATE_READY: begin
                challengeGen_pause <= 0;
                publicKeyReceived <= 0;
                challenge <= 0;
                modExp_rst <= 1'b1;
                modExp_start <= 0;
                modExp_x <= 0;
                modExp_y <= 0;
                modExp_m <= 0;
                SPI_dataToSend <= 0;
                SPI_send <= 0;
                sent_done <= 0;
            end

            STATE_COMPARE_RECEIVED_PK: begin
                if (SPI_dataReceived == storedPK) begin
                    challengeGen_pause <= 1'b1;
                    challenge <= challengeGen_out;
                    modExp_start <= 1'b1;
                end
                else begin
                    challengeGen_pause <= 0;
                    challenge <= 0;
                    modExp_start <= 0;
                end

                modExp_x <= challengeGen_out;
                modExp_y <= publicExponent;
                modExp_m <= SPI_dataReceived;

                publicKeyReceived <= SPI_dataReceived;
                modExp_rst <= 1'b1;
                SPI_dataToSend <= 0;
                SPI_send <= 0;
                sent_done <= 0;
            end

            STATE_ENCRYPT_CHALLENGE: begin
                challengeGen_pause <= 1'b1;
                publicKeyReceived <= publicKeyReceived;
                challenge <= challenge;
                modExp_rst <= 1'b1;
                modExp_start <= 0;
                modExp_x <= challenge;
                modExp_y <= publicExponent;
                modExp_m <= publicKeyReceived;
                if (modExp_ready) begin
                    SPI_dataToSend <= modExp_out;
                end
                else begin
                    SPI_dataToSend <= 0;
                end
                SPI_send <= 0;
                sent_done <= 0;
            end

            STATE_SEND_CHALLENGE: begin
                challengeGen_pause <= 1'b1;
                publicKeyReceived <= publicKeyReceived;
                challenge <= challenge;
                modExp_rst <= 0;
                modExp_start <= 0;
                modExp_x <= 0;
                modExp_y <= 0;
                modExp_m <= 0;
                SPI_dataToSend <= SPI_dataToSend;
                SPI_send <= 1'b1;
                if (SPI_dataReceived_ready_sync_pulse) begin
                    sent_done <= 1'b1;
                end
                else begin
                    sent_done <= sent_done;
                end
            end

            STATE_COMPARE_RESPONSE: begin
                challengeGen_pause <= 1'b1;
                publicKeyReceived <= publicKeyReceived;
                challenge <= challenge;
                modExp_rst <= 0;
                modExp_start <= 0;
                modExp_x <= 0;
                modExp_y <= 0;
                modExp_m <= 0;
                SPI_dataToSend <= 0;
                SPI_send <= 0;
                sent_done <= 0;
            end

            STATE_LOCK: begin
                challengeGen_pause <= 1'b1;
                publicKeyReceived <= publicKeyReceived;
                challenge <= 0;
                modExp_rst <= 0;
                modExp_start <= 0;
                modExp_x <= 0;
                modExp_y <= 0;
                modExp_m <= 0;
                SPI_dataToSend <= 0;
                SPI_send <= 0;
                sent_done <= 0;
            end

            STATE_AUTHENTICATED: begin
                challengeGen_pause <= 1'b1;
                publicKeyReceived <= publicKeyReceived;
                challenge <= challenge;
                modExp_rst <= 0;
                modExp_start <= 0;
                modExp_x <= 0;
                modExp_y <= 0;
                modExp_m <= 0;
                SPI_dataToSend <= 0;
                SPI_send <= 0;
                sent_done <= 0;
            end

            STATE_RESERVED: begin
                challengeGen_pause <= 1'b1;
                publicKeyReceived <= publicKeyReceived;
                challenge <= challenge;
                modExp_rst <= 0;
                modExp_start <= 0;
                modExp_x <= 0;
                modExp_y <= 0;
                modExp_m <= 0;
                SPI_dataToSend <= 0;
                SPI_send <= 0;
                sent_done <= 0;
            end

            default: begin
                challengeGen_pause <= 0;
                publicKeyReceived <= 0;
                challenge <= 0;
                modExp_rst <= 0;
                modExp_start <= 0;
                modExp_x <= 0;
                modExp_y <= 0;
                modExp_m <= 0;
                SPI_dataToSend <= 0;
                SPI_send <= 0;
                sent_done <= 0;
            end
        endcase
    end

endmodule