class receiver_reset_sequence extends uvm_sequence #(receiver_seq_item);
    `uvm_object_utils(receiver_reset_sequence)

    function new(string name = "receiver_reset_sequence");
        super.new(name);
    endfunction

    task body();
        receiver_seq_item item;
        item = receiver_seq_item::type_id::create("reset_item");
        start_item(item);
        item.op        = OP_RESET;
        item.scenario  = SC_RESET;
        item.test_name = "power-on reset clears outputs";
        finish_item(item);
    endtask
endclass

class receiver_valid_frame_sequence extends uvm_sequence #(receiver_seq_item);
    `uvm_object_utils(receiver_valid_frame_sequence)

    function new(string name = "receiver_valid_frame_sequence");
        super.new(name);
    endfunction

    task send_frame(string name,
                    bit [1:0] size,
                    bit [7:0] data,
                    bit parity_on,
                    receiver_scenario_e scenario);
        receiver_seq_item item;
        item = receiver_seq_item::type_id::create(name);
        start_item(item);
        item.op            = OP_FRAME;
        item.scenario      = scenario;
        item.test_name     = name;
        item.data_size     = size;
        item.data          = data;
        item.parity_enable = parity_on;
        item.invert_parity = 1'b0;
        item.bad_stop      = 1'b0;
        finish_item(item);
    endtask

    task body();
        int i;
        for (i = 0; i < 4; i++)
            send_frame($sformatf("%0d-bit no-parity receive", i + 4),
                       i[1:0], no_parity_data(i), 1'b0, SC_NO_PARITY);

        for (i = 0; i < 4; i++)
            send_frame($sformatf("%0d-bit good even-parity receive", i + 4),
                       i[1:0], good_parity_data(i), 1'b1, SC_GOOD_PARITY);
    endtask
endclass


class receiver_error_frame_sequence extends uvm_sequence #(receiver_seq_item);
    `uvm_object_utils(receiver_error_frame_sequence)

    function new(string name = "receiver_error_frame_sequence");
        super.new(name);
    endfunction

    task send_error_frame(string name,
                          bit [1:0] size,
                          bit [7:0] data,
                          bit invert_parity,
                          bit bad_stop,
                          receiver_scenario_e scenario);
        receiver_seq_item item;
        item = receiver_seq_item::type_id::create(name);
        start_item(item);
        item.op            = OP_FRAME;
        item.scenario      = scenario;
        item.test_name     = name;
        item.data_size     = size;
        item.data          = data;
        item.parity_enable = 1'b1;
        item.invert_parity = invert_parity;
        item.bad_stop      = bad_stop;
        finish_item(item);
    endtask

    task body();
        int i;
        for (i = 0; i < 4; i++)
            send_error_frame($sformatf("%0d-bit bad even-parity receive", i + 4),
                             i[1:0], bad_parity_data(i), 1'b1, 1'b0, SC_BAD_PARITY);

        send_error_frame("framing error on bad stop bit",
                         2'b10, 8'h2A, 1'b0, 1'b1, SC_FRAMING);
    endtask
endclass


class receiver_control_sequence extends uvm_sequence #(receiver_seq_item);
    `uvm_object_utils(receiver_control_sequence)

    function new(string name = "receiver_control_sequence");
        super.new(name);
    endfunction

    task send_item(receiver_op_e op,
                   string name,
                   receiver_scenario_e scenario,
                   bit [1:0] size = 2'b00,
                   bit [7:0] data = 8'h00,
                   bit parity_on = 1'b0);
        receiver_seq_item item;
        item = receiver_seq_item::type_id::create(name);
        start_item(item);
        item.op            = op;
        item.scenario      = scenario;
        item.test_name     = name;
        item.data_size     = size;
        item.data          = data;
        item.parity_enable = parity_on;
        finish_item(item);
    endtask

    task body();
        send_item(OP_FALSE_START,
                  "false start shorter than half bit is rejected",
                  SC_FALSE_START);

        send_item(OP_ENABLE_LOW,
                  "enable-low ignores a complete packet",
                  SC_ENABLE_LOW,
                  2'b11, 8'h55, 1'b1);

        send_item(OP_RESET_MID_FRAME,
                  "reset during frame clears state and blocks stale packet",
                  SC_RESET_MID,
                  2'b10, 8'h15, 1'b1);

        send_item(OP_FRAME,
                  "back-to-back frame 1",
                  SC_BACK_TO_BACK,
                  2'b01, 8'h0F, 1'b1);

        send_item(OP_FRAME,
                  "back-to-back frame 2",
                  SC_BACK_TO_BACK,
                  2'b11, 8'h3C, 1'b1);
    endtask
endclass
