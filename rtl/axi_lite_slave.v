module axi_lite_slave (
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
    output reg  [1:0]  BRESP,
    output reg         BVALID,
    input  wire        BREADY,

    // AXI-Lite read address channel
    input  wire [31:0] ARADDR,
    input  wire        ARVALID,
    output wire        ARREADY,

    // AXI-Lite read data channel
    output reg  [31:0] RDATA,
    output reg  [1:0]  RRESP,
    output reg         RVALID,
    input  wire        RREADY,

    // Interface to FIR filter
    output reg         fir_start,
    output reg  [31:0] sample_out,
    output reg  [31:0] coeff0,
    output reg  [31:0] coeff1,
    output reg  [31:0] coeff2,
    input  wire        fir_done,
    input  wire [31:0] fir_result
);

    // Register addresses
    localparam ADDR_SAMPLE = 32'h00000000;
    localparam ADDR_COEFF0 = 32'h00000004;
    localparam ADDR_COEFF1 = 32'h00000008;
    localparam ADDR_COEFF2 = 32'h0000000C;
    localparam ADDR_CTRL   = 32'h00000010;
    localparam ADDR_STATUS = 32'h00000014;
    localparam ADDR_RESULT = 32'h00000018;

    // AXI-Lite transaction storage
    reg [31:0] awaddr_reg;
    reg [31:0] wdata_reg;
    reg [3:0]  wstrb_reg;
    reg        aw_pending;
    reg        w_pending;

    reg [31:0] ctrl_reg;
    reg [31:0] read_value;
    reg [1:0]  read_response;
    reg        read_error;

    // Merge only the bytes enabled by WSTRB
    function [31:0] merge_bytes;
        input [31:0] old_value;
        input [31:0] new_value;
        input [3:0]  byte_enable;
        begin
            merge_bytes = old_value;
            if (byte_enable[0])
                merge_bytes[7:0] = new_value[7:0];
            if (byte_enable[1])
                merge_bytes[15:8] = new_value[15:8];
            if (byte_enable[2])
                merge_bytes[23:16] = new_value[23:16];
            if (byte_enable[3])
                merge_bytes[31:24] = new_value[31:24];
        end
    endfunction

    // Accept one outstanding transaction at a time
    assign AWREADY = resetn && !aw_pending && !BVALID;
    assign WREADY  = resetn && !w_pending  && !BVALID;
    assign ARREADY = resetn && !RVALID;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            awaddr_reg <= 32'd0;
            wdata_reg  <= 32'd0;
            wstrb_reg  <= 4'd0;
            aw_pending <= 1'b0;
            w_pending  <= 1'b0;

            sample_out <= 32'd0;
            coeff0     <= 32'd0;
            coeff1     <= 32'd0;
            coeff2     <= 32'd0;
            ctrl_reg   <= 32'd0;
            fir_start  <= 1'b0;

            BRESP  <= 2'b00;
            BVALID <= 1'b0;
            RDATA  <= 32'd0;
            RRESP  <= 2'b00;
            RVALID <= 1'b0;
        end else begin
            // Default: start is a one-cycle pulse
            fir_start <= 1'b0;

            // Capture write address independently
            if (AWVALID && AWREADY) begin
                awaddr_reg <= AWADDR;
                aw_pending <= 1'b1;
            end

            // Capture write data independently
            if (WVALID && WREADY) begin
                wdata_reg  <= WDATA;
                wstrb_reg  <= WSTRB;
                w_pending  <= 1'b1;
            end

            // Execute after both address and data are captured
            if (aw_pending && w_pending && !BVALID) begin
                case (awaddr_reg)
                    ADDR_SAMPLE:
                        sample_out <= merge_bytes(
                            sample_out, wdata_reg, wstrb_reg
                        );

                    ADDR_COEFF0:
                        coeff0 <= merge_bytes(
                            coeff0, wdata_reg, wstrb_reg
                        );

                    ADDR_COEFF1:
                        coeff1 <= merge_bytes(
                            coeff1, wdata_reg, wstrb_reg
                        );

                    ADDR_COEFF2:
                        coeff2 <= merge_bytes(
                            coeff2, wdata_reg, wstrb_reg
                        );

                    ADDR_CTRL: begin
                        ctrl_reg <= merge_bytes(
                            ctrl_reg, wdata_reg, wstrb_reg
                        );
                        if (wstrb_reg[0] && wdata_reg[0])
                            fir_start <= 1'b1;
                    end

                    default: begin
                        // Status and result are read-only.
                        // Unknown addresses also return an error.
                    end
                endcase

                if ((awaddr_reg == ADDR_SAMPLE) ||
                    (awaddr_reg == ADDR_COEFF0) ||
                    (awaddr_reg == ADDR_COEFF1) ||
                    (awaddr_reg == ADDR_COEFF2) ||
                    (awaddr_reg == ADDR_CTRL))
                    BRESP <= 2'b00;  // OKAY
                else
                    BRESP <= 2'b10;  // SLVERR

                BVALID     <= 1'b1;
                aw_pending <= 1'b0;
                w_pending  <= 1'b0;
            end

            // Hold write response until accepted
            if (BVALID && BREADY)
                BVALID <= 1'b0;

            // Read request: capture data and response
            if (ARVALID && ARREADY) begin
                case (ARADDR)
                    ADDR_SAMPLE: begin
                        read_value    = sample_out;
                        read_response = 2'b00;
                        read_error    = 1'b0;
                    end
                    ADDR_COEFF0: begin
                        read_value    = coeff0;
                        read_response = 2'b00;
                        read_error    = 1'b0;
                    end
                    ADDR_COEFF1: begin
                        read_value    = coeff1;
                        read_response = 2'b00;
                        read_error    = 1'b0;
                    end
                    ADDR_COEFF2: begin
                        read_value    = coeff2;
                        read_response = 2'b00;
                        read_error    = 1'b0;
                    end
                    ADDR_CTRL: begin
                        read_value    = ctrl_reg;
                        read_response = 2'b00;
                        read_error    = 1'b0;
                    end
                    ADDR_STATUS: begin
                        read_value    = {31'd0, fir_done};
                        read_response = 2'b00;
                        read_error    = 1'b0;
                    end
                    ADDR_RESULT: begin
                        read_value    = fir_result;
                        read_response = 2'b00;
                        read_error    = 1'b0;
                    end
                    default: begin
                        read_value    = 32'd0;
                        read_response = 2'b10;
                        read_error    = 1'b1;
                    end
                endcase

                RDATA  <= read_value;
                RRESP  <= read_response;
                RVALID <= 1'b1;
            end

            // Hold read response until accepted
            if (RVALID && RREADY)
                RVALID <= 1'b0;
        end
    end

endmodule
