
`timescale 1ns / 1ps

module tb_counter_system;

    logic reset_rtl = 1'b0;
    logic sig_in_0  = 1'b0;
    logic sys_clock = 1'b0;

    localparam time CLK_PERIOD      = 10ns;
    localparam time SIG_HALF_PERIOD = 500ns;
    localparam time RESET_TIME      = 200ns;
    localparam time TIMEOUT         = 10ms;

    always #(CLK_PERIOD / 2) sys_clock = ~sys_clock;
    always #(SIG_HALF_PERIOD) sig_in_0 = ~sig_in_0;

    design_1_wrapper dut (
        .reset_rtl (reset_rtl),
        .sig_in_0  (sig_in_0),
        .sys_clock (sys_clock)
    );

    initial begin
        $display("[%0t] SYSTEM TEST START", $time);

        reset_rtl = 1'b0;
        #(RESET_TIME);
        reset_rtl = 1'b1;

        $display("[%0t] RESET RELEASED", $time);

        fork
            begin
                // Wait until the hardware measurement completes.
               // Wait until MicroBlaze reads COUNT through AXI.
                wait (
                    dut.design_1_i.axi_smc.S00_AXI_arvalid &&
                    dut.design_1_i.axi_smc.S00_AXI_arready &&
                    dut.design_1_i.axi_smc.S00_AXI_araddr == 32'h44A00008
                );
                
                $display("[%0t] COUNT register read requested", $time);
                
                // Allow the AXI read response and firmware to finish.
                #100us;
                
                $display("[%0t] SYSTEM TEST FINISHED", $time);
                $finish;
            end

            begin
                #(TIMEOUT);
                $error("[%0t] TIMEOUT: measurement did not complete", $time);
                $finish;
            end
        join_any
        disable fork;
    end

endmodule
