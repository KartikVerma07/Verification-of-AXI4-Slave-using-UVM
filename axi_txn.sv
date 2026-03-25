class axi_txn extends uvm_sequence_item;
  rand bit                is_write;
  rand bit [3:0]          id;
  rand bit [31:0]         addr;
  rand bit [7:0]          len;
  rand bit [2:0]          size;
  rand bit [1:0]          burst;

  bit [31:0]              data_q[$];
  bit [31:0]              rdata_q[$];
  bit [1:0]               resp_q[$];

  constraint c_burst { burst == 2'b01; } // INCR only
  constraint c_len   { len inside {[0:7]}; }
  constraint c_size  { size inside {3'd0,3'd1,3'd2}; }
  constraint c_align { addr % (1 << size) == '0; }

  `uvm_object_utils_begin(axi_txn)
    `uvm_field_int(is_write, UVM_ALL_ON)
    `uvm_field_int(id,       UVM_ALL_ON)
    `uvm_field_int(addr,     UVM_ALL_ON)
    `uvm_field_int(len,      UVM_ALL_ON)
    `uvm_field_int(size,     UVM_ALL_ON)
    `uvm_field_int(burst,    UVM_ALL_ON)
    `uvm_field_queue_int(data_q, UVM_ALL_ON)
    `uvm_field_queue_int(rdata_q, UVM_ALL_ON)
    `uvm_field_queue_int(resp_q, UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "axi_txn");
    super.new(name);
  endfunction

  function int unsigned beat_bytes();
    return (1 << size);
  endfunction

  function int unsigned num_beats();
    return int'(len) + 1;
  endfunction

  function void post_randomize();
    int unsigned beats;
    int i;
    beats = num_beats();
    data_q.delete();
    if (is_write) begin
      for (i = 0; i < beats; i++) begin
        data_q.push_back($urandom());
      end
    end
  endfunction
endclass
