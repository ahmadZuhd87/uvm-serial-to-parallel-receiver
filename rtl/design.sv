`timescale 1ns/1ps

module baud_counter #(
    parameter integer CLKS_PER_BIT = 83333
)(
    input  wire clk,
    input  wire rst_n,
    input  wire enable,
    input  wire clear,
    output reg  mid_tick,
    output reg  full_tick
);
    localparam integer HALF_CLKS_PER_BIT = CLKS_PER_BIT / 2;

    reg [31:0] count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count     <= 32'd0;
            mid_tick  <= 1'b0;
            full_tick <= 1'b0;
        end else if (clear) begin
            count     <= 32'd0;
            mid_tick  <= 1'b0;
            full_tick <= 1'b0;
        end else if (enable) begin
            mid_tick  <= (count == (HALF_CLKS_PER_BIT - 1));
            full_tick <= (count == (CLKS_PER_BIT - 1));

            if (count == (CLKS_PER_BIT - 1))
                count <= 32'd0;
            else
                count <= count + 32'd1;
        end else begin
            count     <= 32'd0;
            mid_tick  <= 1'b0;
            full_tick <= 1'b0;
        end
    end
endmodule


module shift_register (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       shift_en,
    input  wire       clear,
    input  wire       serial_in,
    input  wire [1:0] data_size,
    output reg  [7:0] parallel_out
);
    reg [7:0] shreg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            shreg <= 8'h00;
        else if (clear)
            shreg <= 8'h00;
        else if (shift_en)
            shreg <= {serial_in, shreg[7:1]};
    end

    always @(*) begin
        case (data_size)
            2'b00: parallel_out = {4'b0000, shreg[7:4]};
            2'b01: parallel_out = {3'b000,  shreg[7:3]};
            2'b10: parallel_out = {2'b00,   shreg[7:2]};
            2'b11: parallel_out = {1'b0,    shreg[7:1]};
            default: parallel_out = 8'h00;
        endcase
    end
endmodule


module parity_checker (
    input  wire [7:0] data,
    input  wire [1:0] data_size,
    input  wire       received_parity,
    input  wire       parity_enable,
    output wire       parity_error
);
    reg data_xor;

    always @(*) begin
        case (data_size)
            2'b00: data_xor = ^data[3:0];
            2'b01: data_xor = ^data[4:0];
            2'b10: data_xor = ^data[5:0];
            2'b11: data_xor = ^data[6:0];
            default: data_xor = 1'b0;
        endcase
    end

    assign parity_error = parity_enable ? (data_xor ^ received_parity) : 1'b0;
endmodule


module receiver_fsm (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       enable,
    input  wire       parity_enable,
    input  wire [1:0] data_size,
    input  wire       serial_in,
    input  wire       mid_tick,
    input  wire       full_tick,

    output reg        baud_en,
    output reg        baud_clear,
    output reg        shift_en,
    output reg        shift_clear,
    output reg        capture_parity,
    output reg        latch_data,
    output reg        clear_status,
    output reg        set_framing_err,
    output reg        data_valid_next,
    output reg        framing_err_next
);
    localparam IDLE    = 3'd0,
               START   = 3'd1,
               RECEIVE = 3'd2,
               PARITY  = 3'd3,
               STOP    = 3'd4,
               DONE    = 3'd5,
               ERROR   = 3'd6;

    reg [2:0] state;
    reg [2:0] next_state;
    reg [3:0] bit_count;
    reg [3:0] num_bits_needed;

    always @(*) begin
        case (data_size)
            2'b00: num_bits_needed = 4'd4;
            2'b01: num_bits_needed = 4'd5;
            2'b10: num_bits_needed = 4'd6;
            2'b11: num_bits_needed = 4'd7;
            default: num_bits_needed = 4'd4;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bit_count <= 4'd0;
        else if (state == IDLE || state == START)
            bit_count <= 4'd0;
        else if (state == RECEIVE && shift_en)
            bit_count <= bit_count + 4'd1;
    end

    always @(*) begin
        next_state       = state;
        baud_en          = 1'b0;
        baud_clear       = 1'b0;
        shift_en         = 1'b0;
        shift_clear      = 1'b0;
        capture_parity   = 1'b0;
        latch_data       = 1'b0;
        clear_status     = 1'b0;
        set_framing_err  = 1'b0;
        data_valid_next  = 1'b0;
        framing_err_next = 1'b0;

        case (state)
            IDLE: begin
                shift_clear = 1'b1;
                if (enable && !serial_in) begin
                    baud_clear  = 1'b1;
                    clear_status = 1'b1;
                    next_state  = START;
                end
            end

            START: begin
                baud_en = 1'b1;
                if (mid_tick) begin
                    if (!serial_in)
                        next_state = RECEIVE;
                    else begin
                        baud_clear = 1'b1;
                        next_state = IDLE;
                    end
                end
            end

            RECEIVE: begin
                baud_en = 1'b1;
                if (mid_tick)
                    shift_en = 1'b1;

                if (full_tick && bit_count == num_bits_needed) begin
                    if (parity_enable)
                        next_state = PARITY;
                    else
                        next_state = STOP;
                end
            end

            PARITY: begin
                baud_en = 1'b1;
                if (mid_tick)
                    capture_parity = 1'b1;
                if (full_tick)
                    next_state = STOP;
            end

            STOP: begin
                baud_en = 1'b1;
                if (mid_tick) begin
                    if (serial_in) begin
                        latch_data      = 1'b1;
                        data_valid_next = 1'b1;
                        next_state      = DONE;
                    end else begin
                        set_framing_err  = 1'b1;
                        framing_err_next = 1'b1;
                        next_state       = ERROR;
                    end
                end
            end

            DONE: begin
                baud_en = 1'b1;
                if (full_tick)
                    next_state = IDLE;
            end

            ERROR: begin
                framing_err_next = 1'b1;
                if (serial_in)
                    next_state = IDLE;
            end

            default: begin
                baud_clear = 1'b1;
                next_state = IDLE;
            end
        endcase
    end
endmodule


module serial_to_parallel_receiver #(
    parameter integer CLKS_PER_BIT = 83333
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       serial_in,
    input  wire       enable,
    input  wire       parity_enable,
    input  wire [1:0] data_size,
    output reg  [7:0] parallel_data,
    output reg        data_valid,
    output reg        parity_error,
    output reg        framing_error
);
    wire mid_tick;
    wire full_tick;
    wire baud_en;
    wire baud_clear;
    wire shift_en;
    wire shift_clear;
    wire capture_parity;
    wire latch_data;
    wire clear_status;
    wire set_framing_err;
    wire data_valid_next;
    wire framing_err_next;
    wire [7:0] shift_data;
    wire parity_err_comb;

    reg received_parity_bit;

    baud_counter #(
        .CLKS_PER_BIT(CLKS_PER_BIT)
    ) u_baud (
        .clk       (clk),
        .rst_n     (rst_n),
        .enable    (baud_en),
        .clear     (baud_clear),
        .mid_tick  (mid_tick),
        .full_tick (full_tick)
    );

    shift_register u_shift (
        .clk          (clk),
        .rst_n        (rst_n),
        .shift_en     (shift_en),
        .clear        (shift_clear),
        .serial_in    (serial_in),
        .data_size    (data_size),
        .parallel_out (shift_data)
    );

    parity_checker u_parity (
        .data            (shift_data),
        .data_size       (data_size),
        .received_parity (received_parity_bit),
        .parity_enable   (parity_enable),
        .parity_error    (parity_err_comb)
    );

    receiver_fsm u_fsm (
        .clk              (clk),
        .rst_n            (rst_n),
        .enable           (enable),
        .parity_enable    (parity_enable),
        .data_size        (data_size),
        .serial_in        (serial_in),
        .mid_tick         (mid_tick),
        .full_tick        (full_tick),
        .baud_en          (baud_en),
        .baud_clear       (baud_clear),
        .shift_en         (shift_en),
        .shift_clear      (shift_clear),
        .capture_parity   (capture_parity),
        .latch_data       (latch_data),
        .clear_status     (clear_status),
        .set_framing_err  (set_framing_err),
        .data_valid_next  (data_valid_next),
        .framing_err_next (framing_err_next)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            parallel_data       <= 8'h00;
            data_valid          <= 1'b0;
            parity_error        <= 1'b0;
            framing_error       <= 1'b0;
            received_parity_bit <= 1'b0;
        end else begin
            data_valid <= data_valid_next;

            if (clear_status) begin
                parity_error  <= 1'b0;
                framing_error <= 1'b0;
            end else if (set_framing_err) begin
                framing_error <= 1'b1;
            end else begin
                framing_error <= framing_err_next;
            end

            if (capture_parity)
                received_parity_bit <= serial_in;

            if (latch_data) begin
                parallel_data <= shift_data;
                parity_error  <= parity_err_comb;
            end
        end
    end
endmodule