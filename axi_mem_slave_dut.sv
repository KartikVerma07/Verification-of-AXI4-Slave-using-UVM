module axi_mem_slave_dut #(
  parameter ADDR_W     = 32,
  parameter DATA_W     = 32,
  parameter ID_W       = 4,
  parameter DEPTH      = 65536,
  parameter RD_Q_DEPTH = 8
)(
  axi_if.SLV axi
);

  typedef enum logic [1:0] {WR_IDLE, WR_DATA, WR_RESP} wr_state_t;
  typedef enum logic       {RD_IDLE, RD_SEND}          rd_state_t;

  typedef struct packed {
    logic              valid;
    logic [ID_W-1:0]   id;
    logic [ADDR_W-1:0] addr;
    logic [7:0]        len;
    logic [2:0]        size;
    logic [3:0]        delay;
  } rd_req_t;

  // --------------------------------------------------
  // State / datapath registers
  // --------------------------------------------------
  wr_state_t wr_state, wr_state_n;
  rd_state_t rd_state, rd_state_n;

  logic [ID_W-1:0]   wr_id_q;
  logic [ADDR_W-1:0] wr_addr_q;
  logic [7:0]        wr_len_q;
  logic [2:0]        wr_size_q;
  logic [7:0]        wr_beat_q;

  rd_req_t           rd_q [0:RD_Q_DEPTH-1];

  logic [ID_W-1:0]   rd_id_q;
  logic [ADDR_W-1:0] rd_addr_q;
  logic [7:0]        rd_len_q;
  logic [2:0]        rd_size_q;
  logic [7:0]        rd_beat_q;
  integer            rd_active_idx;

  logic [DATA_W-1:0] mem [0:DEPTH-1];

  // --------------------------------------------------
  // Combinational helper signals
  // --------------------------------------------------
  integer first_free_c;
  integer chosen_idx_c;

  // --------------------------------------------------
  // Helpers
  // --------------------------------------------------
  function automatic int unsigned word_idx(input logic [ADDR_W-1:0] addr);
    word_idx = (addr >> 2) % DEPTH;
  endfunction

  function automatic [ADDR_W-1:0] next_addr(
    input [ADDR_W-1:0] addr,
    input [2:0]        size
  );
    next_addr = addr + (1 << size);
  endfunction

  // --------------------------------------------------
  // Find first free slot in read queue
  // --------------------------------------------------
  always_comb begin
    first_free_c = -1;
    for (int j = 0; j < RD_Q_DEPTH; j++) begin
      if (!rd_q[j].valid && first_free_c == -1)
        first_free_c = j;
    end
  end

  // --------------------------------------------------
  // Choose a ready read request:
  // -> pick highest ready index for OOO
  // -> preserve ordering within same ID (In-Order for same ID)
  // --------------------------------------------------
  always_comb begin
    chosen_idx_c = -1;

    for (int i = RD_Q_DEPTH-1; i >= 0; i--) begin
      bit blocked_same_id;
      blocked_same_id = 1'b0;

      if (rd_q[i].valid && rd_q[i].delay == 0) begin
        for (int k = 0; k < i; k++) begin
          if (rd_q[k].valid && rd_q[k].id == rd_q[i].id)
            blocked_same_id = 1'b1;
        end

        if (!blocked_same_id && chosen_idx_c == -1)
          chosen_idx_c = i;
      end
    end
  end

  // --------------------------------------------------
  // READY generation
  // --------------------------------------------------
  always_comb begin
    axi.AWREADY = (wr_state == WR_IDLE);
    axi.WREADY  = (wr_state == WR_DATA);
    axi.ARREADY = (first_free_c != -1);
  end

  // --------------------------------------------------
  // Write FSM next-state logic
  // --------------------------------------------------
  always_comb begin
    wr_state_n = wr_state;

    unique case (wr_state)
      WR_IDLE: begin
        if (axi.AWVALID && axi.AWREADY)
          wr_state_n = WR_DATA;
      end

      WR_DATA: begin
        if (axi.WVALID && axi.WREADY &&
            (axi.WLAST || (wr_beat_q == wr_len_q)))
          wr_state_n = WR_RESP;
      end

      WR_RESP: begin
        if (axi.BVALID && axi.BREADY)
          wr_state_n = WR_IDLE;
      end

      default: wr_state_n = WR_IDLE;
    endcase
  end

  // --------------------------------------------------
  // Read FSM next-state logic
  // --------------------------------------------------
  always_comb begin
    rd_state_n = rd_state;

    unique case (rd_state)
      RD_IDLE: begin
        if (chosen_idx_c != -1)
          rd_state_n = RD_SEND;
      end

      RD_SEND: begin
        if (axi.RVALID && axi.RREADY && (rd_beat_q == rd_len_q))
          rd_state_n = RD_IDLE;
      end

      default: rd_state_n = RD_IDLE;
    endcase
  end

  // --------------------------------------------------
  // Write state/data registers & write response
  // --------------------------------------------------
  always_ff @(posedge axi.ACLK or negedge axi.ARESETn) begin
    if (!axi.ARESETn) begin
      wr_state   <= WR_IDLE;
      wr_id_q    <= '0;
      wr_addr_q  <= '0;
      wr_len_q   <= '0;
      wr_size_q  <= '0;
      wr_beat_q  <= '0;

      axi.BID    <= '0;
      axi.BRESP  <= 2'b00;
      axi.BVALID <= 1'b0;

      for (int i = 0; i < DEPTH; i++)
        mem[i] <= '0;
    end
    else begin
      wr_state <= wr_state_n;

      unique case (wr_state)
        WR_IDLE: begin
          if (axi.AWVALID && axi.AWREADY) begin
            wr_id_q   <= axi.AWID;
            wr_addr_q <= axi.AWADDR;
            wr_len_q  <= axi.AWLEN;
            wr_size_q <= axi.AWSIZE;
            wr_beat_q <= 0;
          end
        end

        WR_DATA: begin
          if (axi.WVALID && axi.WREADY) begin
            mem[word_idx(wr_addr_q)] <= axi.WDATA;
            wr_addr_q                <= next_addr(wr_addr_q, wr_size_q);

            if (axi.WLAST || (wr_beat_q == wr_len_q)) begin
              axi.BID    <= wr_id_q;
              axi.BRESP  <= 2'b00;   // OKAY
              axi.BVALID <= 1'b1;
            end
            else begin
              wr_beat_q <= wr_beat_q + 1;
            end
          end
        end

        WR_RESP: begin
          if (axi.BVALID && axi.BREADY)
            axi.BVALID <= 1'b0;
        end

        default: begin
        end
      endcase
    end
  end

  // --------------------------------------------------
  // Read-request queue management
  // 1. accept AR
  // 2. assign random delay
  // 3. clear queue entry when active read finishes
  // --------------------------------------------------
  always_ff @(posedge axi.ACLK or negedge axi.ARESETn) begin
    if (!axi.ARESETn) begin
      for (int i = 0; i < RD_Q_DEPTH; i++) begin
        rd_q[i].valid <= 1'b0;
        rd_q[i].id    <= '0;
        rd_q[i].addr  <= '0;
        rd_q[i].len   <= '0;
        rd_q[i].size  <= '0;
        rd_q[i].delay <= '0;
      end
    end
    else begin
      // Accept read request into first free slot
      if (axi.ARVALID && axi.ARREADY) begin
        for (int i = 0; i < RD_Q_DEPTH; i++) begin
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

      // Age request delays
      for (int i = 0; i < RD_Q_DEPTH; i++) begin
        if (rd_q[i].valid && rd_q[i].delay != 0)
          rd_q[i].delay <= rd_q[i].delay - 1;
      end

      // Invalidate queue entry when read burst fully completes
      if (rd_state == RD_SEND && axi.RVALID && axi.RREADY &&
          (rd_beat_q == rd_len_q) && (rd_active_idx >= 0)) begin
        rd_q[rd_active_idx].valid <= 1'b0;
      end
    end
  end

  // --------------------------------------------------
  // Read response FSM registers and R channel driving
  // --------------------------------------------------
  always_ff @(posedge axi.ACLK or negedge axi.ARESETn) begin
    if (!axi.ARESETn) begin
      rd_state      <= RD_IDLE;
      rd_id_q       <= '0;
      rd_addr_q     <= '0;
      rd_len_q      <= '0;
      rd_size_q     <= '0;
      rd_beat_q     <= '0;
      rd_active_idx <= -1;

      axi.RID       <= '0;
      axi.RDATA     <= '0;
      axi.RRESP     <= 2'b00;
      axi.RLAST     <= 1'b0;
      axi.RVALID    <= 1'b0;
    end
    else begin
      rd_state <= rd_state_n;

      unique case (rd_state)
        RD_IDLE: begin
          if (chosen_idx_c != -1) begin
            rd_active_idx <= chosen_idx_c;
            rd_id_q       <= rd_q[chosen_idx_c].id;
            rd_addr_q     <= rd_q[chosen_idx_c].addr;
            rd_len_q      <= rd_q[chosen_idx_c].len;
            rd_size_q     <= rd_q[chosen_idx_c].size;
            rd_beat_q     <= 0;

            axi.RID       <= rd_q[chosen_idx_c].id;
            axi.RDATA     <= mem[word_idx(rd_q[chosen_idx_c].addr)];
            axi.RRESP     <= 2'b00;
            axi.RLAST     <= (rd_q[chosen_idx_c].len == 0);
            axi.RVALID    <= 1'b1;
          end
        end

        RD_SEND: begin
          if (axi.RVALID && axi.RREADY) begin
            if (rd_beat_q == rd_len_q) begin
              axi.RVALID    <= 1'b0;
              axi.RLAST     <= 1'b0;
              rd_active_idx <= -1;
            end
            else begin
              rd_beat_q <= rd_beat_q + 1;
              rd_addr_q <= next_addr(rd_addr_q, rd_size_q);

              axi.RID    <= rd_id_q;
              axi.RDATA  <= mem[word_idx(next_addr(rd_addr_q, rd_size_q))];
              axi.RRESP  <= 2'b00;
              axi.RLAST  <= ((rd_beat_q + 1) == rd_len_q);
              axi.RVALID <= 1'b1;
            end
          end
        end

        default: begin
        end
      endcase
    end
  end

endmodule