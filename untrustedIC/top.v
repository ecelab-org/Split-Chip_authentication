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
// Description:    Top level module of the untrusted IC.                         //
///////////////////////////////////////////////////////////////////////////////////

`include "__timescale.v"
`include "__parameters.vh"


module top_untrustedIC #(
        parameter KEY_LENGTH = 512,
        parameter integer e_WIDTH = 3  // set minimum of 3
    )(
        input clk,
        input rst,
        input [(8*KEY_LENGTH)-1:0] cryptoKeyPairGen_noisyIn,
        input SPI_MISO,
        output SPI_SCLK,
        output SPI_MOSI
    );


    wire modExp_rst, cryptoKeyPairGen_modExp_rst, modExp_start, cryptoKeyPairGen_modExp_start, modExp_ready, cryptoKeyPairGen_modExp_ready;
    reg decrypt_modExp_rst, decryptionStart;
    wire [511:0] modExp_x, cryptoKeyPairGen_modExp_x, modExp_m, cryptoKeyPairGen_modExp_m, modExp_out, cryptoKeyPairGen_modExp_out;
    wire [511+e_WIDTH:0] modExp_y, cryptoKeyPairGen_modExp_y;
    wire [9:0] modExp_y_size, cryptoKeyPairGen_modExp_y_size;
    wire [KEY_LENGTH-1 : 0] publicKey, encryptedIn;
    reg [KEY_LENGTH-1 : 0] SPIMaster_dataToSend;

    reg dataArrived, dataArrived_delayed; // edge triggered logic
    reg SPIMaster_start;
    wire cryptoKeyPairGen_ready;
    wire [KEY_LENGTH+e_WIDTH:0] privateKey;

    localparam integer SCLK_PERIOD_AS_CLK_MULTIPLE = 10;
    localparam SPI_counter_WIDTH = $clog2((KEY_LENGTH+1) * SCLK_PERIOD_AS_CLK_MULTIPLE + 2);
    reg [SPI_counter_WIDTH-1:0] SPI_counter;

    wire [e_WIDTH-1:0] publicExponent;

    cryptoKeyPairGen #(.KEY_LENGTH(KEY_LENGTH), .e_WIDTH(e_WIDTH)) cryptoKeyPairGen (
        .clk(clk), 
        .rst(rst), 
        .noisyIn(cryptoKeyPairGen_noisyIn), 
        .e(publicExponent),
        .modExp_ready(cryptoKeyPairGen_modExp_ready),
        .modExp_out(cryptoKeyPairGen_modExp_out),
        .modExp_rst(cryptoKeyPairGen_modExp_rst),
        .modExp_x(cryptoKeyPairGen_modExp_x),
        .modExp_y(cryptoKeyPairGen_modExp_y),
        .modExp_y_size(cryptoKeyPairGen_modExp_y_size),
        .modExp_m(cryptoKeyPairGen_modExp_m),
        .modExp_start(cryptoKeyPairGen_modExp_start),
        .ready(cryptoKeyPairGen_ready),
        .MOD(publicKey),
        .privateKey(privateKey)
    );

    modExp_UIC #(.MONTGOMERY_MODULE_KEY_LENGTH(512), .e_WIDTH(e_WIDTH)) modExp_UIC (   // designed to work only for 512
        .clk(clk), 
        .rst(modExp_rst), 
        .x(modExp_x),
        .y(modExp_y),
        .y_size(modExp_y_size),
        .m(modExp_m),
        .start(modExp_start),
        .ready(modExp_ready),
        .out(modExp_out)
    );

    SPIMaster #(.KEY_LENGTH(KEY_LENGTH), .SCLK_PERIOD_AS_CLK_MULTIPLE(SCLK_PERIOD_AS_CLK_MULTIPLE)) SPIMaster (
        .clk(clk), 
        .rst(rst), 
        .dataToSend(SPIMaster_dataToSend),
        .start(SPIMaster_start),
        .MISO(SPI_MISO),
        .SCLK(SPI_SCLK),
        .MOSI(SPI_MOSI),
        .dataReceived(encryptedIn)
    );


    assign publicExponent = 3'b011; 
//    assign publicExponent[e_WIDTH-1:0] = 'b10000000000000001;   // we can choose a small e, such as 3, to reduce the exponentiation
                                                                // effort for encryption/decryption at later stages. However the search
																// space for finding correct primes will increase and we have to try
                                                                // several prime pairs in order to find a valid pair (f_n % e != 0).

    // SPI receive
    always @(posedge clk) begin // make request signals posedge triggered
        if (!rst) begin
            dataArrived <= 0;
            dataArrived_delayed <= 0;
        end
        else begin
            dataArrived_delayed <= dataArrived;
            if (SPI_MISO == 1'b1) begin
                dataArrived <= 1'b1;
            end
            else begin
                dataArrived <= 0;
            end
        end
    end
    // end of SPI receive

    reg [2:0] state, next_state;
    localparam STATE_IDLE = 3'd0;
    localparam STATE_CRYPTO_KEY_GEN = 3'd1;
    localparam STATE_READY = 3'd2;
    localparam STATE_DECRYPT = 3'd3;

    always @(*) begin
        case (state)
            STATE_CRYPTO_KEY_GEN: begin
                SPIMaster_dataToSend = publicKey;
            end

            STATE_DECRYPT: begin
                SPIMaster_dataToSend = modExp_out;
            end

            default: begin
                SPIMaster_dataToSend = 0;
            end
        endcase
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
                next_state = STATE_CRYPTO_KEY_GEN;
            end

            STATE_CRYPTO_KEY_GEN: begin
                if (SPI_counter == (KEY_LENGTH+1) * SCLK_PERIOD_AS_CLK_MULTIPLE + 2) begin
                    next_state = STATE_READY;
                end
            end

            STATE_READY: begin
                if (SPI_counter == (KEY_LENGTH+1) * SCLK_PERIOD_AS_CLK_MULTIPLE + 2) begin
                    next_state = STATE_DECRYPT;
                end
            end

            STATE_DECRYPT: begin
                if (SPI_counter == (KEY_LENGTH+1) * SCLK_PERIOD_AS_CLK_MULTIPLE + 2) begin
                    next_state = STATE_READY;
                end
            end

            default: begin
                next_state = STATE_CRYPTO_KEY_GEN;
            end
        endcase
    end

    always @(posedge clk) begin

        case (state)
            STATE_IDLE: begin
                decrypt_modExp_rst <= 0;
                decryptionStart <= 0;
                SPIMaster_start <= 0;
                SPI_counter <= 0;
            end

            STATE_CRYPTO_KEY_GEN: begin
                decrypt_modExp_rst <= 0;
                decryptionStart <= 0;
                if (cryptoKeyPairGen_ready) begin
                    if (SPI_counter == (KEY_LENGTH+1) * SCLK_PERIOD_AS_CLK_MULTIPLE + 2) begin
                        SPIMaster_start <= 1'b0;
                        SPI_counter <= 0;
                    end
                    else begin
                        SPIMaster_start <= 1'b1;
                        SPI_counter <= SPI_counter + 1'b1;
                    end
                end
                else begin
                    SPIMaster_start <= 0;
                    SPI_counter <= 0;
                end
            end

            STATE_READY: begin
                decrypt_modExp_rst <= 1'b1;
                decryptionStart <= 0;
                if (dataArrived && !dataArrived_delayed) begin
                    SPIMaster_start <= 1'b1;
                end
                else begin
                    if (SPI_counter == (KEY_LENGTH+1) * SCLK_PERIOD_AS_CLK_MULTIPLE + 2) begin
                        SPIMaster_start <= 0;
                    end
                    else begin
                        SPIMaster_start <= SPIMaster_start;
                    end
                end

                if (SPIMaster_start) begin
                    if (SPI_counter == (KEY_LENGTH+1) * SCLK_PERIOD_AS_CLK_MULTIPLE + 2) begin
                        SPI_counter <= 0;
                        decryptionStart <= 1'b1;
                    end
                    else begin
                        SPI_counter <= SPI_counter + 1'b1;
                        decryptionStart <= 0;
                    end
                end
            end

            STATE_DECRYPT: begin
                decrypt_modExp_rst <= 1'b1;
                decryptionStart <= 0;
                if (modExp_ready) begin
                    SPIMaster_start <= 1'b1;
                end
                else begin
                    if (SPI_counter == (KEY_LENGTH+1) * SCLK_PERIOD_AS_CLK_MULTIPLE + 2) begin
                        SPIMaster_start <= 0;
                    end
                    else begin
                        SPIMaster_start <= SPIMaster_start;
                    end
                end

                if (SPIMaster_start) begin
                    if (SPI_counter == (KEY_LENGTH+1) * SCLK_PERIOD_AS_CLK_MULTIPLE + 2) begin
                        SPI_counter <= 0;
                    end
                    else begin
                        SPI_counter <= SPI_counter + 1'b1;
                    end
                end
            end

            default: begin
                decrypt_modExp_rst <= 0;
                decryptionStart <= 0;
                SPIMaster_start <= 0;
                SPI_counter <= 0;
            end
        endcase
    end


    localparam [9:0] MODEXP_Y_SIZE = KEY_LENGTH+e_WIDTH;

    assign modExp_rst = (state == STATE_CRYPTO_KEY_GEN) ? cryptoKeyPairGen_modExp_rst : decrypt_modExp_rst;
    assign modExp_x = (state == STATE_CRYPTO_KEY_GEN) ? cryptoKeyPairGen_modExp_x : encryptedIn;
    assign modExp_y = (state == STATE_CRYPTO_KEY_GEN) ? cryptoKeyPairGen_modExp_y : privateKey;
    assign modExp_y_size = (state == STATE_CRYPTO_KEY_GEN) ? cryptoKeyPairGen_modExp_y_size : MODEXP_Y_SIZE;
    assign modExp_m = (state == STATE_CRYPTO_KEY_GEN) ? cryptoKeyPairGen_modExp_m : publicKey;
    assign modExp_start = (state == STATE_CRYPTO_KEY_GEN) ? cryptoKeyPairGen_modExp_start : decryptionStart;
    assign cryptoKeyPairGen_modExp_ready = (state == STATE_CRYPTO_KEY_GEN) ? modExp_ready : 0;
    assign cryptoKeyPairGen_modExp_out = (state == STATE_CRYPTO_KEY_GEN) ? modExp_out : 0;

endmodule