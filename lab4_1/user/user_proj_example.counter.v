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
    parameter DELAYS=10
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

    assign bram_WE0 = {(4){wbs_we_i}};
    assign bram_EN0 = (wbs_cyc_i && wbs_stb_i && wbs_we_i && wbs_adr_i[29:27] == 3'b111) ? 1 :
                      (counter == 8 && wbs_adr_i[29:27] == 3'b111) ? 1 : 0;
    assign bram_Di0 = wbs_dat_i;
    assign bram_A0 = {{5'b00000}, wbs_adr_i[26:0]};
    assign wbs_dat_o = (counter == 10) ? wbs_dat_buffer : 0;
    assign wbs_dat_buffer_next = (counter == 9) ? bram_Do0 : wbs_dat_buffer;

    assign io_out = 0;
    assign io_oeb = 1;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            counter <= 0;
            wbs_dat_buffer <= 0;
            wbs_ack_o_tmp <= 0;
        end else begin
            counter <= counter_next;
            wbs_dat_buffer <= wbs_dat_buffer_next;
            wbs_ack_o_tmp <= wbs_ack_o_next;
        end
    end
    
    always @(*) begin
        if (wbs_cyc_i && wbs_adr_i[29:27] == 3'b111 && !(|wbs_we_i) && !(counter == 10)) begin //meaning that wbs_adr_i is in 0x38000000
            counter_next = counter + 1;
        end else if (counter == 10 || !wbs_cyc_i)begin
            counter_next = 0;
        end else begin
            counter_next = counter;
        end
    end

    assign wbs_ack_o = (wbs_cyc_i && wbs_stb_i && wbs_we_i && wbs_adr_i[29:27] == 3'b111) ? 1 :
                       (counter == 10) ? 1 : 0;

    bram user_bram (
        .CLK(clk),
        .WE0(bram_WE0),
        .EN0(bram_EN0),
        .Di0(bram_Di0),
        .Do0(bram_Do0),
        .A0(bram_A0)
    );

endmodule



`default_nettype wire
