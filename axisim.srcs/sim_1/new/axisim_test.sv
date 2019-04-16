`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/04/15 17:12:52
// Design Name: 
// Module Name: axisim_test
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module axisim_test(

    );

    parameter C_M_AXI_THREAD_ID_WIDTH       = 1;
    parameter C_M_AXI_ADDR_WIDTH            = 32;
    parameter C_M_AXI_DATA_WIDTH            = 32;
    parameter C_M_AXI_AWUSER_WIDTH          = 1;
    parameter C_M_AXI_ARUSER_WIDTH          = 1;
    parameter C_M_AXI_WUSER_WIDTH           = 1;
    parameter C_M_AXI_RUSER_WIDTH           = 1;
    parameter C_M_AXI_BUSER_WIDTH           = 1;
	  
	/* Disabling these parameters will remove any throttling.
	   The resulting ERROR flag will not be useful */ 
	  parameter C_M_AXI_SUPPORTS_WRITE         = 1;
	  parameter C_M_AXI_SUPPORTS_READ         = 1;
	   
	/* Max count of written but not yet read bursts.
		If the interconnect/slave is able to accept enough
		addresses and the read channels are stalled, the
		master will issue this many commands ahead of 
		write responses */
	parameter C_INTERCONNECT_M_AXI_WRITE_ISSUING	= 8;
	 
   ////////////////////////////
   // Example design parameters
   ////////////////////////////
   
   // Base address of targeted slave
   parameter C_M_AXI_TARGET = 'h00000000;

   // Number of address bits to test before wrapping   
    parameter C_OFFSET_WIDTH = 9;
   
   /* Burst length for transactions, in C_M_AXI_DATA_WIDTHs.
    Non-2^n lengths will eventually cause bursts across 4K
    address boundaries.*/
    parameter C_M_AXI_BURST_LEN = 16;

    // System Signals
    reg           ACLK;
    reg           ARESETN;
    
    // Master Interface Write Address
    reg [C_M_AXI_THREAD_ID_WIDTH-1:0] M_AXI_AWID;
    reg [C_M_AXI_ADDR_WIDTH-1:0]      M_AXI_AWADDR;
    reg [8-1:0]              M_AXI_AWLEN;
    reg [3-1:0]              M_AXI_AWSIZE;
    reg [2-1:0]              M_AXI_AWBURST;
    reg                      M_AXI_AWLOCK;
    reg [4-1:0]              M_AXI_AWCACHE;
    reg [3-1:0]              M_AXI_AWPROT;
    reg [4-1:0]              M_AXI_AWQOS;
    reg [C_M_AXI_AWUSER_WIDTH-1:0]      M_AXI_AWUSER;
    reg                      M_AXI_AWVALID;
    reg                      M_AXI_AWREADY;
    
    // Master Interface Write Data
    reg [C_M_AXI_DATA_WIDTH-1:0]      M_AXI_WDATA;
    reg [C_M_AXI_DATA_WIDTH/8-1:0]      M_AXI_WSTRB;
    reg                  M_AXI_WLAST;
    reg [C_M_AXI_WUSER_WIDTH-1:0]      M_AXI_WUSER;
    reg                  M_AXI_WVALID;
    reg                  M_AXI_WREADY;
   
    // Master Interface Write Response
    reg [C_M_AXI_THREAD_ID_WIDTH-1:0]      M_AXI_BID;
    reg [2-1:0]              M_AXI_BRESP;
    reg [C_M_AXI_BUSER_WIDTH-1:0]      M_AXI_BUSER;
    reg                  M_AXI_BVALID;
    reg                  M_AXI_BREADY;
    
    // Master Interface Read Address
    reg [C_M_AXI_THREAD_ID_WIDTH-1:0]      M_AXI_ARID;
    reg [C_M_AXI_ADDR_WIDTH-1:0]      M_AXI_ARADDR;
    reg [8-1:0]              M_AXI_ARLEN;
    reg [3-1:0]              M_AXI_ARSIZE;
    reg [2-1:0]              M_AXI_ARBURST;
    reg [2-1:0]              M_AXI_ARLOCK;
    reg [4-1:0]              M_AXI_ARCACHE;
    reg [3-1:0]              M_AXI_ARPROT;
    reg [4-1:0]              M_AXI_ARQOS;
    reg [C_M_AXI_ARUSER_WIDTH-1:0]      M_AXI_ARUSER;
    reg                  M_AXI_ARVALID;
    reg                  M_AXI_ARREADY;
    
    // Master Interface Read Data 
    reg [C_M_AXI_THREAD_ID_WIDTH-1:0]      M_AXI_RID;
    reg [C_M_AXI_DATA_WIDTH-1:0]      M_AXI_RDATA;
    reg [2-1:0]              M_AXI_RRESP;
    reg                  M_AXI_RLAST;
    reg [C_M_AXI_RUSER_WIDTH-1:0]      M_AXI_RUSER;
    reg                  M_AXI_RVALID;
    reg                  M_AXI_RREADY;

    // Example Design
    reg                  ERROR;
    
    axi_master axi_master_i(.*);
    
    initial begin
       forever begin
          #4 ACLK = 0;
          #4 ACLK = 1;
       end
    end
    
    initial begin
        ARESETN = 0;
        #200;
        ARESETN = 1;
    end
    
    
    
endmodule
