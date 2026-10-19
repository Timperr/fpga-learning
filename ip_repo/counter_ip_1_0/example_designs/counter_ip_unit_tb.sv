`timescale 1ns/1ps

// Self-checking unit test for the frequency-counter IP.
// Compile with counter_ip.v and counter_ip_slave_lite_v1_0_S00_AXI.v.
module counter_ip_unit_tb;
    reg clk = 1'b0;
    reg resetn = 1'b0;
    reg sig_in = 1'b0;

    reg [3:0] awaddr = 0;
    reg awvalid = 0;
    wire awready;
    reg [31:0] wdata = 0;
    reg [3:0] wstrb = 4'hF;
    reg wvalid = 0;
    wire wready;
    wire [1:0] bresp;
    wire bvalid;
    reg bready = 0;
    reg [3:0] araddr = 0;
    reg arvalid = 0;
    wire arready;
    wire [31:0] rdata;
    wire [1:0] rresp;
    wire rvalid;
    reg rready = 0;

    integer half_period = 50;
    integer phase_count = 0;
    integer sample_count = 0;
    reg signal_enable = 0;
    integer errors = 0;
    reg [31:0] status_value;
    reg [31:0] count_value;

    always #5 clk = ~clk;

    // Generate a square wave whose rising edge is half a period after enable.
    always @(negedge clk) begin
        if (!signal_enable) begin
            phase_count <= 0;
            sig_in <= 1'b0;
        end else if (phase_count == half_period-1) begin
            phase_count <= 0;
            sig_in <= ~sig_in;
            sample_count <= sample_count + 1;
        end else begin
            phase_count <= phase_count + 1;
        end
    end

    counter_ip #(
        .C_S00_AXI_DATA_WIDTH(32),
        .C_S00_AXI_ADDR_WIDTH(4)
    ) dut (
        .clk(clk),
        .sig_in(sig_in),
        .s00_axi_aclk(clk),
        .s00_axi_aresetn(resetn),
        .s00_axi_awaddr(awaddr),
        .s00_axi_awprot(3'b000),
        .s00_axi_awvalid(awvalid),
        .s00_axi_awready(awready),
        .s00_axi_wdata(wdata),
        .s00_axi_wstrb(wstrb),
        .s00_axi_wvalid(wvalid),
        .s00_axi_wready(wready),
        .s00_axi_bresp(bresp),
        .s00_axi_bvalid(bvalid),
        .s00_axi_bready(bready),
        .s00_axi_araddr(araddr),
        .s00_axi_arprot(3'b000),
        .s00_axi_arvalid(arvalid),
        .s00_axi_arready(arready),
        .s00_axi_rdata(rdata),
        .s00_axi_rresp(rresp),
        .s00_axi_rvalid(rvalid),
        .s00_axi_rready(rready)
    );

    task automatic axi_write(input [3:0] addr, input [31:0] data);
        begin
            @(negedge clk);
            awaddr = addr;
            wdata = data;
            awvalid = 1;
            wvalid = 1;
            bready = 0;
            fork
                begin
                    do @(posedge clk); while (!awready);
                    @(negedge clk); awvalid = 0;
                end
                begin
                    do @(posedge clk); while (!wready);
                    @(negedge clk); wvalid = 0;
                end
            join
            bready = 1;
            do @(posedge clk); while (!bvalid);
            @(negedge clk);
            bready = 0;
            if (bresp != 2'b00) begin
                $display("FAIL: AXI write response %b at address %h", bresp, addr);
                errors = errors + 1;
            end
        end
    endtask

    task automatic axi_read(input [3:0] addr, output [31:0] data);
        begin
            @(negedge clk);
            araddr = addr;
            arvalid = 1;
            rready = 0;
            do @(posedge clk); while (!arready);
            @(negedge clk);
            arvalid = 0;
            rready = 1;
            do @(posedge clk); while (!rvalid);
            data = rdata;
            @(negedge clk);
            rready = 0;
            if (rresp != 2'b00) begin
                $display("FAIL: AXI read response %b at address %h", rresp, addr);
                errors = errors + 1;
            end
        end
    endtask

    task automatic wait_for_done;
        integer cycles;
        begin
            cycles = 0;
            status_value = 0;
            while (status_value[0] == 0 && cycles < 10000) begin
                axi_read(4'hC, status_value);
                cycles = cycles + 1;
            end
            if (status_value[0] !== 1'b1) begin
                $display("FAIL: STATUS did not become 1 before timeout");
                errors = errors + 1;
            end
        end
    endtask

    task automatic check_case(
        input integer test_no,
        input integer window_cycles,
        input integer period_cycles,
        input integer expected_min,
        input integer expected_max
    );
        begin
            signal_enable = 0;
            sig_in = 0;
            repeat (4) @(negedge clk);
            axi_write(4'h0, window_cycles);
            axi_write(4'h4, 1);
            half_period = period_cycles / 2;
            phase_count = 0;
            signal_enable = 1;
            wait_for_done();
            signal_enable = 0;
            axi_read(4'h8, count_value);
            if (count_value < expected_min || count_value > expected_max) begin
                $display("FAIL: case %0d WINDOW=%0d period=%0d COUNT=%0d expected [%0d,%0d]",
                         test_no, window_cycles, period_cycles, count_value,
                         expected_min, expected_max);
                errors = errors + 1;
            end else begin
                $display("PASS: case %0d WINDOW=%0d period=%0d COUNT=%0d",
                         test_no, window_cycles, period_cycles, count_value);
            end
            repeat (4) @(negedge clk);
        end
    endtask

    initial begin
        repeat (5) @(negedge clk);
        resetn = 1;
        repeat (5) @(negedge clk);

        // Integer-period windows: 1000/100 = 10 and 2000/40 = 50.
        check_case(1, 1000, 100, 10, 10);
        check_case(2, 2000, 40, 50, 50);

        // A 250-cycle window spans 2.5 periods; phase determines 2 or 3 edges.
        check_case(3, 250, 100, 2, 3);

        if (errors == 0) begin
            $display("ALL COUNTER TESTS PASSED");
            $finish;
        end else begin
            $display("COUNTER TESTS FAILED: %0d error(s)", errors);
            $fatal(1);
        end
    end

    initial begin
        #2000000;
        $fatal(1, "Testbench global timeout");
    end
endmodule
