
class receiver_driver extends uvm_driver #(receiver_seq_item);
    `uvm_component_utils(receiver_driver)

    virtual receiver_if vif;
    receiver_cfg        cfg;
    int                 clks_per_bit;
    uvm_analysis_port #(receiver_seq_item) exp_ap;   

    function new(string name = "receiver_driver", uvm_component parent = null);
        super.new(name, parent);
        exp_ap = new("exp_ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual receiver_if)::get(this, "", "vif", vif))
            `uvm_fatal("NO_VIF", "receiver_if virtual interface was not set")
        if (uvm_config_db #(receiver_cfg)::get(this, "", "cfg", cfg))
            clks_per_bit = cfg.clks_per_bit;
        else
            clks_per_bit = SPEC_CLKS_PER_BIT;
    endfunction

    task run_phase(uvm_phase phase);
        receiver_seq_item req;
        drive_idle();
        forever begin
            seq_item_port.get_next_item(req);
            case (req.op)
                OP_RESET:           drive_reset(req);
                OP_FRAME:           drive_frame(req, 1'b1);
                OP_FALSE_START:     drive_false_start(req);
                OP_ENABLE_LOW:      drive_enable_low(req);
                OP_RESET_MID_FRAME: drive_reset_mid_frame(req);
                default: `uvm_error("DRV_OP", $sformatf("Unknown op %0d", req.op))
            endcase
            seq_item_port.item_done();
        end
    endtask

   
    task drive_idle();
        vif.rst_n         <= 1'b1;
        vif.serial_in     <= 1'b1;
        vif.enable        <= 1'b1;
        vif.parity_enable <= 1'b0;
        vif.data_size     <= 2'b00;
    endtask

    task drive_bit(input bit value);
        @(negedge vif.clk);
        vif.serial_in <= value;
        repeat (clks_per_bit) @(posedge vif.clk);
    endtask

    task hold_serial(input bit value, input int cycles);
        @(negedge vif.clk);
        vif.serial_in <= value;
        repeat (cycles) @(posedge vif.clk);
    endtask

    task pulse_reset_for_cleanup();
        @(negedge vif.clk);
        vif.rst_n     <= 1'b0;
        vif.serial_in <= 1'b1;
        repeat (4) @(posedge vif.clk);
        @(negedge vif.clk);
        vif.rst_n <= 1'b1;
        repeat (2) @(posedge vif.clk);
    endtask

    task drive_reset(receiver_seq_item req);
        receiver_seq_item done_item;
        @(negedge vif.clk);
        vif.rst_n         <= 1'b0;
        vif.serial_in     <= 1'b1;
        vif.enable        <= 1'b1;
        vif.parity_enable <= 1'b0;
        vif.data_size     <= 2'b00;
        repeat (4) @(posedge vif.clk);
        #1;

        if (vif.data_valid    !== 1'b0  ||
            vif.parity_error  !== 1'b0  ||
            vif.framing_error !== 1'b0) begin
            `uvm_error("RESET_CHECK",
                       $sformatf("%s failed: status flags not clear - valid=%0b parity_error=%0b framing_error=%0b",
                                 req.test_name, vif.data_valid,
                                 vif.parity_error, vif.framing_error))
        end else begin
            `uvm_info("RESET_CHECK", req.test_name, UVM_LOW)
        end

        if (vif.parallel_data !== 8'h00) begin
            `uvm_warning("RESET_DATA_VALUE",
                         $sformatf("parallel_data after reset = 0x%02h (spec implies a benign/zero reset value)",
                                   vif.parallel_data))
        end

        done_item = receiver_seq_item::type_id::create("reset_done_item");
        done_item.copy_fields(req);
        done_item.exp_cmd = EXP_CONTROL_DONE;
        exp_ap.write(done_item);

        @(negedge vif.clk);
        vif.rst_n <= 1'b1;
        repeat (2) @(posedge vif.clk);
    endtask

    task publish_expected_event(receiver_seq_item req);
        receiver_seq_item exp_item;
        exp_item = receiver_seq_item::type_id::create("expected_event");
        exp_item.copy_fields(req);
        exp_item.exp_cmd                = EXP_EVENT;
        exp_item.expected_data          = req.data & spec_mask(req.data_size);
        exp_item.expected_framing_error = req.bad_stop;
        exp_item.expected_data_valid    = !req.bad_stop;
        exp_item.expected_parity_error  = req.parity_enable && req.invert_parity && !req.bad_stop;
        
        exp_item.timeout_cycles         = (spec_width(req.data_size) + 6) * clks_per_bit;
        exp_ap.write(exp_item);
    endtask

    task drive_frame_bits(receiver_seq_item req, bit enable_value = 1'b1);
        int i;
        bit [7:0] masked_data;
        bit parity_bit;
        begin
            masked_data           = req.data & spec_mask(req.data_size);
            vif.enable            <= enable_value;
            vif.data_size         <= req.data_size;
            vif.parity_enable     <= req.parity_enable;

            drive_bit(1'b0);                                 
            for (i = 0; i < spec_width(req.data_size); i++)
                drive_bit(masked_data[i]);                    
            if (req.parity_enable) begin
                parity_bit = spec_even_parity(masked_data, req.data_size) ^ req.invert_parity;
                drive_bit(parity_bit);                        
            end
        end
    endtask

    task drive_frame(receiver_seq_item req, bit expect_event);
        int timeout_cycles;
        int i;
        bit seen_valid;
        bit seen_framing;
        bit last_valid;
        bit last_framing;

        if (expect_event)
            publish_expected_event(req);

        timeout_cycles = (spec_width(req.data_size) + 6) * clks_per_bit;
        drive_frame_bits(req);

        seen_valid   = 1'b0;
        seen_framing = 1'b0;
        last_valid   = vif.data_valid;
        last_framing = vif.framing_error;

        @(negedge vif.clk);
        vif.serial_in <= req.bad_stop ? 1'b0 : 1'b1;

        for (i = 0; i < timeout_cycles; i++) begin
            @(posedge vif.clk);
            if (vif.data_valid    && !last_valid)    seen_valid   = 1'b1;
            if (vif.framing_error && !last_framing)  seen_framing = 1'b1;
            last_valid   = vif.data_valid;
            last_framing = vif.framing_error;
            if (seen_valid || seen_framing) begin
                
                repeat (2) @(posedge vif.clk);
                @(negedge vif.clk);
                vif.serial_in <= 1'b1;   
                return;
            end
        end

        @(negedge vif.clk);
        vif.serial_in <= 1'b1;   

        if (expect_event) begin
            `uvm_error("FRAME_TIMEOUT",
                       $sformatf("%s: neither data_valid nor framing_error asserted (rising edge) within %0d clock cycles after driving a spec-compliant %0d-bit frame. The DUT did not complete the frame as the spec requires.",
                                  req.test_name, timeout_cycles, spec_width(req.data_size)))
        end
      
        pulse_reset_for_cleanup();
    endtask

    task start_no_event_window(receiver_seq_item req, int cycles);
        receiver_seq_item exp_item;
        exp_item = receiver_seq_item::type_id::create("no_event_start");
        exp_item.copy_fields(req);
        exp_item.exp_cmd         = EXP_NO_EVENT_START;
        exp_item.no_event_cycles = cycles;
        exp_ap.write(exp_item);
    endtask

    task finish_no_event_window(receiver_seq_item req);
        receiver_seq_item exp_item;
        exp_item = receiver_seq_item::type_id::create("no_event_done");
        exp_item.copy_fields(req);
        exp_item.exp_cmd = EXP_NO_EVENT_DONE;
        exp_ap.write(exp_item);
    endtask

    task drive_false_start(receiver_seq_item req);
        int wait_cycles;
        wait_cycles = (clks_per_bit * 4);
        start_no_event_window(req, wait_cycles);
        hold_serial(1'b0, (clks_per_bit / 4));    
        hold_serial(1'b1, (clks_per_bit * 3));
        repeat (clks_per_bit) @(posedge vif.clk);
        finish_no_event_window(req);
    endtask

    task drive_enable_low(receiver_seq_item req);
        int wait_cycles;
        wait_cycles = (spec_width(req.data_size) + 5) * clks_per_bit;
        start_no_event_window(req, wait_cycles);
        vif.enable <= 1'b0;
        drive_frame_bits(req, 1'b0);
        drive_bit(req.bad_stop ? 1'b0 : 1'b1);   
        repeat (clks_per_bit) @(posedge vif.clk);
        vif.serial_in      <= 1'b1;
        vif.enable        <= 1'b1;
        vif.parity_enable <= 1'b0;
        vif.data_size     <= 2'b00;
        finish_no_event_window(req);
        repeat (2) @(posedge vif.clk);
    endtask

    task drive_reset_mid_frame(receiver_seq_item req);
        start_no_event_window(req, clks_per_bit * 2);
        vif.enable        <= 1'b1;
        vif.data_size     <= req.data_size;
        vif.parity_enable <= req.parity_enable;
        drive_bit(1'b0);                          
        drive_bit(1'b1);                          
        drive_bit(1'b0);

        @(negedge vif.clk);
        vif.rst_n     <= 1'b0;                     
        vif.serial_in <= 1'b1;
        repeat (4) @(posedge vif.clk);
        #1;

        if (vif.data_valid    !== 1'b0  ||
            vif.parity_error  !== 1'b0  ||
            vif.framing_error !== 1'b0) begin
            `uvm_error("RESET_MID",
                       $sformatf("%s failed: status flags not clear - valid=%0b parity_error=%0b framing_error=%0b",
                                 req.test_name, vif.data_valid,
                                 vif.parity_error, vif.framing_error))
        end else begin
            `uvm_info("RESET_MID", "Reset during frame cleared status outputs", UVM_LOW)
        end

        @(negedge vif.clk);
        vif.rst_n <= 1'b1;
        repeat (clks_per_bit * 2) @(posedge vif.clk);
        finish_no_event_window(req);
        repeat (2) @(posedge vif.clk);
    endtask
endclass
