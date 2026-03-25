`timescale 1ns/1ps
import uvm_pkg::*;
`include "uvm_macros.svh"
`include "axi_if.sv"
`include "axi_uvm_pkg.sv"
`include "axi_mem_slave_dut.sv"
import axi_uvm_pkg::*;

module top;
  logic ACLK;
  logic ARESETn;

  initial begin
    ACLK = 1'b0;
    forever #5ns ACLK = ~ACLK;
  end

  initial begin
    ARESETn = 1'b0;
    #30ns;
    ARESETn = 1'b1;
  end

  axi_if #(.ADDR_W(32), .DATA_W(32), .ID_W(4)) axi_vif (.ACLK(ACLK), .ARESETn(ARESETn));

  axi_mem_slave_dut dut (
    .axi(axi_vif)
  );

  initial begin
    uvm_config_db#(virtual axi_if)::set(null, "uvm_test_top.env.m_agent*", "vif", axi_vif);

    // choose one test (Individual tests)
    // run_test("axi_basic_test");
    // run_test("axi_burst_test");
     run_test("axi_multi_outstanding_test");
    // run_test("axi_ooo_read_test");
    
    // Collective regression test for combined coverage (Not working rn -> will fix later)
    // run_test("axi_regression_test");
  end
endmodule
