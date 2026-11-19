module contador_arst #(
    parameter N = 3
)(
    input  wire         clk,
    input  wire         arst,
    input  wire         clr,
    input  wire         en,
    output reg  [N-1:0] q
);
    always @(posedge clk or posedge arst) begin
        if (arst) begin
            q <= {N{1'b0}};
        end else if (clr) begin
            q <= {N{1'b0}};
        end else if (en) begin
            q <= q + 1'b1;
        end
    end
endmodule