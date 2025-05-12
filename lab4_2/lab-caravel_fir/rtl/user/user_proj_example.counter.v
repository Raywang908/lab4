// SPDX-FileCopyrightText: 2020 Efabless Corporation
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// SPDX-License-Identifier: Apache-2.0

`default_nettype none
/*
 *-------------------------------------------------------------
 *
 * user_proj_example
 *
 * This is an example of a (trivially simple) user project,
 * showing how the user project can connect to the logic
 * analyzer, the wishbone bus, and the I/O pads.
 *
 * This project generates an integer count, which is output
 * on the user area GPIO pads (digital output only).  The
 * wishbone connection allows the project to be controlled
 * (start and stop) from the management SoC program.
 *
 * See the testbenches in directory "mprj_counter" for the
 * example programs that drive this user project.  The three
 * testbenches are "io_ports", "la_test1", and "la_test2".
 *
 *-------------------------------------------------------------
 */

module user_proj_example #(
    parameter BITS = 32,
    parameter DELAYS=10,
    parameter pADDR_WIDTH = 12,
    parameter pDATA_WIDTH = 32,
    parameter DATA_NUM = 64
)(
`ifdef USE_POWER_PINS
    inout vccd1,	// User area 1 1.8V supply
    inout vssd1,	// User area 1 digital ground
`endif

    // Wishbone Slave ports (WB MI A)
    input wb_clk_i,
    input wb_rst_i,
    input wbs_stb_i,
    input wbs_cyc_i,
    input wbs_we_i,
    input [3:0] wbs_sel_i,
    input [31:0] wbs_dat_i,
    input [31:0] wbs_adr_i,
    output wbs_ack_o,
    output [31:0] wbs_dat_o,

    // Logic Analyzer Signals
    input  [127:0] la_data_in,
    output [127:0] la_data_out,
    input  [127:0] la_oenb,

    // IOs
    input  [`MPRJ_IO_PADS-1:0] io_in,
    output [`MPRJ_IO_PADS-1:0] io_out,
    output [`MPRJ_IO_PADS-1:0] io_oeb,

    // IRQ
    output [2:0] irq
);

//========================== Declaration ==========================
//-------------------------- BRAM read/write instruction ------------------------------- 
    wire clk;
    wire rst;
    assign clk = wb_clk_i;
    assign rst = wb_rst_i;

    wire [`MPRJ_IO_PADS-1:0] io_in;
    wire [`MPRJ_IO_PADS-1:0] io_out;
    wire [`MPRJ_IO_PADS-1:0] io_oeb;

    reg [3:0] counter;
    reg [3:0] counter_next;
    reg [31:0] wbs_dat_buffer;
    wire [31:0] wbs_dat_buffer_next;
    wire wbs_ack_o_next;
    reg wbs_ack_o_tmp;
    
    wire [3:0] bram_WE0;
    wire bram_EN0;
    wire [31:0] bram_Di0;
    wire [31:0] bram_Do0;
    wire [31:0] bram_A0;
    localparam [4:0] HEX38 = 5'b00111;
    wire Insc_w;
    reg rtap_delay;
    wire rtap_delay_next;

//-------------------------- Axi_Lite ------------------------------- 
    wire                     awready;
    wire                     wready;
    wire                     awvalid;
    reg                      awvalid_tmp;
    reg                      awvalid_next;
    wire [(pADDR_WIDTH-1):0] awaddr;
    wire                     wvalid;
    reg                      wvalid_next;
    reg                      wvalid_tmp;
    wire [(pDATA_WIDTH-1):0] wdata;
    wire                     arready;
    wire                     rready;
    reg                      rready_tmp;
    reg                      rready_next;
    wire                     arvalid;
    reg                      arvalid_next;
    reg                      arvalid_tmp;
    wire [(pADDR_WIDTH-1):0] araddr;
    wire                     rvalid;
    wire [(pDATA_WIDTH-1):0] rdata;    
// bram for tap RAM
    wire [3:0]               tap_WE;
    wire                     tap_EN;
    wire [(pDATA_WIDTH-1):0] tap_Di;
    wire [(pADDR_WIDTH-1):0] tap_A;
    wire [(pDATA_WIDTH-1):0] tap_Do;
// bram for data RAM
    wire [3:0]               data_WE;
    wire                     data_EN;
    wire [(pDATA_WIDTH-1):0] data_Di;
    wire [(pADDR_WIDTH-1):0] data_A;
    wire [(pDATA_WIDTH-1):0] data_Do;
    
    localparam [23:0] HEX300000 = 24'h300000;
    localparam [7:0] AP_ADR = 8'h00;
    localparam [7:0] X_ADR = 8'h40;
    localparam [7:0] Y_ADR = 8'h44;
    localparam [7:0] DATA_LENGTH = 8'h10;
    localparam [7:0] TAP_LENGTH = 8'h14;
    wire                    axi_write;
    wire                    axi_read;

//-------------------------- Axi_Stream ------------------------------- 
    wire                     ss_tvalid; 
    reg                      ss_tvalid_next;
    reg                      ss_tvalid_tmp;
    wire [(pDATA_WIDTH-1):0] ss_tdata; 
    wire                     ss_tlast; 
    wire                     ss_tready; 
    wire                     sm_tready;
    reg                      sm_tready_next; 
    reg                      sm_tready_tmp; 
    wire                     sm_tvalid; 
    wire [(pDATA_WIDTH-1):0] sm_tdata; 
    wire                     sm_tlast; 

    reg [(pDATA_WIDTH-1):0] ss_tcnter_next;
    reg [(pDATA_WIDTH-1):0] ss_tcnter;

//========================== Function ==========================
//-------------------------- BRAM read/write instruction -------------------------------
    assign bram_WE0 = {(4){wbs_we_i}};
    assign bram_EN0 = (wbs_cyc_i && wbs_stb_i && wbs_we_i && wbs_adr_i[31:27] == HEX38) ? 1 :
                      (counter == 8 && wbs_adr_i[31:27] == HEX38) ? 1 : 0;
    assign bram_Di0 = wbs_dat_i;
    assign bram_A0 = {{5'b00000}, wbs_adr_i[26:0]};
    assign wbs_dat_o = (counter == 10 || rtap_delay) ? wbs_dat_buffer : 
                       (axi_read && rvalid && !(wbs_adr_i[7] == 1)) ? rdata :  
                       (sm_tvalid && sm_tready) ? sm_tdata : 0;
    assign wbs_dat_buffer_next = (counter == 9) ? bram_Do0 : 
                                 (rtap_delay_next) ? rdata : wbs_dat_buffer;

    assign io_out = 0;
    assign io_oeb = 1;
    assign Insc_w = wbs_cyc_i && wbs_stb_i && wbs_we_i && wbs_adr_i[31:27] == HEX38;
    assign rtap_delay_next = rvalid && rready && wbs_adr_i[7] == 1;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            counter <= 0;
            wbs_dat_buffer <= 0;
            wbs_ack_o_tmp <= 0;
            rtap_delay <= 0;
        end else begin
            counter <= counter_next;
            wbs_dat_buffer <= wbs_dat_buffer_next;
            wbs_ack_o_tmp <= wbs_ack_o_next;
            rtap_delay <= rtap_delay_next;
        end
    end
    
    always @(*) begin
        if (wbs_cyc_i && wbs_adr_i[31:27] == HEX38 && !(|wbs_we_i) && !(counter == 10)) begin //meaning that wbs_adr_i is in 0x38000000
            counter_next = counter + 1;
        end else if (counter == 10 || !wbs_cyc_i)begin
            counter_next = 0;
        end else begin
            counter_next = counter;
        end
    end

    assign wbs_ack_o = (Insc_w || axi_write && (wready && awready || ss_tready) 
                        || axi_read && (rvalid && !(wbs_adr_i[7] == 1) || sm_tvalid && sm_tready) 
                        || counter == 10 || rtap_delay) ? 1 : 0;

//-------------------------- Axi_Lite ------------------------------- 
    assign axi_write = wbs_cyc_i && wbs_stb_i && wbs_we_i && wbs_adr_i[31:8] == HEX300000;
    assign axi_read = wbs_cyc_i && wbs_stb_i && !wbs_we_i && wbs_adr_i[31:8] == HEX300000;
    
    assign awaddr = (awvalid) ? wbs_adr_i[(pADDR_WIDTH-1):0] : 0;
    assign araddr = (arvalid)? wbs_adr_i[(pADDR_WIDTH-1):0] : 0;
    assign wdata = (wvalid) ? wbs_dat_i : 0;

    assign awvalid = awvalid_tmp;
    assign wvalid = wvalid_tmp;
    assign arvalid = arvalid_tmp;
    assign rready = rready_tmp;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            awvalid_tmp <= 0;
            wvalid_tmp <= 0;
            arvalid_tmp <= 0;
            rready_tmp <= 0;
        end else begin
            awvalid_tmp <= awvalid_next;
            wvalid_tmp <= wvalid_next;
            arvalid_tmp <= arvalid_next;
            rready_tmp <= rready_next;
        end
    end

    always @(*) begin
        if (axi_write && (wbs_adr_i[7] == 1 || wbs_adr_i[7:0] == DATA_LENGTH || wbs_adr_i[7:0] == TAP_LENGTH || wbs_adr_i[7:0] == AP_ADR) && !wready) begin
            awvalid_next = 1;
            wvalid_next = 1;
        end else if (wready && awready) begin
            awvalid_next = 0;
            wvalid_next = 0;
        end else begin
            awvalid_next = awvalid_tmp;
            wvalid_next = wvalid_tmp;
        end
    end

    always @(*) begin
        if (axi_read && (wbs_adr_i[7] == 1 || wbs_adr_i[7:0] == DATA_LENGTH || wbs_adr_i[7:0] == TAP_LENGTH || wbs_adr_i[7:0] == AP_ADR) && !rready_tmp && !rtap_delay) begin
            arvalid_next = 1;
            rready_next = 1;
        end else if (arready) begin
            arvalid_next = 0;
            rready_next = rready_tmp;
        end else if (rvalid) begin
            arvalid_next = arvalid_tmp;
            rready_next = 0;
        end else begin
            arvalid_next = arvalid_tmp;
            rready_next = rready_tmp;
        end
    end

//-------------------------- Axi_Stream ------------------------------- 
    assign ss_tvalid = ss_tvalid_tmp;
    assign sm_tready = sm_tready_tmp;
    assign ss_tdata = (ss_tvalid)? wbs_dat_i : 0;
    assign ss_tlast = (ss_tcnter == DATA_NUM) ? 1 : 0;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ss_tvalid_tmp <= 0;
            sm_tready_tmp <= 0;
            ss_tcnter <= 0; 
        end else begin
            ss_tvalid_tmp <= ss_tvalid_next;
            sm_tready_tmp <= sm_tready_next; 
            ss_tcnter <= ss_tcnter_next;
        end
    end

    always @(*) begin
        if (axi_write && wbs_adr_i[7:0] == X_ADR && !ss_tready) begin
            ss_tvalid_next = 1;
        end else if (ss_tready) begin
            ss_tvalid_next = 0;
        end else begin
            ss_tvalid_next = ss_tvalid_tmp;
        end
    end

    always @(*) begin
        if (axi_read && wbs_adr_i[7:0] == Y_ADR && !sm_tready_tmp) begin
            sm_tready_next = 1;
        end else if (sm_tvalid) begin
            sm_tready_next = 0;
        end else begin
            sm_tready_next = sm_tready_tmp;
        end
    end

    always @(*) begin
        if (axi_write && wbs_adr_i[7:0] == X_ADR && !ss_tvalid) begin
            ss_tcnter_next = ss_tcnter + 1;
        end else if (ss_tcnter == DATA_NUM && ss_tready) begin
            ss_tcnter_next = 0;
        end else begin
            ss_tcnter_next = ss_tcnter;
        end
    end

//========================== Instantiate Module ==========================
    bram user_bram (
        .CLK(clk),
        .WE0(bram_WE0),
        .EN0(bram_EN0),
        .Di0(bram_Di0),
        .Do0(bram_Do0),
        .A0(bram_A0)
    );

    fir #(
        .Tape_Num(11),
        .pDATA_WIDTH(pDATA_WIDTH),
        .pADDR_WIDTH(pADDR_WIDTH)
    )  
    fir_DUT(
        .awready(awready),
        .wready(wready),
        .awvalid(awvalid),
        .awaddr(awaddr),
        .wvalid(wvalid),
        .wdata(wdata),
        .arready(arready),
        .rready(rready),
        .arvalid(arvalid),
        .araddr(araddr),
        .rvalid(rvalid),
        .rdata(rdata),
        .ss_tvalid(ss_tvalid),
        .ss_tdata(ss_tdata),
        .ss_tlast(ss_tlast),
        .ss_tready(ss_tready),
        .sm_tready(sm_tready),
        .sm_tvalid(sm_tvalid),
        .sm_tdata(sm_tdata),
        .sm_tlast(sm_tlast),

        // ram for tap
        .tap_WE(tap_WE),
        .tap_EN(tap_EN),
        .tap_Di(tap_Di),
        .tap_A(tap_A),
        .tap_Do(tap_Do),

        // ram for data
        .data_WE(data_WE),
        .data_EN(data_EN),
        .data_Di(data_Di),
        .data_A(data_A),
        .data_Do(data_Do),

        .axis_clk(clk),
        .axis_rst_n(~rst)
    );

    // RAM for tap
    bram32 tap_RAM (
        .CLK(clk),
        .WE(tap_WE),
        .EN(tap_EN),
        .Di(tap_Di),
        .A(tap_A),
        .Do(tap_Do)
    );

    // RAM for data: choose bram11 or bram12
    bram32 data_RAM(
        .CLK(clk),
        .WE(data_WE),
        .EN(data_EN),
        .Di(data_Di),
        .A(data_A),
        .Do(data_Do)
    );

    

endmodule



`default_nettype wire
