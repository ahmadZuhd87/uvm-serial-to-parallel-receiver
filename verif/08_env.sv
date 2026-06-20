
class receiver_env extends uvm_env;
    `uvm_component_utils(receiver_env)

    receiver_agent      agent;
    receiver_scoreboard scoreboard;

    function new(string name = "receiver_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent      = receiver_agent::type_id::create("agent", this);
        scoreboard = receiver_scoreboard::type_id::create("scoreboard", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agent.driver.exp_ap.connect(scoreboard.exp_export);
        agent.monitor.act_ap.connect(scoreboard.act_export);
    endfunction
endclass
