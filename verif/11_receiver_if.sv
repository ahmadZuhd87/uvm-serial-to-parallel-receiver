
interface receiver_if (input logic clk);
    logic       rst_n;
    logic       serial_in;
    logic       enable;
    logic       parity_enable;
    logic [1:0] data_size;
    logic [7:0] parallel_data;
    logic       data_valid;
    logic       parity_error;
    logic       framing_error;

    clocking cb @(posedge clk);
        default input #1step output #1;
        output serial_in, enable, parity_enable, data_size, rst_n;
        input  parallel_data, data_valid, parity_error, framing_error;
    endclocking

    modport DRV (clocking cb, output rst_n, serial_in, enable,
                 parity_enable, data_size, input clk);
    modport MON (clocking cb, input clk, rst_n, serial_in, enable,
                 parity_enable, data_size, parallel_data, data_valid,
                 parity_error, framing_error);
endinterface


module receiver_assertions (
    input logic       clk,
    input logic       rst_n,
    input logic [7:0] parallel_data,
    input logic       data_valid,
    input logic       parity_error,
    input logic       framing_error
);
    
    reg rst_seen;
    initial rst_seen = 1'b0;
    always @(negedge rst_n) rst_seen <= 1'b1;

    property p_reset_clears;
        @(posedge clk) (!rst_n) |-> (!data_valid && !parity_error && !framing_error);
    endproperty
    a_reset_clears : assert property (p_reset_clears)
        else $error("[ASSERT] status flag high during reset");

    property p_valid_xor_framing;
        @(posedge clk) disable iff (!rst_n || !rst_seen)
            !(data_valid && framing_error);
    endproperty
    a_valid_xor_framing : assert property (p_valid_xor_framing)
        else $error("[ASSERT] data_valid and framing_error asserted together");

    
    reg last_data_valid;
    initial last_data_valid = 1'b0;
    always @(posedge clk) last_data_valid <= data_valid;

    property p_valid_is_pulse;
        @(posedge clk) disable iff (!rst_n || !rst_seen)
            (data_valid && !last_data_valid) |=> !data_valid;
    endproperty
    a_valid_is_pulse : assert property (p_valid_is_pulse)
        else $warning("[ASSERT] data_valid stayed high for more than one cycle (DUT deviates from a single-cycle pulse convention)");
endmodule
