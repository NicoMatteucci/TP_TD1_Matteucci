module datapath_legajo (
    input  wire       clk,
    input  wire       arst,
    input  wire [3:0] dato,
    // Señales de control (vienen de la FSM)
    input  wire       clr_acum,
    input  wire       clr_cnt,
    input  wire       en_acum,
    input  wire       en_cnt,
    input  wire       sel_op,        // 0: sumar producto parcial | 1: restar 11
    input  wire       en_verif,
    // Banderas de estado (van hacia la FSM)
    output wire       ultimo_digito, // 1 cuando idx == 5 (6to dígito)
    output wire       menor_11,      // 1 cuando acum < 11
    // Salida de datos
    output wire [3:0] verificador
);
    wire [2:0] idx_digito;
    wire [5:0] producto;
    wire [7:0] acum_q;
    wire [7:0] suma_parcial;
    wire [7:0] resta_11;
    wire [7:0] op_resultado;
    wire [7:0] acum_d;
    wire [3:0] verif_d;

    // 1. Contador de posición de dígito (0 a 5)
    contador_arst #(.N(3)) cnt_pos (
        .clk  (clk),
        .arst (arst),
        .clr  (clr_cnt),
        .en   (en_cnt),
        .q    (idx_digito)
    );

    // 2. Cálculo combinacional de peso y producto parcial
    calc_peso_prod u_peso_prod (
        .idx      (idx_digito),
        .dato     (dato),
        .producto (producto)
    );

    // 3. Operaciones aritméticas sobre 8 bits (máx suma = 243)
    assign suma_parcial = acum_q + {2'b00, producto};
    assign resta_11     = acum_q - 8'd11;

    // 4. Selección de operación (0: acumulación | 1: resta sucesiva de 11)
    mux2to1 #(.N(8)) mux_operacion (
        .x1 (suma_parcial),
        .x2 (resta_11),
        .s  (sel_op),
        .y  (op_resultado)
    );

    // 5. Selección de limpieza sincrónica del acumulador al iniciar (start)
    mux2to1 #(.N(8)) mux_clear_acum (
        .x1 (op_resultado),
        .x2 (8'd0),
        .s  (clr_acum),
        .y  (acum_d)
    );

    // 6. Registro Acumulador (8 bits)
    reg_arst #(.N(8)) reg_acumulador (
        .clk  (clk),
        .arst (arst),
        .en   (en_acum | clr_acum),
        .d    (acum_d),
        .q    (acum_q)
    );

    // 7. Conversión de resto a dígito verificador (si el resto es 10 -> 0)
    assign verif_d = (acum_q == 8'd10) ? 4'd0 : acum_q[3:0];

    // 8. Registro de salida Verificador (conserva el valor hasta el próximo fin o arst)
    reg_arst #(.N(4)) reg_verificador (
        .clk  (clk),
        .arst (arst),
        .en   (en_verif),
        .d    (verif_d),
        .q    (verificador)
    );

    // 9. Banderas de estado hacia la Unidad de Control
    assign ultimo_digito = (idx_digito == 3'd5) ? 1'b1 : 1'b0;
    assign menor_11      = (acum_q < 8'd11)     ? 1'b1 : 1'b0;

endmodule