class axi_master_monitor extends uvm_component;
  `uvm_component_utils(axi_master_monitor)

  virtual axi_if vif;

  uvm_analysis_port #(axi_txn) aw_ap;
  uvm_analysis_port #(axi_txn) w_ap;
  uvm_analysis_port #(axi_txn) b_ap;
  uvm_analysis_port #(axi_txn) ar_ap;
  uvm_analysis_port #(axi_txn) r_ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    aw_ap = new("aw_ap", this);
    w_ap  = new("w_ap",  this);
    b_ap  = new("b_ap",  this);
    ar_ap = new("ar_ap", this);
    r_ap  = new("r_ap",  this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual axi_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", $sformatf("%s: vif not set", get_full_name()))
  endfunction

  task run_phase(uvm_phase phase);
    fork
      collect_aw();
      collect_w();
      collect_b();
      collect_ar();
      collect_r();
    join_none
  endtask

  task collect_aw();
    axi_txn tr;
    forever begin
      @(vif.mon_cb);
      if (vif.mon_cb.AWVALID && vif.mon_cb.AWREADY) begin
        tr          = axi_txn::type_id::create("aw_tr");
        tr.is_write = 1'b1;
        tr.id       = vif.mon_cb.AWID;
        tr.addr     = vif.mon_cb.AWADDR;
        tr.len      = vif.mon_cb.AWLEN;
        tr.size     = vif.mon_cb.AWSIZE;
        tr.burst    = vif.mon_cb.AWBURST;
        aw_ap.write(tr);
        `uvm_info(get_type_name(),
                  $sformatf("MON AW id=%0d addr=0x%08h len=%0d", tr.id, tr.addr, tr.len),
                  UVM_HIGH)
      end
    end
  endtask

  // AXI4 has no WID, W bursts are matched to AW in order globally
  task collect_w();
    axi_txn tr;
    forever begin
      @(vif.mon_cb);
      if (vif.mon_cb.WVALID && vif.mon_cb.WREADY) begin
        tr          = axi_txn::type_id::create("w_tr");
        tr.is_write = 1'b1;
        tr.data_q.push_back(vif.mon_cb.WDATA);
        while (!vif.mon_cb.WLAST) begin
          @(vif.mon_cb);
          if (vif.mon_cb.WVALID && vif.mon_cb.WREADY)
            tr.data_q.push_back(vif.mon_cb.WDATA);
        end
        w_ap.write(tr);
        `uvm_info(get_type_name(),
                  $sformatf("MON W beats=%0d", tr.data_q.size()),
                  UVM_HIGH)
      end
    end
  endtask

  task collect_b();
    axi_txn tr;
    forever begin
      @(vif.mon_cb);
      if (vif.mon_cb.BVALID && vif.mon_cb.BREADY) begin
        tr          = axi_txn::type_id::create("b_tr");
        tr.is_write = 1'b1;
        tr.id       = vif.mon_cb.BID;
        tr.resp_q.push_back(vif.mon_cb.BRESP);
        b_ap.write(tr);
        `uvm_info(get_type_name(),
                  $sformatf("MON B id=%0d resp=0x%0h", tr.id, vif.mon_cb.BRESP),
                  UVM_HIGH)
      end
    end
  endtask

  task collect_ar();
    axi_txn tr;
    forever begin
      @(vif.mon_cb);
      if (vif.mon_cb.ARVALID && vif.mon_cb.ARREADY) begin
        tr          = axi_txn::type_id::create("ar_tr");
        tr.is_write = 1'b0;
        tr.id       = vif.mon_cb.ARID;
        tr.addr     = vif.mon_cb.ARADDR;
        tr.len      = vif.mon_cb.ARLEN;
        tr.size     = vif.mon_cb.ARSIZE;
        tr.burst    = vif.mon_cb.ARBURST;
        ar_ap.write(tr);
        `uvm_info(get_type_name(),
                  $sformatf("MON AR id=%0d addr=0x%08h len=%0d", tr.id, tr.addr, tr.len),
                  UVM_HIGH)
      end
    end
  endtask

  task collect_r();
    axi_txn active_r[int];
    int idx;
    forever begin
      @(vif.mon_cb);
      if (vif.mon_cb.RVALID && vif.mon_cb.RREADY) begin
        idx = int'(vif.mon_cb.RID);
        if (!active_r.exists(idx)) begin
          active_r[idx]          = axi_txn::type_id::create("r_tr");
          active_r[idx].is_write = 1'b0;
          active_r[idx].id       = vif.mon_cb.RID;
        end
        active_r[idx].rdata_q.push_back(vif.mon_cb.RDATA);
        active_r[idx].resp_q.push_back(vif.mon_cb.RRESP);
        if (vif.mon_cb.RLAST) begin
          r_ap.write(active_r[idx]);
          `uvm_info(get_type_name(),
                    $sformatf("MON R id=%0d beats=%0d", idx, active_r[idx].rdata_q.size()),
                    UVM_HIGH)
          active_r.delete(idx);
        end
      end
    end
  endtask

endclass