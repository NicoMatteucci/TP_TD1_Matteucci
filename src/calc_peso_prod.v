module calc_peso_prod (
    input  wire [2:0] idx,       // Índice del dígito (0 a 5)
    input  wire [3:0] dato,      // Dígito BCD (0 a 9)
    output wire [5:0] producto   // Producto parcial (máx 9*7 = 63 -> 6 bits)
);
    reg [2:0] peso;

    always @(*) begin
        case (idx)
            3'd0:    peso = 3'd7; // Primer dígito (más significativo)
            3'd1:    peso = 3'd6;
            3'd2:    peso = 3'd5;
            3'd3:    peso = 3'd4;
            3'd4:    peso = 3'd3;
            3'd5:    peso = 3'd2; // Sexto dígito (menos significativo)
            default: peso = 3'd0; // Evita latches combinacionales
        endcase
    end

    // Al asignar a un bus de 6 bits, Verilog preserva el ancho completo sin truncar
    assign producto = dato * peso;

endmodule