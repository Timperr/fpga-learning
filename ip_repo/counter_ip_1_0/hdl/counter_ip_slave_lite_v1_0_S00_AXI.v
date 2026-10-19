`timescale 1 ns / 1 ps

module counter_ip_slave_lite_v1_0_S00_AXI #(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 4
)(
    output wire [31:0] window,
    output reg start_pulse,
    input wire [31:0] count,
    input wire [31:0] status,
    input wire S_AXI_ACLK,
    input wire S_AXI_ARESETN,
    input wire [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_AWADDR,
    input wire [2:0] S_AXI_AWPROT,
    input wire S_AXI_AWVALID,
    output wire S_AXI_AWREADY,
    input wire [C_S_AXI_DATA_WIDTH-1:0] S_AXI_WDATA,
    input wire [(C_S_AXI_DATA_WIDTH/8)-1:0] S_AXI_WSTRB,
    input wire S_AXI_WVALID,
    output wire S_AXI_WREADY,
    output wire [1:0] S_AXI_BRESP,
    output wire S_AXI_BVALID,
    input wire S_AXI_BREADY,
    input wire [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_ARADDR,
    input wire [2:0] S_AXI_ARPROT,
    input wire S_AXI_ARVALID,
    output wire S_AXI_ARREADY,
    output reg [C_S_AXI_DATA_WIDTH-1:0] S_AXI_RDATA,
    output wire [1:0] S_AXI_RRESP,
    output reg S_AXI_RVALID,
    input wire S_AXI_RREADY
);

    localparam integer ADDR_LSB = 2;
    reg [31:0] window_reg, control_reg;
    reg [C_S_AXI_ADDR_WIDTH-1:0] awaddr_hold;
    reg [C_S_AXI_DATA_WIDTH-1:0] wdata_hold;
    reg [(C_S_AXI_DATA_WIDTH/8)-1:0] wstrb_hold;
    reg aw_pending, w_pending, bvalid_reg;
    reg [C_S_AXI_ADDR_WIDTH-1:0] araddr_hold;
    reg arready_reg;
    reg [31:0] write_data;
    reg [(C_S_AXI_DATA_WIDTH/8)-1:0] write_strb;
    reg [C_S_AXI_ADDR_WIDTH-1:0] write_addr;
    reg write_fire;
    integer i;

    assign window = window_reg;
    assign S_AXI_AWREADY = S_AXI_ARESETN && !aw_pending && !bvalid_reg;
    assign S_AXI_WREADY = S_AXI_ARESETN && !w_pending && !bvalid_reg;
    assign S_AXI_BVALID = bvalid_reg;
    assign S_AXI_BRESP = 2'b00;
    assign S_AXI_ARREADY = arready_reg;
    assign S_AXI_RRESP = 2'b00;

    always @* begin
        write_addr = aw_pending ? awaddr_hold : S_AXI_AWADDR;
        write_data = w_pending ? wdata_hold : S_AXI_WDATA;
        write_strb = w_pending ? wstrb_hold : S_AXI_WSTRB;
        write_fire = (aw_pending || (S_AXI_AWVALID && S_AXI_AWREADY)) &&
                     (w_pending || (S_AXI_WVALID && S_AXI_WREADY)) && !bvalid_reg;
    end

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            window_reg <= 0;
            control_reg <= 0;
            awaddr_hold <= 0;
            wdata_hold <= 0;
            wstrb_hold <= 0;
            aw_pending <= 0;
            w_pending <= 0;
            bvalid_reg <= 0;
            start_pulse <= 0;
        end else begin
            start_pulse <= 0;
            if (S_AXI_BVALID && S_AXI_BREADY)
                bvalid_reg <= 0;

            if (S_AXI_AWVALID && S_AXI_AWREADY) begin
                if (write_fire && !aw_pending)
                    aw_pending <= 0;
                else begin
                    awaddr_hold <= S_AXI_AWADDR;
                    aw_pending <= 1;
                end
            end
            if (S_AXI_WVALID && S_AXI_WREADY) begin
                if (write_fire && !w_pending)
                    w_pending <= 0;
                else begin
                    wdata_hold <= S_AXI_WDATA;
                    wstrb_hold <= S_AXI_WSTRB;
                    w_pending <= 1;
                end
            end

            if (write_fire) begin
                aw_pending <= 0;
                w_pending <= 0;
                bvalid_reg <= 1;
                case (write_addr[ADDR_LSB+1:ADDR_LSB])
                    2'd0: for (i=0; i<C_S_AXI_DATA_WIDTH/8; i=i+1)
                        if (write_strb[i] && i < 4) window_reg[i*8 +: 8] <= write_data[i*8 +: 8];
                    2'd1: for (i=0; i<C_S_AXI_DATA_WIDTH/8; i=i+1)
                        if (write_strb[i] && i < 4) control_reg[i*8 +: 8] <= write_data[i*8 +: 8];
                    default: ; // Result and status registers are read-only.
                endcase
                if (write_addr[ADDR_LSB+1:ADDR_LSB] == 2'd1 &&
                    write_strb[0] && write_data[0]) start_pulse <= 1;
            end
        end
    end

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            araddr_hold <= 0;
            arready_reg <= 0;
            S_AXI_RVALID <= 0;
            S_AXI_RDATA <= 0;
        end else begin
            if (!arready_reg && !S_AXI_RVALID)
                arready_reg <= 1;
            if (S_AXI_ARVALID && S_AXI_ARREADY) begin
                araddr_hold <= S_AXI_ARADDR;
                arready_reg <= 0;
                S_AXI_RVALID <= 1;
                case (S_AXI_ARADDR[ADDR_LSB+1:ADDR_LSB])
                    2'd0: S_AXI_RDATA <= window_reg;
                    2'd1: S_AXI_RDATA <= control_reg;
                    2'd2: S_AXI_RDATA <= count;
                    2'd3: S_AXI_RDATA <= status;
                endcase
            end else if (S_AXI_RVALID && S_AXI_RREADY) begin
                S_AXI_RVALID <= 0;
                arready_reg <= 1;
            end
        end
    end
endmodule
