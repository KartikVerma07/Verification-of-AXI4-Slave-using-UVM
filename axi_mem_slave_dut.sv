module axi_mem_slave_dut #(
  parameter ADDR_W = 32,
  parameter DATA_W = 32,
  parameter ID_W   = 4,
  parameter DEPTH  = 65536  ,//2^16
  parameter RD_Q_DEPTH = 8
)(
  axi_if.SLV axi
);

  typedef enum logic [1:0] {WR_IDLE, WR_DATA, WR_RESP} wr_state_t;
  typedef enum logic [0:0] {RD_IDLE, RD_SEND} rd_state_t;

  typedef struct packed {
    logic              valid;
    logic [ID_W-1:0]   id;
    logic [ADDR_W-1:0] addr;
    logic [7:0]        len;
    logic [2:0]        size;
    logic [3:0]        delay;
  } rd_req_t;

  wr_state_t wr_state;
  rd_state_t rd_state;

  logic [ID_W-1:0]   wr_id_q;
  logic [ADDR_W-1:0] wr_addr_q;
  logic [7:0]        wr_len_q;
  logic [2:0]        wr_size_q;
  logic [7:0]        wr_beat_q;

  rd_req_t           rd_q [0:RD_Q_DEPTH-1];
  logic [ADDR_W-1:0] rd_addr_q;
  logic [7:0]        rd_len_q;
  logic [2:0]        rd_size_q;
  logic [ID_W-1:0]   rd_id_q;
  logic [7:0]        rd_beat_q;
  integer            rd_active_idx;

  logic [DATA_W-1:0] mem [0:DEPTH-1];

  integer i;
  integer chosen_idx;
  integer first_free;
  bit earlier_same_id;

  function automatic int unsigned word_idx(input logic [ADDR_W-1:0] addr);
    word_idx = (addr >> 2) % DEPTH;
  endfunction

  function automatic [ADDR_W-1:0] next_addr(input [ADDR_W-1:0] addr, input [2:0] size);
    next_addr = addr + (1 << size);
  endfunction

  // --------------------------------------------------
  // Combinational ready generation
  // --------------------------------------------------
  always_comb begin
    axi.AWREADY = (wr_state == WR_IDLE);
    axi.WREADY  = (wr_state == WR_DATA);

    first_free = -1;
    for (int j = 0; j < RD_Q_DEPTH; j++) begin
      if (!rd_q[j].valid && first_free == -1)
        first_free = j;
    end
    axi.ARREADY = (first_free != -1);
  end

  // --------------------------------------------------
  // Sequential logic
  // --------------------------------------------------
  always_ff @(posedge axi.ACLK or negedge axi.ARESETn) begin
    if (!axi.ARESETn) begin
      wr_state   <= WR_IDLE;
      wr_id_q    <= '0;
      wr_addr_q  <= '0;
      wr_len_q   <= '0;
      wr_size_q  <= '0;
      wr_beat_q  <= '0;

      rd_state   <= RD_IDLE;
      rd_addr_q  <= '0;
      rd_len_q   <= '0;
      rd_size_q  <= '0;
      rd_id_q    <= '0;
      rd_beat_q  <= '0;
      rd_active_idx <= -1;

      axi.BID    <= '0;
      axi.BRESP  <= 2'b00;
      axi.BVALID <= 1'b0;

      axi.RID    <= '0;
      axi.RDATA  <= '0;
      axi.RRESP  <= 2'b00;
      axi.RLAST  <= 1'b0;
      axi.RVALID <= 1'b0;

      for (i = 0; i < DEPTH; i++)
        mem[i] <= '0;
      for (i = 0; i < RD_Q_DEPTH; i++) begin
        rd_q[i].valid <= 1'b0;
        rd_q[i].id    <= '0;
        rd_q[i].addr  <= '0;
        rd_q[i].len   <= '0;
        rd_q[i].size  <= '0;
        rd_q[i].delay <= '0;
      end
    end
    else begin
      // ------------------------
      // Accept write address
      // ------------------------
      if (wr_state == WR_IDLE && axi.AWVALID && axi.AWREADY) begin
        wr_id_q   <= axi.AWID;
        wr_addr_q <= axi.AWADDR;
        wr_len_q  <= axi.AWLEN;
        wr_size_q <= axi.AWSIZE;
        wr_beat_q <= 0;
        wr_state  <= WR_DATA;
      end

      // ------------------------
      // Accept write data beats
      // ------------------------
      if (wr_state == WR_DATA && axi.WVALID && axi.WREADY) begin
        mem[word_idx(wr_addr_q)] <= axi.WDATA;
        wr_addr_q <= next_addr(wr_addr_q, wr_size_q);

        if (axi.WLAST || (wr_beat_q == wr_len_q)) begin
          axi.BID    <= wr_id_q;
          axi.BRESP  <= 2'b00;
          axi.BVALID <= 1'b1;
          wr_state   <= WR_RESP;
        end
        else begin
          wr_beat_q <= wr_beat_q + 1;
        end
      end

      // ------------------------
      // Complete write response
      // ------------------------
      if (wr_state == WR_RESP && axi.BVALID && axi.BREADY) begin
        axi.BVALID <= 1'b0;
        wr_state   <= WR_IDLE;
      end

      // ------------------------
      // Accept read requests
      // ------------------------
      if (axi.ARVALID && axi.ARREADY) begin
        for (i = 0; i < RD_Q_DEPTH; i++) begin
          if (!rd_q[i].valid) begin
            rd_q[i].valid <= 1'b1;
            rd_q[i].id    <= axi.ARID;
            rd_q[i].addr  <= axi.ARADDR;
            rd_q[i].len   <= axi.ARLEN;
            rd_q[i].size  <= axi.ARSIZE;
            rd_q[i].delay <= $urandom_range(0,3);
            break;
          end
        end
      end

      // Age read-request delays
      for (i = 0; i < RD_Q_DEPTH; i++) begin
        if (rd_q[i].valid && rd_q[i].delay != 0)
          rd_q[i].delay <= rd_q[i].delay - 1;
      end

      // ------------------------
      // Launch read response (out-of-order across IDs)
      // choose highest ready index to encourage OOO
      // but preserve order within same ID
      // ------------------------
      if (rd_state == RD_IDLE) begin
        chosen_idx = -1;
        for (i = RD_Q_DEPTH-1; i >= 0; i--) begin
          if (rd_q[i].valid && rd_q[i].delay == 0) begin
            earlier_same_id = 0;
            for (int k = 0; k < i; k++) begin
              if (rd_q[k].valid && rd_q[k].id == rd_q[i].id)
                earlier_same_id = 1;
            end
            if (!earlier_same_id && chosen_idx == -1)
              chosen_idx = i;
          end
        end

        if (chosen_idx != -1) begin
          rd_active_idx <= chosen_idx;
          rd_id_q       <= rd_q[chosen_idx].id;
          rd_addr_q     <= rd_q[chosen_idx].addr;
          rd_len_q      <= rd_q[chosen_idx].len;
          rd_size_q     <= rd_q[chosen_idx].size;
          rd_beat_q     <= 0;

          axi.RID       <= rd_q[chosen_idx].id;
          axi.RDATA     <= mem[word_idx(rd_q[chosen_idx].addr)];
          axi.RRESP     <= 2'b00;
          axi.RLAST     <= (rd_q[chosen_idx].len == 0);
          axi.RVALID    <= 1'b1;
          rd_state      <= RD_SEND;
        end
      end
      else if (rd_state == RD_SEND) begin
        if (axi.RVALID && axi.RREADY) begin
          if (rd_beat_q == rd_len_q) begin
            axi.RVALID <= 1'b0;
            axi.RLAST  <= 1'b0;
            if (rd_active_idx >= 0)
              rd_q[rd_active_idx].valid <= 1'b0;
            rd_active_idx <= -1;
            rd_state <= RD_IDLE;
          end
          else begin
            rd_beat_q <= rd_beat_q + 1;
            rd_addr_q <= next_addr(rd_addr_q, rd_size_q);
            axi.RID   <= rd_id_q;
            axi.RDATA <= mem[word_idx(next_addr(rd_addr_q, rd_size_q))];
            axi.RRESP <= 2'b00;
            axi.RLAST <= ((rd_beat_q + 1) == rd_len_q);
            axi.RVALID <= 1'b1;
          end
        end
      end
    end
  end
endmodule
