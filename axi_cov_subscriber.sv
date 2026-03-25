class axi_cov_subscriber extends uvm_subscriber #(axi_txn);
  `uvm_component_utils(axi_cov_subscriber)

  covergroup axi_cg with function sample(
    bit        is_write,
    bit [3:0]  id,
    int unsigned beats,
    bit [31:0] addr
  );
    option.per_instance = 1;

    cp_dir : coverpoint is_write {
      bins write = {1};
      bins read  = {0};
    }

    cp_beats : coverpoint beats {
      bins single = {1};
      bins burst4 = {4};
      bins burst8 = {8};
      bins other  = default;
    }

    cp_id : coverpoint id {
      bins low_ids  = {[0:3]};
      bins mid_ids  = {[4:7]};
      bins high_ids = {[8:15]};
    }

    cp_addr_region : coverpoint addr[15:12] {
      bins low  = {[0:3]};
      bins high  = {[4:15]};
    }

    cx_dir_beats : cross cp_dir, cp_beats;
    cx_id_beats  : cross cp_id, cp_beats;
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    axi_cg = new();
  endfunction

  function void write(axi_txn t);
    axi_cg.sample(
      t.is_write,
      t.id,
      t.num_beats(),
      t.addr
    );
  endfunction
  
  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("COV",
              $sformatf("AXI functional coverage = %0.2f%%",
                        axi_cg.get_inst_coverage()),
              UVM_NONE)
  endfunction

endclass