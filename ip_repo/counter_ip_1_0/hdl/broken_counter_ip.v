
`timescale 1 ns / 1 ps

	module counter_ip #
	(
		// Users to add parameters here

		// User parameters ends
		// Do not modify the parameters beyond this line


		// Parameters of Axi Slave Bus Interface S00_AXI
		parameter integer C_S00_AXI_DATA_WIDTH	= 32,
		parameter integer C_S00_AXI_ADDR_WIDTH	= 4
	)
	(
		// Users to add ports here
        input wire sig_in,
        input wire clk,
		// User ports ends
		// Do not modify the ports beyond this line


		// Ports of Axi Slave Bus Interface S00_AXI
		input wire  s00_axi_aclk,
		input wire  s00_axi_aresetn,
		input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_awaddr,
		input wire [2 : 0] s00_axi_awprot,
		input wire  s00_axi_awvalid,
		output wire  s00_axi_awready,
		input wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_wdata,
		input wire [(C_S00_AXI_DATA_WIDTH/8)-1 : 0] s00_axi_wstrb,
		input wire  s00_axi_wvalid,
		output wire  s00_axi_wready,
		output wire [1 : 0] s00_axi_bresp,
		output wire  s00_axi_bvalid,
		input wire  s00_axi_bready,
		input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_araddr,
		input wire [2 : 0] s00_axi_arprot,
		input wire  s00_axi_arvalid,
		output wire  s00_axi_arready,
		output wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_rdata,
		output wire [1 : 0] s00_axi_rresp,
		output wire  s00_axi_rvalid,
		input wire  s00_axi_rready
	);
// Instantiation of Axi Bus Interface S00_AXI
    reg [31:0] count;
    reg [31:0] status;
    wire [31:0] window;
    wire start_pulse;
	counter_ip_slave_lite_v1_0_S00_AXI # ( 
		.C_S_AXI_DATA_WIDTH(C_S00_AXI_DATA_WIDTH),
		.C_S_AXI_ADDR_WIDTH(C_S00_AXI_ADDR_WIDTH)
	) counter_ip_slave_lite_v1_0_S00_AXI_inst (
	    .window(window),
	    .start_pulse(start_pulse),
        .count(count),
        .status(status),
		.S_AXI_ACLK(s00_axi_aclk),
		.S_AXI_ARESETN(s00_axi_aresetn),
		.S_AXI_AWADDR(s00_axi_awaddr),
		.S_AXI_AWPROT(s00_axi_awprot),
		.S_AXI_AWVALID(s00_axi_awvalid),
		.S_AXI_AWREADY(s00_axi_awready),
		.S_AXI_WDATA(s00_axi_wdata),
		.S_AXI_WSTRB(s00_axi_wstrb),
		.S_AXI_WVALID(s00_axi_wvalid),
		.S_AXI_WREADY(s00_axi_wready),
		.S_AXI_BRESP(s00_axi_bresp),
		.S_AXI_BVALID(s00_axi_bvalid),
		.S_AXI_BREADY(s00_axi_bready),
		.S_AXI_ARADDR(s00_axi_araddr),
		.S_AXI_ARPROT(s00_axi_arprot),
		.S_AXI_ARVALID(s00_axi_arvalid),
		.S_AXI_ARREADY(s00_axi_arready),
		.S_AXI_RDATA(s00_axi_rdata),
		.S_AXI_RRESP(s00_axi_rresp),
		.S_AXI_RVALID(s00_axi_rvalid),
		.S_AXI_RREADY(s00_axi_rready)
	);

	// Add user logic here
    // signal synch
    reg stage1;
    reg signal_synced;
    
	always @(posedge clk)
	begin
	   if (!s00_axi_aresetn)
	   begin
	       stage1 <= 0;
	       signal_synced <= 0;
	   end
	   else
	   begin
           stage1 <= sig_in;
           signal_synced <= stage1;
       end    
	end
	
    // FSM states
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] MEASURE = 2'd1;
    localparam [1:0] DONE    = 2'd2;
    
    reg [1:0]  state;
    reg [31:0] timer;
    reg [31:0] active_window;
    reg [31:0] count_int;
    reg        signal_prev;
    
    // Rising-edge detector
    wire rising_edge = signal_synced && !signal_prev;
    
    always @(posedge clk)
    begin
        if (!s00_axi_aresetn)
        begin
            state       <= IDLE;
            timer       <= 0;
            active_window <= 0;
            count_int   <= 0;
            count       <= 0;
            status      <= 1;
            signal_prev <= 0;
        end
        else
        begin
            signal_prev <= signal_synced;
    
            case (state)
    
                // Wait for a new start command
                IDLE:
                begin
                    status <= 1;
                    timer  <= 0;
    
                    if (start_pulse && (window != 0))
                    begin
                        count_int <= 0;
                        timer     <= 0;
                        active_window <= window;
                        status    <= 0;
                        state     <= MEASURE;
                    end
                end
    
                // Count rising edges during the measurement window
                MEASURE:
                begin
                    status <= 0;
    
                    if (timer == active_window - 1)
                    begin
                        // Include an edge detected on the final cycle
                        if (rising_edge)
                        begin
                            // BUG (intentional): counter increment disabled for failure demo.
                            // count_int <= count_int + 1;
                            // count     <= count_int + 1;
                        end
                        else
                        begin
                            count     <= count_int;
                        end
    
                        timer  <= 0;
                        status <= 1;
                        state  <= DONE;
                    end
                    else
                    begin
                        if (rising_edge)
                            ; // BUG (intentional): rising edges are not counted.
    
                        timer <= timer + 1;
                    end
                end
    
                // Keep the completed result until another command
                DONE:
                begin
                    status <= 1;
                    timer  <= 0;
    
                    if (start_pulse && (window != 0))
                    begin
                        count_int <= 0;
                        timer     <= 0;
                        active_window <= window;
                        status    <= 0;
                        state     <= MEASURE;
                    end
                    else
                    begin
                        state <= IDLE;
                    end
                end
    
                default:
                begin
                    state  <= IDLE;
                    timer  <= 0;
                    status <= 1;
                end
    
            endcase
        end
    end
	// User logic ends

	endmodule
