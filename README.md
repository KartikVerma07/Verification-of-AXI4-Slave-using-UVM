# Verification-of-AXI4-Slave-using-UVM

## Overview
This project is a UVM-based verification environment for a simplified AXI memory system with:
- one AXI master
- one AXI slave
- a memory-backed DUT

The main goal of this project was to learn AXI properly before moving to more advanced topics like multi-master arbitration.

This project focuses on:
- burst reads and writes
- independent AXI channels
- multiple outstanding read transactions
- out-of-order read completion across different IDs

---

## Main learning goals

The purpose of this project was to understand:
- how AXI channels work independently
- how burst transfers are driven and monitored
- how multiple outstanding reads are tracked
- how IDs are used for out-of-order read completion
- how to reconstruct full AXI transactions in the monitor
- how to compare DUT results against a reference memory model in the scoreboard

---

## DUT

The DUT is a simplified AXI memory slave.

It:
- stores incoming write data into internal memory
- returns memory contents on read requests
- supports burst transfers
- can return read responses out of order across different IDs

This was kept intentionally simple so the focus remains on AXI protocol understanding and verification.

---

## UVM Components

### Transaction
The transaction class models AXI read and write bursts.  
It contains fields such as:
- ID
- address
- burst length
- burst size
- burst type
- write data queue
- read data queue

### Driver
The driver sends AXI transactions from the sequence to the DUT.

Since AXI channels are independent, the driver handles them separately:
- AW channel
- W channel
- B channel
- AR channel
- R channel

### Monitor
The monitor watches the interface and reconstructs full AXI transactions from bus activity.

For writes:
- AW + W + B are combined into one completed write transaction

For reads:
- AR + R are combined into one completed read transaction

For read transactions, the monitor tracks requests by ID so that out-of-order read completion can still be matched correctly.

### Scoreboard
The scoreboard maintains a reference memory model.

It:
- updates memory contents on completed writes
- compares read data from DUT against expected reference memory values

This helps verify that burst addressing and returned data are correct.

---

## Test scenarios

### 1. Basic test
This test checks basic burst write and readback behavior.

It verifies:
- write path works
- read path works
- readback matches what was written

### 2. Burst test
This test verifies different burst lengths such as:
- 1 beat
- 4 beats
- 8 beats

It checks:
- address incrementing across beats
- correct data storage across consecutive locations
- correct readback for each burst length

### 3. Multiple outstanding read test
This test sends multiple read requests before earlier ones are fully completed.

It verifies:
- multiple outstanding reads
- tracking of multiple active transactions
- correct handling of different IDs

### 4. Out-of-order read test
This is the main advanced scenario in the project.

It sends multiple reads with different IDs and allows the DUT to return them in a different order.

It verifies:
- out-of-order read completion across IDs
- monitor reconstruction using RID
- correct scoreboard matching even when completion order differs from request order

---

## Functional coverage
Functional coverage was added using a UVM subscriber.

Coverage focuses on meaningful protocol behavior such as:
- read vs write traffic
- burst length buckets
- ID ranges
- address region buckets

---

## Simplifications used in this project
To keep the project focused and manageable, a few simplifications were made:
- single master only
- single slave only
- INCR bursts only
- 32-bit data width
- aligned accesses
- simplified memory model
- simplified write response behavior

These simplifications were intentional so the main AXI concepts could be understood clearly first.

---

## Future improvements
Some possible future extensions are:
- multi-master AXI arbitration
- support for more burst types
- write strobes
- support for more transfer sizes
- protocol assertions
- stronger functional coverage
- more corner-case testing

---

## Summary
In simple words, this project is a UVM verification environment for a single-master, single-slave AXI memory system.

It was built mainly to understand AXI deeply, especially:
- burst transfers
- outstanding reads
- out-of-order read completion
- monitor reconstruction
- scoreboard-based checking

This project gives a strong foundation before moving to more advanced AXI verification topics.
