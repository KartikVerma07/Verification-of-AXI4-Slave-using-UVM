// Test 1
class axi_basic_test extends axi_base_test;
  `uvm_component_utils(axi_basic_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    uvm_config_db#(string)::set(this, "env.sb", "scenario_name", "BASIC");
  endfunction

  task run_phase(uvm_phase phase);
    axi_basic_vseq vseq;
    phase.raise_objection(this);
    vseq = axi_basic_vseq::type_id::create("vseq");
    vseq.start(env.vseqr);
    #500ns;
    phase.drop_objection(this);
  endtask
endclass


// Test 2
class axi_burst_test extends axi_base_test;
  `uvm_component_utils(axi_burst_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    uvm_config_db#(string)::set(this, "env.sb", "scenario_name", "BURST");
  endfunction

  task run_phase(uvm_phase phase);
    axi_burst_vseq vseq;
    phase.raise_objection(this);
    vseq = axi_burst_vseq::type_id::create("vseq");
    vseq.start(env.vseqr);
    #1000ns;
    phase.drop_objection(this);
  endtask
endclass


// Test 3
class axi_multi_outstanding_test extends axi_base_test;
  `uvm_component_utils(axi_multi_outstanding_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    uvm_config_db#(string)::set(this, "env.sb", "scenario_name", "MULTI_OUTSTANDING");
  endfunction

  task run_phase(uvm_phase phase);
    axi_multi_outstanding_vseq vseq;
    phase.raise_objection(this);
    vseq = axi_multi_outstanding_vseq::type_id::create("vseq");
    vseq.start(env.vseqr);
    #1200ns;
    phase.drop_objection(this);
  endtask
endclass


// Test 4
class axi_ooo_read_test extends axi_base_test;
  `uvm_component_utils(axi_ooo_read_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    uvm_config_db#(string)::set(this, "env.sb", "scenario_name", "OOO_READ");
  endfunction

  task run_phase(uvm_phase phase);
    axi_ooo_read_vseq vseq;
    phase.raise_objection(this);
    vseq = axi_ooo_read_vseq::type_id::create("vseq");
    vseq.start(env.vseqr);
    #1800ns;
    phase.drop_objection(this);
  endtask
endclass
	/*
// Regression Test for Coverage
class axi_regression_test extends axi_base_test;
  `uvm_component_utils(axi_regression_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    uvm_config_db#(string)::set(this, "env.sb", "scenario_name", "REGRESSION");
  endfunction

  task run_phase(uvm_phase phase);
    axi_regression_vseq vseq;
    phase.raise_objection(this);

    vseq = axi_regression_vseq::type_id::create("vseq");
    vseq.start(env.vseqr);

    #3000ns;
    phase.drop_objection(this);
  endtask
endclass
	*/