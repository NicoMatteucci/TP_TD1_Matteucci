module control_legajo (
    input  wire clk,
    input  wire arst,
    // Entradas externas
    input  wire start,
    input  wire valid,
    // Banderas desde el Datapath
    input  wire ultimo_digito,
    input  wire menor_11,
    // Salidas externas
    output reg  busy,
    output reg  done,
    // Señales de control hacia el Datapath
    output reg  clr_acum,
    output reg  clr_cnt,
    output reg  en_acum,
    output reg  en_cnt,
    output reg  sel_op,
    output reg  en_verif
);
    // Codificación de estados
    localparam [1:0] S_IDLE = 2'b00, // Esperando inicio
                     S_LOAD = 2'b01, // Recibiendo y acumulando los 6 dígitos
                     S_MOD  = 2'b10, // Restando 11 hasta que acum < 11
                     S_DONE = 2'b11; // Entrega resultado (done = 1 por 1 ciclo)

    reg [1:0] estado_actual, estado_futuro;

    // -------------------------------------------------------------------------
    // 1. Memoria de estado (Secuencial con reset asincrónico)
    // -------------------------------------------------------------------------
    always @(posedge clk or posedge arst) begin
        if (arst) begin
            estado_actual <= S_IDLE;
        end else begin
            estado_actual <= estado_futuro;
        end
    end

    // -------------------------------------------------------------------------
    // 2. Lógica de estado futuro (Combinacional)
    // -------------------------------------------------------------------------
    always @(*) begin
        estado_futuro = estado_actual; // Valor por defecto anti-latches
        case (estado_actual)
            S_IDLE: begin
                if (start)
                    estado_futuro = S_LOAD;
            end

            S_LOAD: begin
                // Al validar el 6to dígito (idx == 5), se incorpora y pasa a restar
                if (valid && ultimo_digito)
                    estado_futuro = S_MOD;
            end

            S_MOD: begin
                // Cuando acum < 11, pasa a entregar el resultado
                if (menor_11)
                    estado_futuro = S_DONE;
            end

            S_DONE: begin
                // Como busy == 0 en S_DONE, permite encadenar un nuevo start inmediato
                if (start)
                    estado_futuro = S_LOAD;
                else
                    estado_futuro = S_IDLE;
            end

            default: estado_futuro = S_IDLE;
        endcase
    end

    // -------------------------------------------------------------------------
    // 3. Lógica de salidas y control del Datapath (Combinacional)
    // -------------------------------------------------------------------------
    always @(*) begin
        // Valores por defecto en reposo (evita latches)
        busy     = 1'b0;
        done     = 1'b0;
        clr_acum = 1'b0;
        clr_cnt  = 1'b0;
        en_acum  = 1'b0;
        en_cnt   = 1'b0;
        sel_op   = 1'b0;
        en_verif = 1'b0;

        case (estado_actual)
            S_IDLE: begin
                busy = 1'b0;
                if (start) begin
                    clr_acum = 1'b1;
                    clr_cnt  = 1'b1;
                end
            end

            S_LOAD: begin
                busy   = 1'b1;
                sel_op = 1'b0; // Operación: acum + dato * peso
                // Mientras busy == 1 se ignora start. Si valid == 0 se conserva todo.
                if (valid) begin
                    en_acum = 1'b1;
                    en_cnt  = 1'b1;
                end
            end

            S_MOD: begin
                busy   = 1'b1;
                sel_op = 1'b1; // Operación: acum - 11
                // Se ignora valid durante el cálculo del resto
                if (!menor_11) begin
                    en_acum = 1'b1; // Resta 11 en este ciclo
                end else begin
                    en_verif = 1'b1; // Captura verificador en el flanco que pasa a S_DONE
                end
            end

            S_DONE: begin
                busy = 1'b0;
                done = 1'b1; // Pulso de exactamente 1 ciclo de reloj
                if (start) begin
                    clr_acum = 1'b1;
                    clr_cnt  = 1'b1;
                end
            end

            default: begin
                busy = 1'b0;
                done = 1'b0;
            end
        endcase
    end

endmodule