`uvm_analysis_imp_decl(_aw)
`uvm_analysis_imp_decl(_w)
`uvm_analysis_imp_decl(_b)
`uvm_analysis_imp_decl(_ar)
`uvm_analysis_imp_decl(_r)

class axi_scoreboard extends uvm_component;
  `uvm_component_utils(axi_scoreboard)

  uvm_analysis_imp_aw #(axi_txn, axi_scoreboard) aw_imp;
  uvm_analysis_imp_w  #(axi_txn, axi_scoreboard) w_imp;
  uvm_analysis_imp_b  #(axi_txn, axi_scoreboard) b_imp;
  uvm_analysis_imp_ar #(axi_txn, axi_scoreboard) ar_imp;
  uvm_analysis_imp_r  #(axi_txn, axi_scoreboard) r_imp;

  // per-ID queues for address side and assembled transactions(ID needed coz B response can be out of order)
  axi_txn pending_aw_by_id[int][$];
  axi_txn assembled_wr_by_id[int][$];
  // per-ID queue for out of order read transactions
  axi_txn pending_ar_by_id[int][$];

  // We know AXI4 has no WID, so order is sufficent for merging W and AW (protocol adherence)
  axi_txn pending_w_q[$];

  // AW issue order, tells us which ID owns the next W burst
  int aw_order_q[$];

  byte unsigned ref_mem[int unsigned];
  string        scenario_name = "UNSPECIFIED";

  function new(string name, uvm_component parent);
    super.new(name, parent);
    aw_imp = new("aw_imp", this);
    w_imp  = new("w_imp",  this);
    b_imp  = new("b_imp",  this);
    ar_imp = new("ar_imp", this);
    r_imp  = new("r_imp",  this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    void'(uvm_config_db#(string)::get(this, "", "scenario_name", scenario_name));
  endfunction

  // ------------------------------------------------------------------ AW
  function void write_aw(axi_txn tr);
    int id = int'(tr.id);
    pending_aw_by_id[id].push_back(tr);
    aw_order_q.push_back(id);   // record issue order BEFORE trying to merge
    `uvm_info("SB",
              $sformatf("[%s] AW queued id=%0d addr=0x%08h aw_order_q size=%0d",
                        scenario_name, id, tr.addr, aw_order_q.size()),
              UVM_HIGH)
    try_merge_w_to_aw();
  endfunction

  // ------------------------------------------------------------------ W
  function void write_w(axi_txn tr);
    pending_w_q.push_back(tr);
    `uvm_info("SB",
              $sformatf("[%s] W queued beats=%0d pending_w_q size=%0d",
                        scenario_name, tr.data_q.size(), pending_w_q.size()),
              UVM_HIGH)
    try_merge_w_to_aw();
  endfunction

  // Match oldest W in global FIFO to oldest AW by issue order.
  // AXI4 guarantees W order follows AW order on a single master.
  function void try_merge_w_to_aw();
    int id;
    if (aw_order_q.size() == 0 || pending_w_q.size() == 0) return;
    id = aw_order_q.pop_front();
    begin
      axi_txn aw_tr = pending_aw_by_id[id].pop_front();
      axi_txn w_tr  = pending_w_q.pop_front();
      aw_tr.data_q  = w_tr.data_q;
      assembled_wr_by_id[id].push_back(aw_tr);
      `uvm_info("SB",
                $sformatf("[%s] AW+W merged id=%0d addr=0x%08h beats=%0d",
                          scenario_name, id, aw_tr.addr, aw_tr.data_q.size()),
                UVM_HIGH)
    end
  endfunction

  // ------------------------------------------------------------------ B
  function void write_b(axi_txn tr);
    int id = int'(tr.id);
    if (!assembled_wr_by_id.exists(id) || assembled_wr_by_id[id].size() == 0) begin
      `uvm_error("SB",
                 $sformatf("[%s] B resp id=%0d with no assembled write txn",
                           scenario_name, id))
      return;
    end
    begin
      axi_txn wr_tr = assembled_wr_by_id[id].pop_front();
      wr_tr.resp_q  = tr.resp_q;
      if (tr.resp_q[0] != 2'b00)
        `uvm_error("SB",
                   $sformatf("[%s] BAD BRESP id=%0d resp=0x%0h",
                             scenario_name, id, tr.resp_q[0]))
      else
        commit_write(wr_tr);
    end
  endfunction

  function void commit_write(axi_txn tr);
    int unsigned step = (1 << tr.size);
    for (int i = 0; i < tr.data_q.size(); i++) begin
      int unsigned beat_addr = tr.addr + i * step;
      write_mem_word(beat_addr, tr.data_q[i]);
      `uvm_info("SB",
                $sformatf("[%s] WRITE id=%0d beat_addr=0x%08h data=0x%08h",
                          scenario_name, tr.id, beat_addr, tr.data_q[i]),
                UVM_MEDIUM)
    end
  endfunction

  // ------------------------------------------------------------------ AR
  function void write_ar(axi_txn tr);
    int id = int'(tr.id);
    pending_ar_by_id[id].push_back(tr);
  endfunction

  // ------------------------------------------------------------------ R
  function void write_r(axi_txn tr);
    int id = int'(tr.id);
    if (!pending_ar_by_id.exists(id) || pending_ar_by_id[id].size() == 0) begin
      `uvm_error("SB",
                 $sformatf("[%s] R data id=%0d with no pending AR",
                           scenario_name, id))
      return;
    end
    begin
      axi_txn ar_tr = pending_ar_by_id[id].pop_front();
      ar_tr.rdata_q = tr.rdata_q;
      ar_tr.resp_q  = tr.resp_q;
      check_read(ar_tr);
    end
  endfunction

  function void check_read(axi_txn tr);
    int unsigned step = (1 << tr.size);
    for (int i = 0; i < tr.rdata_q.size(); i++) begin
      int unsigned beat_addr = tr.addr + i * step;
      bit [31:0]   exp_data  = read_mem_word(beat_addr);
      if (tr.rdata_q[i] !== exp_data)
        `uvm_error("SB",
                   $sformatf("[%s] READ MISMATCH id=%0d beat_addr=0x%08h exp=0x%08h got=0x%08h",
                             scenario_name, tr.id, beat_addr, exp_data, tr.rdata_q[i]))
      else
        `uvm_info("SB",
                  $sformatf("[%s] READ MATCH id=%0d beat_addr=0x%08h data=0x%08h",
                            scenario_name, tr.id, beat_addr, tr.rdata_q[i]),
                  UVM_MEDIUM)
    end
  endfunction

  // ------------------------------------------------------------------ helpers
  function void write_mem_word(input int unsigned addr, input bit [31:0] data);
    for (int b = 0; b < 4; b++)
      ref_mem[addr + b] = data[b*8 +: 8];
  endfunction

  function bit [31:0] read_mem_word(input int unsigned addr);
    bit [31:0] data = '0;
    for (int b = 0; b < 4; b++)
      data[b*8 +: 8] = ref_mem.exists(addr+b) ? ref_mem[addr+b] : 8'h00;
    return data;
  endfunction

  // ------------------------------------------------------------------ drain check
  function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    foreach (pending_aw_by_id[id])
      if (pending_aw_by_id[id].size())
        `uvm_error("SB", $sformatf("[%s] %0d pending AW(s) for id=%0d never got W",
                                   scenario_name, pending_aw_by_id[id].size(), id))
    if (pending_w_q.size())
      `uvm_error("SB", $sformatf("[%s] %0d pending W(s) never got AW",
                                 scenario_name, pending_w_q.size()))
    foreach (assembled_wr_by_id[id])
      if (assembled_wr_by_id[id].size())
        `uvm_error("SB", $sformatf("[%s] %0d write txn(s) for id=%0d never got B resp",
                                   scenario_name, assembled_wr_by_id[id].size(), id))
    foreach (pending_ar_by_id[id])
      if (pending_ar_by_id[id].size())
        `uvm_error("SB", $sformatf("[%s] %0d pending AR(s) for id=%0d never got R data",
                                   scenario_name, pending_ar_by_id[id].size(), id))
    if (aw_order_q.size())
      `uvm_error("SB", $sformatf("[%s] %0d AW(s) in order queue never got W",
                                 scenario_name, aw_order_q.size()))
  endfunction

endclass