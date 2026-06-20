
class receiver_seq_item extends uvm_sequence_item;
    receiver_op_e       op;
    receiver_scenario_e scenario;
    expected_cmd_e      exp_cmd;
    string              test_name;
    bit [1:0]           data_size;
    bit [7:0]           data;
    bit                 parity_enable;
    bit                 invert_parity;   
    bit                 bad_stop;        

    bit [7:0]           expected_data;
    bit                 expected_data_valid;
    bit                 expected_parity_error;
    bit                 expected_framing_error;
    int                 no_event_cycles;
    int                 timeout_cycles;   

    `uvm_object_utils(receiver_seq_item)

    function new(string name = "receiver_seq_item");
        super.new(name);
        op                      = OP_FRAME;
        scenario                = SC_NO_PARITY;
        exp_cmd                 = EXP_EVENT;
        test_name               = name;
        data_size               = 2'b00;
        data                    = 8'h00;
        parity_enable           = 1'b0;
        invert_parity           = 1'b0;
        bad_stop                = 1'b0;
        expected_data           = 8'h00;
        expected_data_valid     = 1'b0;
        expected_parity_error   = 1'b0;
        expected_framing_error  = 1'b0;
        no_event_cycles         = 0;
        timeout_cycles          = 0;
    endfunction

    function void copy_fields(receiver_seq_item rhs);
        op                      = rhs.op;
        scenario                = rhs.scenario;
        exp_cmd                 = rhs.exp_cmd;
        test_name               = rhs.test_name;
        data_size               = rhs.data_size;
        data                    = rhs.data;
        parity_enable           = rhs.parity_enable;
        invert_parity           = rhs.invert_parity;
        bad_stop                = rhs.bad_stop;
        expected_data           = rhs.expected_data;
        expected_data_valid     = rhs.expected_data_valid;
        expected_parity_error   = rhs.expected_parity_error;
        expected_framing_error  = rhs.expected_framing_error;
        no_event_cycles         = rhs.no_event_cycles;
        timeout_cycles          = rhs.timeout_cycles;
    endfunction

    function string convert2string();
        return $sformatf("%s op=%0d scenario=%0d size=%0d data=0x%02h parity_en=%0b inv_par=%0b bad_stop=%0b exp_data=0x%02h exp_valid=%0b exp_perr=%0b exp_ferr=%0b",
                         test_name, op, scenario, data_size, data, parity_enable,
                         invert_parity, bad_stop, expected_data,
                         expected_data_valid, expected_parity_error,
                         expected_framing_error);
    endfunction
endclass
