
class receiver_monitor extends uvm_component;
    `uvm_component_utils(receiver_monitor)

    virtual receiver_if vif;
    uvm_analysis_port #(receiver_seq_item) act_ap;   
    function new(string name = "receiver_monitor", uvm_component parent = null);
        super.new(name, parent);
        act_ap = new("act_ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual receiver_if)::get(this, "", "vif", vif))
            `uvm_fatal("NO_VIF", "receiver_if virtual interface was not set")
    endfunction

    task run_phase(uvm_phase phase);
        bit last_data_valid;
        bit last_framing_error;
        receiver_seq_item actual;
        last_data_valid    = 1'b0;
        last_framing_error = 1'b0;

        forever begin
            @(posedge vif.clk);
            #1;                                       
            if (!vif.rst_n) begin
                last_data_valid    = 1'b0;
                last_framing_error = 1'b0;
            end else begin
                
                if ((vif.data_valid && !last_data_valid) ||
                    (vif.framing_error && !last_framing_error)) begin
                    actual = receiver_seq_item::type_id::create("actual_event");
                    actual.expected_data          = vif.parallel_data;
                    actual.expected_data_valid    = vif.data_valid;
                    actual.expected_parity_error  = vif.parity_error;
                    actual.expected_framing_error = vif.framing_error;
                    act_ap.write(actual);
                end
                last_data_valid    = vif.data_valid;
                last_framing_error = vif.framing_error;
            end
        end
    endtask
endclass
