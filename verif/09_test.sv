
class receiver_base_test extends uvm_test;
    `uvm_component_utils(receiver_base_test)

    receiver_env        env;
    receiver_cfg        cfg;
    virtual receiver_if vif;

    function new(string name = "receiver_base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = receiver_env::type_id::create("env", this);
        if (!uvm_config_db #(virtual receiver_if)::get(this, "", "vif", vif))
            `uvm_fatal("NO_VIF", "receiver_if virtual interface was not set")
        void'(uvm_config_db #(receiver_cfg)::get(this, "", "cfg", cfg));
    endfunction

    task run_phase(uvm_phase phase);
        receiver_reset_sequence       reset_seq;
        receiver_valid_frame_sequence valid_seq;
        receiver_error_frame_sequence error_seq;
        receiver_control_sequence     control_seq;
        int rtl_default_clks_per_bit;

        phase.raise_objection(this);

        if (cfg != null)
            rtl_default_clks_per_bit = cfg.rtl_default_clks_per_bit;
        else if (!uvm_config_db #(int)::get(this, "", "rtl_default_clks_per_bit", rtl_default_clks_per_bit))
            rtl_default_clks_per_bit = -1;

        if (rtl_default_clks_per_bit == -1) begin
            `uvm_error("BAUD_CHECK", "RTL default CLKS_PER_BIT value was not provided")
        end else if (rtl_default_clks_per_bit != SPEC_CLKS_PER_BIT) begin
            `uvm_error("BAUD_CHECK",
                       $sformatf("RTL default CLKS_PER_BIT is %0d (~%0d bps); spec requires %0d (1200 bps @ 100MHz) - DUT baud rate deviates from spec",
                                 rtl_default_clks_per_bit,
                                 100_000_000 / rtl_default_clks_per_bit,
                                 SPEC_CLKS_PER_BIT))
        end else begin
            `uvm_info("BAUD_CHECK",
                      "RTL default CLKS_PER_BIT is 83333 for 100 MHz / 1200 bps, matches spec",
                      UVM_LOW)
        end

        reset_seq   = receiver_reset_sequence::type_id::create("reset_seq");
        valid_seq   = receiver_valid_frame_sequence::type_id::create("valid_seq");
        error_seq   = receiver_error_frame_sequence::type_id::create("error_seq");
        control_seq = receiver_control_sequence::type_id::create("control_seq");

        reset_seq.start(env.agent.sequencer);
        valid_seq.start(env.agent.sequencer);
        error_seq.start(env.agent.sequencer);
        control_seq.start(env.agent.sequencer);

        repeat (20) @(posedge vif.clk);
        phase.drop_objection(this);
    endtask

    function void final_phase(uvm_phase phase);
        uvm_report_server svr;
        super.final_phase(phase);
        svr = uvm_report_server::get_server();
        if (svr.get_severity_count(UVM_FATAL) == 0 &&
            svr.get_severity_count(UVM_ERROR) == 0) begin
            `uvm_info("UVM_PASS",
                      "FINAL UVM TEST PASS: all receiver checks passed",
                      UVM_NONE)
        end else begin
            `uvm_error("UVM_FAIL", "FINAL UVM TEST FAIL: see errors above - DUT deviates from spec")
        end
    endfunction
endclass
