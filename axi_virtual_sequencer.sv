class axi_virtual_sequencer extends uvm_sequencer;
  `uvm_component_utils(axi_virtual_sequencer)

  axi_master_sequencer m_seqr;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
endclass
