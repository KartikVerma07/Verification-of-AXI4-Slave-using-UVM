class axi_master_driver extends uvm_driver #(axi_txn);
  `uvm_component_utils(axi_master_driver)

  virtual axi_if vif;

  axi_txn aw_q[$];
  axi_txn w_q[$];
  axi_txn ar_q[$];

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual axi_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", $sformatf("%s: vif not set", get_full_name()))
  endfunction

  task reset_signals();
    vif.drv_cb.AWID    <= '0;
    vif.drv_cb.AWADDR  <= '0;
    vif.drv_cb.AWLEN   <= '0;
    vif.drv_cb.AWSIZE  <= '0;
    vif.drv_cb.AWBURST <= '0;
    vif.drv_cb.AWVALID <= 1'b0;

    vif.drv_cb.WDATA   <= '0;
    vif.drv_cb.WLAST   <= 1'b0;
    vif.drv_cb.WVALID  <= 1'b0;

    vif.drv_cb.BREADY  <= 1'b1;

    vif.drv_cb.ARID    <= '0;
    vif.drv_cb.ARADDR  <= '0;
    vif.drv_cb.ARLEN   <= '0;
    vif.drv_cb.ARSIZE  <= '0;
    vif.drv_cb.ARBURST <= '0;
    vif.drv_cb.ARVALID <= 1'b0;

    vif.drv_cb.RREADY  <= 1'b1;
  endtask

  task run_phase(uvm_phase phase);
    reset_signals();
    wait(vif.ARESETn === 1'b1);

    fork
      get_items_thread();
      aw_thread();
      w_thread();
      ar_thread();
      b_thread();
      r_thread();
    join_none
  endtask

  task get_items_thread();
    axi_txn tr;
    axi_txn tr_cpy;
    forever begin
      seq_item_port.get_next_item(tr);
      if (tr.is_write) begin
        tr_cpy = axi_txn::type_id::create("tr_aw");
        tr_cpy.copy(tr);
        aw_q.push_back(tr_cpy);
        tr_cpy = axi_txn::type_id::create("tr_w");
        tr_cpy.copy(tr);
        w_q.push_back(tr_cpy);
        `uvm_info(get_type_name(),
                  $sformatf("DRV queued WRITE id=%0d addr=0x%08h len=%0d beats=%0d aw_q=%0d w_q=%0d",
                            tr.id, tr.addr, tr.len, tr.num_beats(), aw_q.size(), w_q.size()),
                  UVM_MEDIUM)
      end
      else begin
        tr_cpy = axi_txn::type_id::create("tr_ar");
        tr_cpy.copy(tr);
        ar_q.push_back(tr_cpy);
        `uvm_info(get_type_name(),
                  $sformatf("DRV queued READ  id=%0d addr=0x%08h len=%0d beats=%0d ar_q=%0d",
                            tr.id, tr.addr, tr.len, tr.num_beats(), ar_q.size()),
                  UVM_MEDIUM)
      end
      seq_item_port.item_done();
    end
  endtask

  task aw_thread();
    axi_txn tr;
    forever begin
      wait (aw_q.size() > 0);
      tr = aw_q.pop_front();
	  repeat ($urandom_range(0,2)) @(vif.drv_cb);
      vif.drv_cb.AWID    <= tr.id;
      vif.drv_cb.AWADDR  <= tr.addr;
      vif.drv_cb.AWLEN   <= tr.len;
      vif.drv_cb.AWSIZE  <= tr.size;
      vif.drv_cb.AWBURST <= tr.burst;
      vif.drv_cb.AWVALID <= 1'b1;
      do @(vif.drv_cb); while (!vif.drv_cb.AWREADY);
      vif.drv_cb.AWVALID <= 1'b0;
      `uvm_info(get_type_name(),
                $sformatf("DRV AW handshake id=%0d addr=0x%08h len=%0d", tr.id, tr.addr, tr.len),
                UVM_HIGH)
    end
  endtask

  task w_thread();
    axi_txn tr;
    int i;
    forever begin
      wait (w_q.size() > 0);
      tr = w_q.pop_front();
      repeat ($urandom_range(0,2)) @(vif.drv_cb);
      for (i = 0; i < tr.num_beats(); i++) begin
        vif.drv_cb.WDATA  <= tr.data_q[i];
        vif.drv_cb.WLAST  <= (i == tr.num_beats()-1);
        vif.drv_cb.WVALID <= 1'b1;
        do @(vif.drv_cb); while (!vif.drv_cb.WREADY);
      end
      vif.drv_cb.WVALID <= 1'b0;
      vif.drv_cb.WLAST  <= 1'b0;
      `uvm_info(get_type_name(),
                $sformatf("DRV W burst complete id=%0d beats=%0d", tr.id, tr.num_beats()),
                UVM_HIGH)
    end
  endtask

  task ar_thread();
    axi_txn tr;
    forever begin
      wait (ar_q.size() > 0);
      tr = ar_q.pop_front();
      repeat ($urandom_range(0,2)) @(vif.drv_cb);
      vif.drv_cb.ARID    <= tr.id;
      vif.drv_cb.ARADDR  <= tr.addr;
      vif.drv_cb.ARLEN   <= tr.len;
      vif.drv_cb.ARSIZE  <= tr.size;
      vif.drv_cb.ARBURST <= tr.burst;
      vif.drv_cb.ARVALID <= 1'b1;
      do @(vif.drv_cb); while (!vif.drv_cb.ARREADY);
      vif.drv_cb.ARVALID <= 1'b0;
      `uvm_info(get_type_name(),
                $sformatf("DRV AR handshake id=%0d addr=0x%08h len=%0d", tr.id, tr.addr, tr.len),
                UVM_HIGH)
    end
  endtask

  task b_thread();
    forever begin
      @(vif.drv_cb);
      vif.drv_cb.BREADY <= 1'b1;
      if (vif.drv_cb.BVALID) begin
        `uvm_info(get_type_name(),
                  $sformatf("DRV saw B id=%0d resp=0x%0h", vif.drv_cb.BID, vif.drv_cb.BRESP),
                  UVM_HIGH)
      end
    end
  endtask

  task r_thread();
    forever begin
      @(vif.drv_cb);
      vif.drv_cb.RREADY <= 1'b1;
      if (vif.drv_cb.RVALID) begin
        `uvm_info(get_type_name(),
                  $sformatf("DRV saw R id=%0d data=0x%08h resp=0x%0h last=%0b",
                            vif.drv_cb.RID, vif.drv_cb.RDATA, vif.drv_cb.RRESP, vif.drv_cb.RLAST),
                  UVM_HIGH)
      end
    end
  endtask
endclass
