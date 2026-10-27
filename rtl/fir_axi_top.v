module fir_axi_top (
    input  wire        clk,
    input  wire        resetn,

    // AXI-Lite write address channel
    input  wire [31:0] AWADDR,
    input  wire        AWVALID,
    output wire        AWREADY,

    // AXI-Lite write data channel
    input  wire [31:0] WDATA,
    input  wire [3:0]  WSTRB,
    input  wire        WVALID,
    output wire        WREADY,

    // AXI-Lite write response channel
    output wire [1:0]  BRESP,
    output wire        BVALID,
    input  wire        BREADY,

    // AXI-Lite read address channel
    input  wire [31:0] ARADDR,
    input  wire        ARVALID,
    output wire        ARREADY,

    // AXI-Lite read data channel
    output wire [31:0] RDATA,
    output wire [1:0]  RRESP,
    output wire        RVALID,
    input  wire        RREADY
);

    // Internal connections between modules
    wire        fir_start;
    wire [31:0] sample_in;
    wire [31:0] coeff0;
    wire [31:0] coeff1;
    wire [31:0] coeff2;
    wire        fir_done;
    wire [31:0] fir_result;

    // AXI-Lite slave instance
    axi_lite_slave u_axi_slave (
        .clk        (clk),
        .resetn     (resetn),

        .AWADDR     (AWADDR),
        .AWVALID    (AWVALID),
        .AWREADY    (AWREADY),

        .WDATA      (WDATA),
        .WSTRB      (WSTRB),
        .WVALID     (WVALID),
        .WREADY     (WREADY),

        .BRESP      (BRESP),
        .BVALID     (BVALID),
        .BREADY     (BREADY),

        .ARADDR     (ARADDR),
        .ARVALID    (ARVALID),
        .ARREADY    (ARREADY),

        .RDATA      (RDATA),
        .RRESP      (RRESP),
        .RVALID     (RVALID),
        .RREADY     (RREADY),

        .fir_start  (fir_start),
        .sample_out (sample_in),
        .coeff0     (coeff0),
        .coeff1     (coeff1),
        .coeff2     (coeff2),
        .fir_done   (fir_done),
        .fir_result (fir_result)
    );

    // FIR filter instance
    fir_filter u_fir_filter (
        .clk       (clk),
        .resetn    (resetn),
        .start     (fir_start),
        .sample_in (sample_in),
        .coeff0    (coeff0),
        .coeff1    (coeff1),
        .coeff2    (coeff2),
        .result    (fir_result),
        .done      (fir_done)
    );

endmodule
