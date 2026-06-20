
localparam int SPEC_CLKS_PER_BIT = 83333;

typedef enum int {
    OP_RESET,            
    OP_FRAME,            
    OP_FALSE_START,      
    OP_ENABLE_LOW,       
    OP_RESET_MID_FRAME  
} receiver_op_e;

typedef enum int {
    SC_RESET,
    SC_NO_PARITY,
    SC_GOOD_PARITY,
    SC_BAD_PARITY,
    SC_FRAMING,
    SC_FALSE_START,
    SC_ENABLE_LOW,
    SC_RESET_MID,
    SC_BACK_TO_BACK
} receiver_scenario_e;

typedef enum int {
    EXP_EVENT,           
    EXP_NO_EVENT_START,  
    EXP_NO_EVENT_DONE,   
    EXP_CONTROL_DONE     
} expected_cmd_e;


function automatic int spec_width(input bit [1:0] size);
    case (size)
        2'b00: spec_width = 4;
        2'b01: spec_width = 5;
        2'b10: spec_width = 6;
        2'b11: spec_width = 7;
        default: spec_width = 4;
    endcase
endfunction

function automatic bit [7:0] spec_mask(input bit [1:0] size);
    case (size)
        2'b00: spec_mask = 8'h0F;
        2'b01: spec_mask = 8'h1F;
        2'b10: spec_mask = 8'h3F;
        2'b11: spec_mask = 8'h7F;
        default: spec_mask = 8'h0F;
    endcase
endfunction

function automatic bit spec_even_parity(input bit [7:0] data, input bit [1:0] size);
    bit parity;
    int i;
    begin
        parity = 1'b0;
        for (i = 0; i < spec_width(size); i++)
            parity = parity ^ data[i];
        spec_even_parity = parity;
    end
endfunction

function automatic bit [7:0] no_parity_data(input int index);
    case (index)
        0: no_parity_data = 8'h0A;
        1: no_parity_data = 8'h13;
        2: no_parity_data = 8'h2D;
        3: no_parity_data = 8'h55;
        default: no_parity_data = 8'h00;
    endcase
endfunction

function automatic bit [7:0] good_parity_data(input int index);
    case (index)
        0: good_parity_data = 8'h09;
        1: good_parity_data = 8'h16;
        2: good_parity_data = 8'h31;
        3: good_parity_data = 8'h6A;
        default: good_parity_data = 8'h00;
    endcase
endfunction

function automatic bit [7:0] bad_parity_data(input int index);
    case (index)
        0: bad_parity_data = 8'h05;
        1: bad_parity_data = 8'h1B;
        2: bad_parity_data = 8'h22;
        3: bad_parity_data = 8'h49;
        default: bad_parity_data = 8'h00;
    endcase
endfunction



class receiver_cfg extends uvm_object;
    int clks_per_bit;              
    int rtl_default_clks_per_bit;  

    `uvm_object_utils_begin(receiver_cfg)
        `uvm_field_int(clks_per_bit,             UVM_DEFAULT)
        `uvm_field_int(rtl_default_clks_per_bit, UVM_DEFAULT)
    `uvm_object_utils_end

    function new(string name = "receiver_cfg");
        super.new(name);
        clks_per_bit             = SPEC_CLKS_PER_BIT;
        rtl_default_clks_per_bit = SPEC_CLKS_PER_BIT;
    endfunction
endclass
