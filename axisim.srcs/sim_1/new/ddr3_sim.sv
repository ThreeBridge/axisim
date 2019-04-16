/****************************************************************************************
*
*    File Name:  tb.v
*
* Dependencies:  ddr3.v, ddr3_parameters.vh
*
*  Description:  Micron SDRAM DDR3 (Double Data Rate 3) test bench
*
*         Note: -Set simulator resolution to "ps" accuracy
*               -Set Debug = 0 to disable $display messages
*
*   Disclaimer   This software code and all associated documentation, comments or other 
*  of Warranty:  information (collectively "Software") is provided "AS IS" without 
*                warranty of any kind. MICRON TECHNOLOGY, INC. ("MTI") EXPRESSLY 
*                DISCLAIMS ALL WARRANTIES EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED 
*                TO, NONINFRINGEMENT OF THIRD PARTY RIGHTS, AND ANY IMPLIED WARRANTIES 
*                OF MERCHANTABILITY OR FITNESS FOR ANY PARTICULAR PURPOSE. MTI DOES NOT 
*                WARRANT THAT THE SOFTWARE WILL MEET YOUR REQUIREMENTS, OR THAT THE 
*                OPERATION OF THE SOFTWARE WILL BE UNINTERRUPTED OR ERROR-FREE. 
*                FURTHERMORE, MTI DOES NOT MAKE ANY REPRESENTATIONS REGARDING THE USE OR 
*                THE RESULTS OF THE USE OF THE SOFTWARE IN TERMS OF ITS CORRECTNESS, 
*                ACCURACY, RELIABILITY, OR OTHERWISE. THE ENTIRE RISK ARISING OUT OF USE 
*                OR PERFORMANCE OF THE SOFTWARE REMAINS WITH YOU. IN NO EVENT SHALL MTI, 
*                ITS AFFILIATED COMPANIES OR THEIR SUPPLIERS BE LIABLE FOR ANY DIRECT, 
*                INDIRECT, CONSEQUENTIAL, INCIDENTAL, OR SPECIAL DAMAGES (INCLUDING, 
*                WITHOUT LIMITATION, DAMAGES FOR LOSS OF PROFITS, BUSINESS INTERRUPTION, 
*                OR LOSS OF INFORMATION) ARISING OUT OF YOUR USE OF OR INABILITY TO USE 
*                THE SOFTWARE, EVEN IF MTI HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH 
*                DAMAGES. Because some jurisdictions prohibit the exclusion or 
*                limitation of liability for consequential or incidental damages, the 
*                above limitation may not apply to you.
*
*                Copyright 2003 Micron Technology, Inc. All rights reserved.
*
****************************************************************************************/

`timescale 1ps / 1ps

module ddr3_sim;

    `include "4096Mb_ddr3_parameters.vh"

    // ports
    reg                         rst_n;
    wire                        ck;
    wire                        ck_n = ~ck;
    reg                         cke;
    reg                         cs_n;
    reg                         ras_n;
    reg                         cas_n;
    reg                         we_n;
    reg           [BA_BITS-1:0] ba;
    reg         [ADDR_BITS-1:0] a;
    wire          [DM_BITS-1:0] dm;
    wire          [DQ_BITS-1:0] dq;
    wire          [DQ_BITS-1:0] dq0;
    wire          [DQ_BITS-1:0] dq1;
    wire         [DQS_BITS-1:0] dqs;
    wire         [DQS_BITS-1:0] dqs_n;
    wire         [DQS_BITS-1:0] tdqs_n;
    wire                        odt;
    
    // mode registers
    reg         [ADDR_BITS-1:0] mode_reg0;                                 //Mode Register
    reg         [ADDR_BITS-1:0] mode_reg1;                                 //Extended Mode Register
    reg         [ADDR_BITS-1:0] mode_reg2;                                 //Extended Mode Register 2
    wire                  [3:0] cl       = {mode_reg0[2], mode_reg0[6:4]} + 4;              //CAS Latency
    wire                        bo       = mode_reg0[3];                    //Burst Order
    reg                   [3:0] bl;                                         //Burst Length
    wire                  [3:0] cwl      = mode_reg2[5:3] + 5;              //CAS Write Latency
    wire                  [3:0] al       = (mode_reg1[4:3] === 2'b00) ? 4'h0 : cl - mode_reg1[4:3]; //Additive Latency
    wire                  [4:0] rl       = cl + al;                         //Read Latency
    wire                  [4:0] wl       = cwl + al;                        //Write Latency

    // dq transmit
    reg                         dq_en;
    reg           [DM_BITS-1:0] dm_out;
    reg           [DQ_BITS-1:0] dq_out;
    reg                         dqs_en;
    reg          [DQS_BITS-1:0] dqs_out;
    assign                      dm       = dq_en ? dm_out : {DM_BITS{1'bz}};
    assign                      dq0      = dq_en ? dq_out : {DQ_BITS{1'bz}};
    assign                      dq1      = dq_en ? ~dq_out : {DQ_BITS{1'bz}};
    assign                      dqs      = dqs_en ? dqs_out : {DQS_BITS{1'bz}};
    assign                      dqs_n    = dqs_en ? ~dqs_out : {DQS_BITS{1'bz}};

    // dq receive
    reg           [DM_BITS-1:0] dm_fifo [4*CL_MAX+BL_MAX+2:0];
    reg           [DQ_BITS-1:0] dq_fifo [4*CL_MAX+BL_MAX+2:0];
    wire          [DQ_BITS-1:0] q0, q1, q2, q3;
    reg                         ptr_rst_n;
    reg                   [1:0] burst_cntr;

    // odt
    reg                         odt_out;
    reg     [(AL_MAX+CL_MAX):0] odt_fifo;
    assign                      odt      = odt_out & !odt_fifo[0];

    // timing definition in tCK units
    real                        tck;
    wire                 [11:0] tccd     = TCCD;
    wire                 [11:0] tcke     = max(ceil(TCKE/tck), TCKE_TCK);
    wire                 [11:0] tckesr   = TCKESR_TCK;
    wire                 [11:0] tcksre   = max(ceil(TCKSRE/tck), TCKSRE_TCK);
    wire                 [11:0] tcksrx   = max(ceil(TCKSRX/tck), TCKSRX_TCK);
    wire                 [11:0] tcl_min  = min_cl(tck);
    wire                  [6:2] mr_cl    = (tcl_min - 4)<<2 | (tcl_min/12);
    wire                 [11:0] tcpded   = TCPDED;
    wire                 [11:0] tcwl_min = min_cwl(tck);
    wire                  [5:3] mr_cwl   = tcwl_min - 5;
    wire                 [11:0] tdllk    = TDLLK;
    wire                 [11:0] tfaw     = ceil(TFAW/tck);
    wire                 [11:0] tmod     = max(ceil(TMOD/tck), TMOD_TCK);
    wire                 [11:0] tmrd     = TMRD;
    wire                 [11:0] tras     = ceil(TRAS_MIN/tck);
    wire                 [11:0] trc      = ceil(TRC/tck);
    wire                 [11:0] trcd     = ceil(TRCD/tck);
    wire                 [11:0] trfc     = ceil(TRFC_MIN/tck);
    wire                 [11:0] trp      = ceil(TRP/tck);
    wire                 [11:0] trrd     = max(ceil(TRRD/tck), TRRD_TCK);
    wire                 [11:0] trtp     = max(ceil(TRTP/tck), TRTP_TCK);
    wire                 [11:0] twr      = ceil(TWR/tck);
    wire                 [11:0] twtr     = max(ceil(TWTR/tck), TWTR_TCK);
    wire                 [11:0] txp      = max(ceil(TXP/tck), TXP_TCK);
    wire                 [11:0] txpdll   = max(ceil(TXPDLL/tck), TXPDLL_TCK);
    wire                 [11:0] txpr     = max(ceil(TXPR/tck), TXPR_TCK);
    wire                 [11:0] txs      = max(ceil(TXS/tck), TXS_TCK);
    wire                 [11:0] txsdll   = TXSDLL;
    wire                 [11:0] tzqcs    = TZQCS;
    wire                 [11:0] tzqoper  = TZQOPER;
    wire                 [11:0] wr       = (twr < 8) ? twr : twr + twr%2;
    wire                 [11:9] mr_wr    = (twr < 8) ? (twr - 4) : twr>>1;

`ifdef TRUEBL4
    wire                 [11:0] tccd_dg  = TCCD_DG;
    wire                 [11:0] trrd_dg  = max(ceil(TRRD_DG/tck), TRRD_DG_TCK);
    wire                 [11:0] twtr_dg  = max(ceil(TWTR_DG/tck), TWTR_DG_TCK);
`endif

    initial begin
        $timeformat (-9, 1, " ns", 1);
`ifdef period
        tck <= `period; 
`else
        tck <= ceil(TCK_MIN);
`endif
        //ck <= 1'b1;
        odt_fifo <= 0;
    end

    logic sys_clk_i;
    
    logic clk_ref_i;
    
    logic ui_clk;
    logic ui_clk_sync_rst;
    logic mmcm_locked;
    logic aresetn;
    logic app_sr_req;
    logic app_ref_req;
    logic app_zq_req;
    logic app_sr_active;
    logic app_ref_ack;
    logic app_zq_ack;
    
    logic s_axi_awid;
    logic s_axi_awaddr;
    logic s_axi_awlen;
    logic s_axi_awsize;
    logic s_axi_awburst;
    logic s_axi_awlock;
    logic s_axi_awcache;
    logic s_axi_awprot;
    logic s_axi_awqos;
    logic s_axi_awvalid;
    logic s_axi_awready;
    
    logic s_axi_wdata;
    logic s_axi_wstrb;
    logic s_axi_wlast;
    logic s_axi_wvalid;
    logic s_axi_wready;
    
    logic s_axi_bready;
    logic s_axi_bid;
    logic s_axi_bresp;
    logic s_axi_bvalid;
    
    logic s_axi_arid;
    logic s_axi_araddr;
    logic s_axi_arlen;
    logic s_axi_arsize;
    logic s_axi_arburst;
    logic s_axi_arlock;
    logic s_axi_arcache;
    logic s_axi_arprot;
    logic s_axi_arqos;
    logic s_axi_arvalid;
    logic s_axi_arready;
    
    logic s_axi_rready;
    logic s_axi_rid;
    logic s_axi_rdata;
    logic s_axi_rresp;
    logic s_axi_rlast;
    logic s_axi_rvalid;
    logic init_calib_complete;
    logic device_temp;
    
    `ifdef
        logic calib_tap_req;
        logic calib_tap_load;
        logic calib_tap_addr;
        logic calib_tap_val;
        logic calib_tap_load_done;
    `endif
    
    logic sys_rst;
    

    mig_7series_0 mig_7series_0(
        // Inouts
        .ddr3_dq        (dq0),
        .ddr3_dqs_n     (dqs_n),
        .ddr3_dqs_p     (dqs),
        // Outputs
        .ddr3_addr      (a),
        .ddr3_ba        (ba),
        .ddr3_ras_n     (ras_n),
        .ddr3_cas_n     (cas_n),
        .ddr3_we_n      (we_n),
        .ddr3_reset_n   (rst_n),
        .ddr3_ck_p      (ck),
        .ddr3_ck_n      (ck_n),
        .ddr3_cke       (cke),
        .ddr3_dm        (dm),
        .ddr3_odt       (odt),
        // Inputs
        // Single-ended system clock
        .sys_clk_i      (sys_clk_i),
        // Single-ended iodelayctrl clk (reference clock)
        .clk_ref_i      (clk_ref_i),
        // user interface signals
        .ui_clk         (ui_clk),
        .ui_clk_sync_rst(ui_clk_sync_rst),
        .mmcm_locked    (mmcm_locked),
        .aresetn        (aresetn),
        .app_sr_req     (app_sr_req),
        .app_ref_req    (app_ref_req),
        .app_zq_req     (app_zq_req),
        .app_sr_active  (app_sr_active),
        .app_ref_ack    (app_ref_ack),
        .app_zq_ack     (app_zq_ack),
        // Slave Interface Write Address Ports
        .s_axi_awid     (s_axi_awid),
        .s_axi_awaddr   (s_axi_awaddr),
        .s_axi_awlen    (s_axi_awlen),
        .s_axi_awsize   (s_axi_awsize),
        .s_axi_awburst  (s_axi_awburst),
        .s_axi_awlock   (s_axi_awlock),
        .s_axi_awcache  (s_axi_awcache),
        .s_axi_awprot   (s_axi_awprot),
        .s_axi_awqos    (s_axi_awqos),
        .s_axi_awvalid  (s_axi_awvalid),
        .s_axi_awready  (s_axi_awready),
        // Slave Interface Write Data Ports
        .s_axi_wdata    (s_axi_wdata),
        .s_axi_wstrb    (s_axi_wstrb),
        .s_axi_wlast    (s_axi_wlast),
        .s_axi_wvalid   (s_axi_wvalid),
        .s_axi_wready   (s_axi_wready),
        // Slave Interface Write Response Ports
        .s_axi_bready   (s_axi_bready),
        .s_axi_bid      (s_axi_bid),
        .s_axi_bresp    (s_axi_bresp),
        .s_axi_bvalid   (s_axi_bvalid),
        // Slave Interface Read Address Ports
        .s_axi_arid     (s_axi_arid),
        .s_axi_araddr   (s_axi_araddr),
        .s_axi_arlen    (s_axi_arlen),
        .s_axi_arsize   (s_axi_arsize),
        .s_axi_arburst  (s_axi_arburst),
        .s_axi_arlock   (s_axi_arlock),
        .s_axi_arcache  (s_axi_arcache),
        .s_axi_arprot   (s_axi_arprot),
        .s_axi_arqos    (s_axi_arqos),
        .s_axi_arvalid  (s_axi_arvalid),
        .s_axi_arready  (s_axi_arready),
        // Slave Interface Read Data Ports
        .s_axi_rready   (s_axi_rready),
        .s_axi_rid      (s_axi_rid),
        .s_axi_rdata    (s_axi_rdata),
        .s_axi_rresp    (s_axi_rresp),
        .s_axi_rlast    (s_axi_rlast),
        .s_axi_rvalid   (s_axi_rvalid),
        .init_calib_complete(init_calib_complete),
        .device_temp    (device_temp),
        `ifdef SKIP_CALIB
          .calib_tap_req    (calib_tap_req),
          .calib_tap_load   (calib_tap_load),
          .calib_tap_addr   (calib_tap_addr),
          .calib_tap_val    (calib_tap_val),
          .calib_tap_load_done(calib_tap_load_done),
        `endif
        
        .sys_rst        (sys_rst)
    );

    // component instantiation
    ddr3_den4096Mb sdramddr3_0 (
        rst_n,
        ck, 
        ck_n,
        cke, 
        cs_n,       // コントロールしない
        ras_n, 
        cas_n, 
        we_n, 
        dm, 
        ba, 
        a, 
        dq0, 
        dqs,
        dqs_n,
        tdqs_n,     // 未使用
        odt
    );

    assign cs_n = 1'b0;

    // clock generator
    initial begin
        forever begin
            #5000 sys_clk_i = 0;
            #5000 sys_clk_i = 1;
        end
    end
    
    initial begin
        forever begin
            #2500 clk_ref_i = 0;
            #2500 clk_ref_i = 1;
        end
    end
    
    initial begin
        aresetn = 1;
        #400000 aresetn = 0;
        #400000 aresetn = 1;
    end
    
    function integer ceil;
        input number;
        real number;
        if (number > $rtoi(number))
            ceil = $rtoi(number) + 1;
        else
            ceil = number;
    endfunction

    function integer max;
        input arg1;
        input arg2;
        integer arg1;
        integer arg2;
        if (arg1 > arg2)
            max = arg1;
        else
            max = arg2;
    endfunction

    // Test included from external file
    //`include "subtest.vh"

endmodule

//module dqrx (
//    ptr_rst_n, dqs, dq, q0, q1, q2, q3
//);

//`ifdef den1024Mb
//    `include "1024Mb_ddr3_parameters.vh"
//`elsif den2048Mb
//    `include "2048Mb_ddr3_parameters.vh"
//`elsif den4096Mb
//    `include "4096Mb_ddr3_parameters.vh"
//`elsif den8192Mb
//    `include "8192Mb_ddr3_parameters.vh"
//`else
//    // NOTE: Intentionally cause a compile fail here to force the users
//    //       to select the correct component density before continuing
//    ERROR: You must specify component density with +define+den____Mb.
//`endif

//    input  ptr_rst_n;
//    input  dqs;
//    input  [DQ_BITS/DQS_BITS-1:0] dq;
//    output [DQ_BITS/DQS_BITS-1:0] q0;
//    output [DQ_BITS/DQS_BITS-1:0] q1;
//    output [DQ_BITS/DQS_BITS-1:0] q2;
//    output [DQ_BITS/DQS_BITS-1:0] q3;

//    reg [1:0] ptr;
//    reg [DQ_BITS/DQS_BITS-1:0] q [3:0];

//    reg ptr_rst_dly_n;
//    always @(ptr_rst_n) ptr_rst_dly_n <= #(TDQSCK + TDQSQ + 2) ptr_rst_n;

//    reg dqs_dly;
//    always @(dqs) dqs_dly <= #(TDQSQ + 1) dqs;

//    always @(negedge ptr_rst_dly_n or posedge dqs_dly or negedge dqs_dly) begin
//        if (!ptr_rst_dly_n) begin
//            ptr <= 0;
//        end else if (dqs_dly || ptr) begin
//            q[ptr] <= dq;
//            ptr <= ptr + 1;
//        end
//    end
    
//    assign q0 = q[0];
//    assign q1 = q[1];
//    assign q2 = q[2];
//    assign q3 = q[3];
//endmodule
