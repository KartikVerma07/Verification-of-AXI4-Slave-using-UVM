`timescale 1ns/1ps

interface axi_if #(
  parameter ADDR_W = 32,
  parameter DATA_W = 32,
  parameter ID_W   = 4
)(
  input logic ACLK,
  input logic ARESETn
);

  // Write address channel
  logic [ID_W-1:0]   AWID;
  logic [ADDR_W-1:0] AWADDR;
  logic [7:0]        AWLEN;
  logic [2:0]        AWSIZE;
  logic [1:0]        AWBURST;
  logic              AWVALID;
  logic              AWREADY;

  // Write data channel
  logic [DATA_W-1:0] WDATA;
  logic              WLAST;
  logic              WVALID;
  logic              WREADY;

  // Write response channel
  logic [ID_W-1:0]   BID;
  logic [1:0]        BRESP;
  logic              BVALID;
  logic              BREADY;

  // Read address channel
  logic [ID_W-1:0]   ARID;
  logic [ADDR_W-1:0] ARADDR;
  logic [7:0]        ARLEN;
  logic [2:0]        ARSIZE;
  logic [1:0]        ARBURST;
  logic              ARVALID;
  logic              ARREADY;

  // Read data channel
  logic [ID_W-1:0]   RID;
  logic [DATA_W-1:0] RDATA;
  logic [1:0]        RRESP;
  logic              RLAST;
  logic              RVALID;
  logic              RREADY;

  clocking drv_cb @(posedge ACLK);
    default input #1ps output #1ps;

    output AWID, AWADDR, AWLEN, AWSIZE, AWBURST, AWVALID;
    input  AWREADY;

    output WDATA, WLAST, WVALID;
    input  WREADY;

    input  BID, BRESP, BVALID;
    output BREADY;

    output ARID, ARADDR, ARLEN, ARSIZE, ARBURST, ARVALID;
    input  ARREADY;

    input  RID, RDATA, RRESP, RLAST, RVALID;
    output RREADY;
  endclocking

  clocking mon_cb @(posedge ACLK);
    default input #1ps output #1ps;

    input AWID, AWADDR, AWLEN, AWSIZE, AWBURST, AWVALID, AWREADY;
    input WDATA, WLAST, WVALID, WREADY;
    input BID, BRESP, BVALID, BREADY;
    input ARID, ARADDR, ARLEN, ARSIZE, ARBURST, ARVALID, ARREADY;
    input RID, RDATA, RRESP, RLAST, RVALID, RREADY;
  endclocking

  modport DRV (clocking drv_cb, input ACLK, input ARESETn);
  modport MON (clocking mon_cb, input ACLK, input ARESETn);
  modport SLV (
    input  ACLK,
    input  ARESETn,
    input  AWID, AWADDR, AWLEN, AWSIZE, AWBURST, AWVALID,
    output AWREADY,
    input  WDATA, WLAST, WVALID,
    output WREADY,
    output BID, BRESP, BVALID,
    input  BREADY,
    input  ARID, ARADDR, ARLEN, ARSIZE, ARBURST, ARVALID,
    output ARREADY,
    output RID, RDATA, RRESP, RLAST, RVALID,
    input  RREADY
  );

endinterface
