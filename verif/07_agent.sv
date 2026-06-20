
class receiver_sequencer extends uvm_sequencer #(receiver_seq_item);
    `uvm_component_utils(receiver_sequencer)

    function new(string name = "receiver_sequencer", uvm_component parent = null);
        super.new(name, parent);
    endfunction
endclass


class receiver_agent extends uvm_agent;
    `uvm_component_utils(receiver_agent)

    receiver_sequencer sequencer;
    receiver_driver    driver;
    receiver_monitor   monitor;

    function new(string name = "receiver_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        sequencer = receiver_sequencer::type_id::create("sequencer", this);
        driver    = receiver_driver::type_id::create("driver", this);
        monitor   = receiver_monitor::type_id::create("monitor", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        driver.seq_item_port.connect(sequencer.seq_item_export);
    endfunction
endclass
