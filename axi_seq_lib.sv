class axi_write_burst_seq extends uvm_sequence #(axi_txn);
  `uvm_object_utils(axi_write_burst_seq)

  bit [3:0]  req_id  = 0;
  bit [31:0] addr    = 32'h0;
  bit [7:0]  len     = 0;
  bit [2:0]  size    = 3'd2;

  function new(string name = "axi_write_burst_seq");
    super.new(name);
  endfunction

  task body();
    axi_txn tr;
    tr = axi_txn::type_id::create("tr");

    start_item(tr);
    if (!tr.randomize() with {
          is_write == 1;
          id       == local::req_id;
          addr     == local::addr;
          len      == local::len;
          size     == local::size;
          burst    == 2'b01; // INCR
        })
      `uvm_fatal("RANDFAIL", "axi_write_burst_seq randomization failed")
    finish_item(tr);
  endtask
endclass


class axi_read_burst_seq extends uvm_sequence #(axi_txn);
  `uvm_object_utils(axi_read_burst_seq)

  bit [3:0]  req_id  = 0;
  bit [31:0] addr    = 32'h0;
  bit [7:0]  len     = 0;
  bit [2:0]  size    = 3'd2;

  function new(string name = "axi_read_burst_seq");
    super.new(name);
  endfunction

  task body();
    axi_txn tr;
    tr = axi_txn::type_id::create("tr");

    start_item(tr);
    if (!tr.randomize() with {
          is_write == 0;
          id       == local::req_id;
          addr     == local::addr;
          len      == local::len;
          size     == local::size;
          burst    == 2'b01; // INCR
        })
      `uvm_fatal("RANDFAIL", "axi_read_burst_seq randomization failed")
    finish_item(tr);
  endtask
endclass


// ------------------------------------------------------------
// VSEQ 1 : BASIC
// One 4-beat write burst + matching 4-beat read burst
// ------------------------------------------------------------
class axi_basic_vseq extends uvm_sequence;
  `uvm_object_utils(axi_basic_vseq)
  `uvm_declare_p_sequencer(axi_virtual_sequencer)

  function new(string name = "axi_basic_vseq");
    super.new(name);
  endfunction

  task body();
    axi_write_burst_seq wseq;
    axi_read_burst_seq  rseq;

    `uvm_info(get_type_name(), "Starting basic burst vseq", UVM_LOW)

    wseq = axi_write_burst_seq::type_id::create("wseq");
    wseq.req_id = 4'd1;
    wseq.addr   = 32'h0000_0000;
    wseq.len    = 8'd3;   // 4 beats
    wseq.size   = 3'd2;   // 4 bytes/beat
    wseq.start(p_sequencer.m_seqr);

   // #100ns;

    rseq = axi_read_burst_seq::type_id::create("rseq");
    rseq.req_id = 4'd1;
    rseq.addr   = 32'h0000_0000;
    rseq.len    = 8'd3;
    rseq.size   = 3'd2;
    rseq.start(p_sequencer.m_seqr);
  endtask
endclass


// ------------------------------------------------------------
// VSEQ 2 : BURST
// Multiple burst writes and reads with different lengths
// ------------------------------------------------------------
class axi_burst_vseq extends uvm_sequence;
  `uvm_object_utils(axi_burst_vseq)
  `uvm_declare_p_sequencer(axi_virtual_sequencer)

  function new(string name = "axi_burst_vseq");
    super.new(name);
  endfunction

  task body();
    axi_write_burst_seq w0, w1, w2;
    axi_read_burst_seq  r0, r1, r2;

    `uvm_info(get_type_name(), "Starting burst vseq: 1-beat, 4-beat, 8-beat", UVM_LOW)

    // ------------------------------------------------
    // WRITE 1 : single beat  (len=0)  -> low region
    // ------------------------------------------------
    w0 = axi_write_burst_seq::type_id::create("w0");
    w0.req_id = 4'd1;
    w0.addr   = 32'h0000_0100;
    w0.len    = 8'd0;   // 1 beat
    w0.size   = 3'd2;   // 4 bytes/beat
    w0.start(p_sequencer.m_seqr);

    // ------------------------------------------------
    // WRITE 2 : 4-beat burst (len=3) -> mid region
    // ------------------------------------------------
    w1 = axi_write_burst_seq::type_id::create("w1");
    w1.req_id = 4'd4;
    w1.addr   = 32'h0000_5000;
    w1.len    = 8'd3;   // 4 beats
    w1.size   = 3'd2;
    w1.start(p_sequencer.m_seqr);

    // ------------------------------------------------
    // WRITE 3 : 8-beat burst (len=7) -> high region
    // ------------------------------------------------
    w2 = axi_write_burst_seq::type_id::create("w2");
    w2.req_id = 4'd8;
    w2.addr   = 32'h0000_A000;
    w2.len    = 8'd7;   // 8 beats
    w2.size   = 3'd2;
    w2.start(p_sequencer.m_seqr);

    #200ns;

    // ------------------------------------------------
    // Read back in same order
    // ------------------------------------------------
    r0 = axi_read_burst_seq::type_id::create("r0");
    r0.req_id = 4'd1;
    r0.addr   = 32'h0000_0100;
    r0.len    = 8'd0;   // 1 beat
    r0.size   = 3'd2;
    r0.start(p_sequencer.m_seqr);

    r1 = axi_read_burst_seq::type_id::create("r1");
    r1.req_id = 4'd4;
    r1.addr   = 32'h0000_5000;
    r1.len    = 8'd3;   // 4 beats
    r1.size   = 3'd2;
    r1.start(p_sequencer.m_seqr);

    r2 = axi_read_burst_seq::type_id::create("r2");
    r2.req_id = 4'd8;
    r2.addr   = 32'h0000_A000;
    r2.len    = 8'd7;   // 8 beats
    r2.size   = 3'd2;
    r2.start(p_sequencer.m_seqr);
  endtask
endclass


// ------------------------------------------------------------
// VSEQ 3 : MULTI OUTSTANDING
// Preload memory, then launch multiple reads close together
// ------------------------------------------------------------
class axi_multi_outstanding_vseq extends uvm_sequence;
  `uvm_object_utils(axi_multi_outstanding_vseq)
  `uvm_declare_p_sequencer(axi_virtual_sequencer)

  function new(string name = "axi_multi_outstanding_vseq");
    super.new(name);
  endfunction

  task body();
    axi_write_burst_seq w0, w1;
    axi_read_burst_seq  r0, r1, r2;

    `uvm_info(get_type_name(), "Starting multi-outstanding vseq", UVM_LOW)

    // preload region 0x200
    w0 = axi_write_burst_seq::type_id::create("w0");
    w0.req_id = 4'd1;
    w0.addr   = 32'h0000_0200;
    w0.len    = 8'd3;   // 4 beats
    w0.size   = 3'd2;
    w0.start(p_sequencer.m_seqr);

    // preload region 0x300
    w1 = axi_write_burst_seq::type_id::create("w1");
    w1.req_id = 4'd2;
    w1.addr   = 32'h0000_0300;
    w1.len    = 8'd3;   // 4 beats
    w1.size   = 3'd2;
    w1.start(p_sequencer.m_seqr);

    #150ns;

    // launch multiple reads close together
    r0 = axi_read_burst_seq::type_id::create("r0");
    r1 = axi_read_burst_seq::type_id::create("r1");
    r2 = axi_read_burst_seq::type_id::create("r2");

    r0.req_id = 4'd1;
    r0.addr   = 32'h0000_0200;
    r0.len    = 8'd3;
    r0.size   = 3'd2;

    r1.req_id = 4'd2;
    r1.addr   = 32'h0000_0300;
    r1.len    = 8'd3;
    r1.size   = 3'd2;

    r2.req_id = 4'd3;
    r2.addr   = 32'h0000_0400; // unwritten region
    r2.len    = 8'd3;
    r2.size   = 3'd2;

    fork
      r0.start(p_sequencer.m_seqr);
      r1.start(p_sequencer.m_seqr);
      r2.start(p_sequencer.m_seqr);
    join
  endtask
endclass


// ------------------------------------------------------------
// VSEQ 4 : OOO READ
// Preload 3 regions, then issue 3 reads with different IDs
// DUT may return them out-of-order across IDs
// ------------------------------------------------------------
class axi_ooo_read_vseq extends uvm_sequence;
  `uvm_object_utils(axi_ooo_read_vseq)
  `uvm_declare_p_sequencer(axi_virtual_sequencer)

  localparam int NUM_REQS = 12;

  function new(string name = "axi_ooo_read_vseq");
    super.new(name);
  endfunction

  task body();
    axi_write_burst_seq w[NUM_REQS];
    axi_read_burst_seq  r[NUM_REQS];
    bit [31:0]          base_addr[NUM_REQS];
    int i;

    `uvm_info(get_type_name(),
              $sformatf("Starting OOO read vseq with %0d IDs (0 to %0d)", NUM_REQS, NUM_REQS-1),
              UVM_LOW)

    // ----------------------------
    // Address map per ID
    // ID 0  -> 0x1000
    // ID 1  -> 0x1100
    // ...
    // ID 11 -> 0x1B00
    // ----------------------------
    for (i = 0; i < NUM_REQS; i++) begin
      base_addr[i] = 32'h0000_1000 + (i * 32'h100);
    end

    // ----------------------------
    // Preload memory for all IDs  (Write bursts)
    // ----------------------------
    for (i = 0; i < NUM_REQS; i++) begin
      w[i] = axi_write_burst_seq::type_id::create($sformatf("w_id_%0d", i));
      w[i].req_id = i[3:0];
      w[i].addr   = base_addr[i];
      w[i].len    = 8'd3;   // 4 beats
      w[i].size   = 3'd2;   // 4 bytes/beat
      w[i].start(p_sequencer.m_seqr);
    end

    #400ns;

    // ----------------------------
    // Create all reads
    // ----------------------------
    for (i = 0; i < NUM_REQS; i++) begin
      r[i] = axi_read_burst_seq::type_id::create($sformatf("r_id_%0d", i));
      r[i].req_id = i[3:0];
      r[i].addr   = base_addr[i];
      r[i].len    = 8'd3;   // 4 beats
      r[i].size   = 3'd2;
    end

    // ----------------------------
    // Launch all reads close together
    // to maximize OOO opportunities
    // ----------------------------
    for (i = 0; i < NUM_REQS; i++) begin
      automatic int j = i;
      fork
        r[j].start(p_sequencer.m_seqr);
      join_none
    end
    wait fork;
  endtask
endclass
 
	/*      
// Regression vseq for Coverage
class axi_regression_vseq extends uvm_sequence;
  `uvm_object_utils(axi_regression_vseq)
  `uvm_declare_p_sequencer(axi_virtual_sequencer)

  function new(string name = "axi_regression_vseq");
    super.new(name);
  endfunction

  task body();
    axi_basic_vseq             basic_vseq;
    axi_burst_vseq             burst_vseq;
    axi_multi_outstanding_vseq multi_vseq;
    axi_ooo_read_vseq          ooo_vseq;

    `uvm_info(get_type_name(), "Starting regression vseq", UVM_LOW)

    basic_vseq = axi_basic_vseq::type_id::create("basic_vseq");
    `uvm_info(get_type_name(), "Running BASIC scenario", UVM_LOW)
    basic_vseq.start(p_sequencer);
    #1000ns;

    burst_vseq = axi_burst_vseq::type_id::create("burst_vseq");
    `uvm_info(get_type_name(), "Running BURST scenario", UVM_LOW)
    burst_vseq.start(p_sequencer);
    #1000ns;

    multi_vseq = axi_multi_outstanding_vseq::type_id::create("multi_vseq");
    `uvm_info(get_type_name(), "Running MULTI_OUTSTANDING scenario", UVM_LOW)
    multi_vseq.start(p_sequencer);
    #1000ns;

    ooo_vseq = axi_ooo_read_vseq::type_id::create("ooo_vseq");
    `uvm_info(get_type_name(), "Running OOO_READ scenario", UVM_LOW)
    ooo_vseq.start(p_sequencer);
    #1000ns;

    `uvm_info(get_type_name(), "Completed regression vseq", UVM_LOW)
  endtask
endclass
      */