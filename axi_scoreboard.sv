class axi_scoreboard extends uvm_component;
  `uvm_component_utils(axi_scoreboard)

  uvm_analysis_imp #(axi_txn, axi_scoreboard) txn_imp;

  byte unsigned ref_mem [int unsigned];
  string scenario_name = "UNSPECIFIED";

  function new(string name, uvm_component parent);
    super.new(name, parent);
    txn_imp = new("txn_imp", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    void'(uvm_config_db#(string)::get(this, "", "scenario_name", scenario_name));
  endfunction

  function void write_mem_word(input int unsigned addr, input bit [31:0] data);
    int b;
    for (b = 0; b < 4; b++) begin
      ref_mem[addr + b] = data[b*8 +: 8];
    end
  endfunction

  function bit [31:0] read_mem_word(input int unsigned addr);
    bit [31:0] data;
    int b;
    begin
      data = '0;
      for (b = 0; b < 4; b++) begin
        if (ref_mem.exists(addr + b))
          data[b*8 +: 8] = ref_mem[addr + b];
        else
          data[b*8 +: 8] = 8'h00;
      end
      return data;
    end
  endfunction

  function void write(axi_txn tr);
    int unsigned beat_addr;
    int unsigned step;
    int i;
    bit [31:0] exp_data;

    step = (1 << tr.size);

    if (tr.is_write) begin
      for (i = 0; i < tr.data_q.size(); i++) begin
        beat_addr = tr.addr + i * step;
        write_mem_word(beat_addr, tr.data_q[i]);

        `uvm_info("SB",
         $sformatf("[%s] WRITE id=%0d base_addr=0x%08h beat_addr=0x%08h beat=%0d data=0x%08h",
                    scenario_name, tr.id, tr.addr, beat_addr, i, tr.data_q[i]),
          			UVM_MEDIUM)
      end
    end
    else begin
      for (i = 0; i < tr.rdata_q.size(); i++) begin
        beat_addr = tr.addr + i * step;
        exp_data  = read_mem_word(beat_addr);

        if (tr.rdata_q[i] !== exp_data) begin
          `uvm_error("SB",
 		   $sformatf("[%s] READ MISMATCH id=%0d base_addr=0x%08h beat_addr=0x%08h beat=%0d exp=0x%08h got=0x%08h",
                     scenario_name, tr.id, tr.addr, beat_addr, i, exp_data, tr.rdata_q[i]))
        end
        else begin
          `uvm_info("SB",
           $sformatf("[%s] READ MATCH id=%0d base_addr=0x%08h beat_addr=0x%08h beat=%0d data=0x%08h",
                    scenario_name, tr.id, tr.addr, beat_addr, i, tr.rdata_q[i]),
          			UVM_MEDIUM)
        end
      end
    end
  endfunction
endclass