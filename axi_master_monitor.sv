class axi_master_monitor extends uvm_component;
  `uvm_component_utils(axi_master_monitor)

  virtual axi_if vif;
  uvm_analysis_port #(axi_txn) txn_ap;

  axi_txn pending_aw_q[$];
  axi_txn pending_w_q[$];
  axi_txn pending_ar_q_by_id[16][$];
  axi_txn active_r_by_id[16];

  function new(string name, uvm_component parent);
    super.new(name, parent);
    txn_ap = new("txn_ap", this);
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
    join
  endtask

  task collect_aw();
    axi_txn tr;
    forever begin
      @(vif.mon_cb);
      if (vif.mon_cb.AWVALID && vif.mon_cb.AWREADY) begin
        tr = axi_txn::type_id::create("aw_tr");
        tr.is_write = 1'b1;
        tr.id       = vif.mon_cb.AWID;
        tr.addr     = vif.mon_cb.AWADDR;
        tr.len      = vif.mon_cb.AWLEN;
        tr.size     = vif.mon_cb.AWSIZE;
        tr.burst    = vif.mon_cb.AWBURST;
        pending_aw_q.push_back(tr);
      end
    end
  endtask

  task collect_w();
    axi_txn tr;
    forever begin
      wait (pending_aw_q.size() > 0);
      tr = axi_txn::type_id::create("w_tr");
      tr.copy(pending_aw_q[0]);
      tr.data_q.delete();
      forever begin
        @(vif.mon_cb);
        if (vif.mon_cb.WVALID && vif.mon_cb.WREADY) begin
          tr.data_q.push_back(vif.mon_cb.WDATA);
          if (vif.mon_cb.WLAST) begin
            void'(pending_aw_q.pop_front());
            pending_w_q.push_back(tr);
            break;
          end
        end
      end
    end
  endtask

  task collect_b();
    axi_txn tr;
    forever begin
      @(vif.mon_cb);
      if (vif.mon_cb.BVALID && vif.mon_cb.BREADY) begin
        if (pending_w_q.size() == 0) begin
          `uvm_warning(get_type_name(), "B seen with no pending write txn")
        end
        else begin
          tr = pending_w_q.pop_front();
          tr.resp_q.push_back(vif.mon_cb.BRESP);
          txn_ap.write(tr);
          `uvm_info(get_type_name(),
                    $sformatf("MON WRITE complete id=%0d addr=0x%08h beats=%0d", tr.id, tr.addr, tr.num_beats()),
                    UVM_HIGH)
        end
      end
    end
  endtask

  task collect_ar();
    axi_txn tr;
    forever begin
      @(vif.mon_cb);
      if (vif.mon_cb.ARVALID && vif.mon_cb.ARREADY) begin
        tr = axi_txn::type_id::create("ar_tr");
        tr.is_write = 1'b0;
        tr.id       = vif.mon_cb.ARID;
        tr.addr     = vif.mon_cb.ARADDR;
        tr.len      = vif.mon_cb.ARLEN;
        tr.size     = vif.mon_cb.ARSIZE;
        tr.burst    = vif.mon_cb.ARBURST;
        pending_ar_q_by_id[int'(tr.id)].push_back(tr);
      end
    end
  endtask

  task collect_r();
    axi_txn tr;
    int idx;
    forever begin
      @(vif.mon_cb);
      if (vif.mon_cb.RVALID && vif.mon_cb.RREADY) begin
        idx = int'(vif.mon_cb.RID);
        if (active_r_by_id[idx] == null) begin
          if (pending_ar_q_by_id[idx].size() == 0) begin
            `uvm_warning(get_type_name(), $sformatf("R seen for RID=%0d with no pending AR", idx))
          end
          else begin
            active_r_by_id[idx] = pending_ar_q_by_id[idx].pop_front();
            // make sure rdata_q and resp_q are empty before filling in data in coming if statement
            active_r_by_id[idx].rdata_q.delete();
            active_r_by_id[idx].resp_q.delete();
          end
        end

        if (active_r_by_id[idx] != null) begin
          active_r_by_id[idx].rdata_q.push_back(vif.mon_cb.RDATA);
          active_r_by_id[idx].resp_q.push_back(vif.mon_cb.RRESP);
          if (vif.mon_cb.RLAST) begin
            tr = active_r_by_id[idx];
            txn_ap.write(tr);
            `uvm_info(get_type_name(),
                      $sformatf("MON READ complete id=%0d addr=0x%08h beats=%0d", tr.id, tr.addr, tr.rdata_q.size()),
                      UVM_HIGH)
            active_r_by_id[idx] = null;
            // burst is now complete, so the monitor is ready for the next read response with the same ID.
          end
        end
      end
    end
  endtask
endclass
