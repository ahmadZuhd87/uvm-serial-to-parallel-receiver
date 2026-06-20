

class receiver_scoreboard extends uvm_component;
    `uvm_component_utils(receiver_scoreboard)

    uvm_analysis_imp_exp #(receiver_seq_item, receiver_scoreboard) exp_export;
    uvm_analysis_imp_act #(receiver_seq_item, receiver_scoreboard) act_export;

    receiver_seq_item exp_q[$];       
    bit    no_event_active;
    string no_event_name;
    int    checks_passed;
    int    timeout_failures;

    bit got_reset;
    bit got_no_parity   [4];
    bit got_good_parity [4];
    bit got_bad_parity  [4];
    bit got_framing_error;
    bit got_false_start;
    bit got_enable_low;
    bit got_reset_mid;
    int back_to_back_count;
    bit got_valid_packet;

    covergroup receiver_cg with function sample(bit [1:0] size,
                                                 bit parity_en,
                                                 bit parity_err,
                                                 bit frame_err,
                                                 bit valid_pkt);
        option.per_instance = 1;
        data_size_cp: coverpoint size {
            bins size_4 = {2'b00};
            bins size_5 = {2'b01};
            bins size_6 = {2'b10};
            bins size_7 = {2'b11};
        }
        parity_enable_cp: coverpoint parity_en {
            bins disabled = {0};
            bins enabled  = {1};
        }
        parity_error_cp: coverpoint parity_err {
            bins no_error = {0};
            bins error    = {1};
        }
        framing_error_cp: coverpoint frame_err {
            bins no_error = {0};
            bins error    = {1};
        }
        valid_packet_cp: coverpoint valid_pkt {
            bins not_valid = {0};
            bins valid     = {1};
        }
        size_x_parity: cross data_size_cp, parity_enable_cp;
        parity_en_x_err: cross parity_enable_cp, parity_error_cp;
    endgroup

    function new(string name = "receiver_scoreboard", uvm_component parent = null);
        super.new(name, parent);
        exp_export = new("exp_export", this);
        act_export = new("act_export", this);
        receiver_cg = new();
    endfunction

    function void mark_scenario(receiver_seq_item t);
        case (t.scenario)
            SC_RESET:        got_reset = 1'b1;
            SC_NO_PARITY:    got_no_parity[t.data_size]   = 1'b1;
            SC_GOOD_PARITY:  got_good_parity[t.data_size] = 1'b1;
            SC_BAD_PARITY:   got_bad_parity[t.data_size]  = 1'b1;
            SC_FRAMING:      got_framing_error = 1'b1;
            SC_FALSE_START:  got_false_start   = 1'b1;
            SC_ENABLE_LOW:   got_enable_low    = 1'b1;
            SC_RESET_MID:    got_reset_mid     = 1'b1;
            SC_BACK_TO_BACK: back_to_back_count++;
            default: ;
        endcase
        if (t.expected_data_valid)
            got_valid_packet = 1'b1;
    endfunction

   
    function void write_exp(receiver_seq_item t);
        receiver_seq_item exp_copy;
        case (t.exp_cmd)
            EXP_EVENT: begin
                exp_copy = receiver_seq_item::type_id::create("exp_copy");
                exp_copy.copy_fields(t);
                exp_q.push_back(exp_copy);
                `uvm_info("SB_EXP", {"Queued expected event (per spec): ", exp_copy.convert2string()}, UVM_MEDIUM)
            end

            EXP_NO_EVENT_START: begin
                if (no_event_active)
                    `uvm_error("SB_NO_EVENT", {"Nested no-event window started by ", t.test_name})
                no_event_active = 1'b1;
                no_event_name   = t.test_name;
                `uvm_info("SB_EXP", {"Started no-event window: ", t.test_name}, UVM_MEDIUM)
            end

            EXP_NO_EVENT_DONE: begin
                if (!no_event_active)
                    `uvm_error("SB_NO_EVENT", {"No-event window ended without a matching start: ", t.test_name})
                else begin
                    no_event_active = 1'b0;
                    checks_passed++;
                    mark_scenario(t);
                    `uvm_info("SB_PASS", {"No-event check passed: ", t.test_name}, UVM_LOW)
                end
            end

            EXP_CONTROL_DONE: begin
                checks_passed++;
                mark_scenario(t);
                `uvm_info("SB_PASS", {"Control check passed: ", t.test_name}, UVM_LOW)
            end

            default: `uvm_error("SB_EXP", "Unknown expected command")
        endcase
    endfunction

    
    function void write_act(receiver_seq_item actual);
        receiver_seq_item exp;
        bit pass;
        bit [7:0] upper_mask;

        if (no_event_active) begin
            `uvm_error("SB_UNEXPECTED",
                       $sformatf("Unexpected output event during no-event check '%s': data=0x%02h valid=%0b parity_error=%0b framing_error=%0b",
                                 no_event_name, actual.expected_data,
                                 actual.expected_data_valid,
                                 actual.expected_parity_error,
                                 actual.expected_framing_error))
            return;
        end

        if (exp_q.size() == 0) begin
            `uvm_error("SB_UNEXPECTED",
                       $sformatf("Unexpected output event: data=0x%02h valid=%0b parity_error=%0b framing_error=%0b",
                                 actual.expected_data,
                                 actual.expected_data_valid,
                                 actual.expected_parity_error,
                                 actual.expected_framing_error))
            return;
        end

        exp  = exp_q.pop_front();
        pass = 1'b1;

        if (actual.expected_data_valid !== exp.expected_data_valid) begin
            `uvm_error("SB_COMPARE", $sformatf("%s: data_valid expected %0b got %0b",
                                               exp.test_name, exp.expected_data_valid,
                                               actual.expected_data_valid))
            pass = 1'b0;
        end

        if (actual.expected_framing_error !== exp.expected_framing_error) begin
            `uvm_error("SB_COMPARE", $sformatf("%s: framing_error expected %0b got %0b",
                                               exp.test_name, exp.expected_framing_error,
                                               actual.expected_framing_error))
            pass = 1'b0;
        end

       
        if (!exp.expected_framing_error) begin
            upper_mask = ~spec_mask(exp.data_size);

            if (actual.expected_data !== exp.expected_data) begin
                `uvm_error("SB_COMPARE", $sformatf("%s: parallel_data expected 0x%02h (per spec, %0d-bit right-aligned) got 0x%02h",
                                                   exp.test_name, exp.expected_data,
                                                   spec_width(exp.data_size), actual.expected_data))
                pass = 1'b0;
            end

            if ((actual.expected_data & upper_mask) !== 8'h00) begin
                `uvm_error("SB_COMPARE", $sformatf("%s: unused upper bits are not zero per spec, got 0x%02h (upper mask 0x%02h)",
                                                   exp.test_name, actual.expected_data, upper_mask))
                pass = 1'b0;
            end

            if (actual.expected_parity_error !== exp.expected_parity_error) begin
                `uvm_error("SB_COMPARE", $sformatf("%s: parity_error expected %0b (standard even parity) got %0b",
                                                   exp.test_name, exp.expected_parity_error,
                                                   actual.expected_parity_error))
                pass = 1'b0;
            end
        end

        receiver_cg.sample(exp.data_size,
                           exp.parity_enable,
                           actual.expected_parity_error,
                           actual.expected_framing_error,
                           actual.expected_data_valid && !actual.expected_framing_error);

        if (pass) begin
            checks_passed++;
            mark_scenario(exp);
            `uvm_info("SB_PASS", {"Matched spec: ", exp.test_name}, UVM_LOW)
        end
    endfunction

    
    function void check_phase(uvm_phase phase);
        int i;
        super.check_phase(phase);

        if (exp_q.size() != 0)
            `uvm_error("SB_REMAINING", $sformatf("%0d expected event(s) were never observed (see SB_TIMEOUT errors above for details)", exp_q.size()))
        if (no_event_active)
            `uvm_error("SB_REMAINING", {"No-event window was still active: ", no_event_name})

        if (!got_reset)
            `uvm_error("COVERAGE", "Missing reset behavior check")
        for (i = 0; i < 4; i++) begin
            if (!got_no_parity[i])
                `uvm_error("COVERAGE", $sformatf("Missing no-parity check for data_size %0d", i))
            if (!got_good_parity[i])
                `uvm_error("COVERAGE", $sformatf("Missing good-parity check for data_size %0d", i))
            if (!got_bad_parity[i])
                `uvm_error("COVERAGE", $sformatf("Missing bad-parity check for data_size %0d", i))
        end
        if (!got_framing_error)
            `uvm_error("COVERAGE", "Missing framing-error check")
        if (!got_false_start)
            `uvm_error("COVERAGE", "Missing false-start check")
        if (!got_enable_low)
            `uvm_error("COVERAGE", "Missing enable-low check")
        if (!got_reset_mid)
            `uvm_error("COVERAGE", "Missing reset-mid-frame check")
        if (back_to_back_count < 2)
            `uvm_error("COVERAGE", "Missing back-to-back frame check")
        if (!got_valid_packet)
            `uvm_error("COVERAGE", "Missing valid packet coverage")

        `uvm_info("SB_SUMMARY",
                  $sformatf("Scoreboard checks passed: %0d, timeout failures: %0d, functional coverage: %0.2f%%",
                            checks_passed, timeout_failures, receiver_cg.get_coverage()),
                  UVM_LOW)
    endfunction
endclass
