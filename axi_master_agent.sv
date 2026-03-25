class axi_master_agent extends uvm_agent;
  `uvm_component_utils(axi_master_agent)

  axi_master_sequencer sqr;
  axi_master_driver    drv;
  axi_master_monitor   mon;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    sqr = axi_master_sequencer::type_id::create("sqr", this);
    drv = axi_master_driver   ::type_id::create("drv", this);
    mon = axi_master_monitor  ::type_id::create("mon", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    drv.seq_item_port.connect(sqr.seq_item_export);
  endfunction
endclass
