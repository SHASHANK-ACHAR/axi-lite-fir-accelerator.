`timescale 1ns/1ps

module tb_fir_axi_top;

    reg clk;
    reg resetn;

    reg [31:0] AWADDR;
    reg AWVALID;
    wire AWREADY;

    reg [31:0] WDATA;
    reg [3:0] WSTRB;
    reg WVALID;
    wire WREADY;

    wire [1:0] BRESP;
    wire BVALID;
    reg BREADY;

    reg [31:0] ARADDR;
    reg ARVALID;
    wire ARREADY;

    wire [31:0] RDATA;
    wire [1:0] RRESP;
    wire RVALID;
    reg RREADY;

    reg [31:0] read_data;
    integer i;

    // Device under test (DUT)
    fir_axi_top dut (
        .clk(clk),
        .resetn(resetn),

        .AWADDR(AWADDR),
        .AWVALID(AWVALID),
        .AWREADY(AWREADY),

        .WDATA(WDATA),
        .WSTRB(WSTRB),
        .WVALID(WVALID),
        .WREADY(WREADY),

        .BRESP(BRESP),
        .BVALID(BVALID),
        .BREADY(BREADY),

        .ARADDR(ARADDR),
        .ARVALID(ARVALID),
        .ARREADY(ARREADY),

        .RDATA(RDATA),
        .RRESP(RRESP),
        .RVALID(RVALID),
        .RREADY(RREADY)
    );

    // 10 ns clock period
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // AXI-Lite write transaction
    task axi_write;
        input [31:0] addr;
        input [31:0] data;
        reg aw_seen;
        reg w_seen;
        begin
            aw_seen = 1'b0;
            w_seen = 1'b0;

            @(negedge clk);
            AWADDR = addr;
            AWVALID = 1'b1;
            WDATA = data;
            WSTRB = 4'hF;
            WVALID = 1'b1;

            while (!(aw_seen && w_seen)) begin
                @(posedge clk);
                if (AWVALID && AWREADY)
                    aw_seen = 1'b1;
                if (WVALID && WREADY)
                    w_seen = 1'b1;
            end

            @(negedge clk);
            AWVALID = 1'b0;
            WVALID = 1'b0;
            BREADY = 1'b1;

            while (!BVALID)
                @(negedge clk);

            @(negedge clk);
            BREADY = 1'b0;

            if (BRESP !== 2'b00)
                $display("ERROR: Write response at %h = %b",
                         addr, BRESP);
        end
    endtask

    // AXI-Lite read transaction
    task axi_read;
        input [31:0] addr;
        output [31:0] data;
        reg ar_seen;
        begin
            ar_seen = 1'b0;

            @(negedge clk);
            ARADDR = addr;
            ARVALID = 1'b1;

            while (!ar_seen) begin
                @(posedge clk);
                if (ARVALID && ARREADY)
                    ar_seen = 1'b1;
            end

            @(negedge clk);
            ARVALID = 1'b0;

            while (!RVALID)
                @(negedge clk);

            data = RDATA;
            RREADY = 1'b1;

            @(negedge clk);
            RREADY = 1'b0;

            if (RRESP !== 2'b00)
                $display("ERROR: Read response at %h = %b",
                         addr, RRESP);
        end
    endtask

    // Main test sequence
    initial begin
        resetn = 1'b0;

        AWADDR = 0;
        AWVALID = 0;
        WDATA = 0;
        WSTRB = 0;
        WVALID = 0;
        BREADY = 0;

        ARADDR = 0;
        ARVALID = 0;
        RREADY = 0;
        read_data = 0;

        $dumpfile("sim/fir_axi.vcd");
        $dumpvars(0, tb_fir_axi_top);

        repeat (3) @(negedge clk);
        resetn = 1'b1;

        // Configure FIR coefficients
        axi_write(32'h00000004, 32'd2);
        axi_write(32'h00000008, 32'd3);
        axi_write(32'h0000000C, 32'd4);

        // Test samples: 10, 20, 30
        for (i = 1; i <= 3; i = i + 1) begin

            axi_write(32'h00000000, i * 10);
            axi_write(32'h00000010, 32'd1);

            // Allow the FIR calculation to complete
            repeat (3) @(negedge clk);

            axi_read(32'h00000018, read_data);

            case (i)
                1: begin
                    if (read_data === 32'd20)
                        $display("PASS: sample 10, result %0d",
                                 read_data);
                    else
                        $display("FAIL: sample 10, expected 20, got %0d",
                                 read_data);
                end

                2: begin
                    if (read_data === 32'd70)
                        $display("PASS: sample 20, result %0d",
                                 read_data);
                    else
                        $display("FAIL: sample 20, expected 70, got %0d",
                                 read_data);
                end

                3: begin
                    if (read_data === 32'd160)
                        $display("PASS: sample 30, result %0d",
                                 read_data);
                    else
                        $display("FAIL: sample 30, expected 160, got %0d",
                                 read_data);
                end
            endcase
        end

        $display("Testbench finished.");
        $finish;
    end

endmodule
