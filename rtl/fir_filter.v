module fir_filter (
    input  wire        clk,
    input  wire        resetn,
    input  wire        start,
    input  wire [31:0] sample_in,
    input  wire [31:0] coeff0,
    input  wire [31:0] coeff1,
    input  wire [31:0] coeff2,
    output reg  [31:0] result,
    output reg         done
);

    reg [31:0] sample_d1;
    reg [31:0] sample_d2;

    reg [63:0] product0;
    reg [63:0] product1;
    reg [63:0] product2;
    reg [63:0] sum;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            sample_d1 <= 32'd0;
            sample_d2 <= 32'd0;
            result    <= 32'd0;
            done      <= 1'b0;
        end else begin
            done <= 1'b0;

            if (start) begin
                product0 = sample_in * coeff0;
                product1 = sample_d1 * coeff1;
                product2 = sample_d2 * coeff2;

                sum = product0 + product1 + product2;

                result    <= sum[31:0];
                sample_d2 <= sample_d1;
                sample_d1 <= sample_in;
                done      <= 1'b1;
            end
        end
    end

endmodule
