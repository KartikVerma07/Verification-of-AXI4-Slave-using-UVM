class axi_env extends uvm_env;
  `uvm_component_utils(axi_env)

  axi_master_agent       m_agent;
  axi_scoreboard         sb;
  axi_cov_subscriber     cov;
  axi_virtual_sequencer  vseqr;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    m_agent = axi_master_agent      ::type_id::create("m_agent", this);
    sb      = axi_scoreboard        ::type_id::create("sb", this);
    cov     = axi_cov_subscriber ::type_id::create("cov", this);
    vseqr   = axi_virtual_sequencer ::type_id::create("vseqr", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    m_agent.mon.txn_ap.connect(sb.txn_imp);
    m_agent.mon.txn_ap.connect(cov.analysis_export);
    vseqr.m_seqr = m_agent.sqr;
  endfunction
endclass
