module verificador_legajo (
    input  wire       clk,
    input  wire       arst,
    input  wire       start,
    input  wire       valid,
    input  wire [3:0] dato,
    output reg        busy,
    output reg        done,
    output reg  [3:0] verificador
);
    // Señales de control
    wire       clr_acum, clr_cnt, en_acum, en_cnt, sel_op, en_verif;
    // Señales de estado
    wire       ultimo_digito, menor_11;
    // Señales de salida Unidad de Control
    wire       busy_w, done_w;
    // Señales de salida Datapath
    wire [3:0] verificador_w;

    // Instancia de la Unidad de Control
    control_legajo u_control (
        .clk           (clk),
        .arst          (arst),
        .start         (start),
        .valid         (valid),
        .ultimo_digito (ultimo_digito),
        .menor_11      (menor_11),
        .busy          (busy_w),
        .done          (done_w),
        .clr_acum      (clr_acum),
        .clr_cnt       (clr_cnt),
        .en_acum       (en_acum),
        .en_cnt        (en_cnt),
        .sel_op        (sel_op),
        .en_verif      (en_verif)
    );

    // Instancia del Datapath
    datapath_legajo u_datapath (
        .clk           (clk),
        .arst          (arst),
        .dato          (dato),
        .clr_acum      (clr_acum),
        .clr_cnt       (clr_cnt),
        .en_acum       (en_acum),
        .en_cnt        (en_cnt),
        .sel_op        (sel_op),
        .en_verif      (en_verif),
        .ultimo_digito (ultimo_digito),
        .menor_11      (menor_11),
        .verificador   (verificador_w)
    );

    // Puente combinacional para respetar los tipos "output reg" de la interfaz
    always @(*) begin
        busy        = busy_w;
        done        = done_w;
        verificador = verificador_w;
    end

endmodule