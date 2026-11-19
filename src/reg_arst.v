module reg_arst #(
    parameter N = 8
)(
    input  wire         clk,
    input  wire         arst,
    input  wire         en,
    input  wire [N-1:0] d,
    output reg  [N-1:0] q
);
    always @(posedge clk or posedge arst) begin
        if (arst) begin
            q <= {N{1'b0}};
        end else if (en) begin
            q <= d;
        end
    end
endmodule