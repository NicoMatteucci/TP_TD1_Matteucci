`timescale 1ns / 1ps

module tb_verificador_legajo;

    // -------------------------------------------------------------------------
    // 1. Parámetros y señales de interconexión
    // -------------------------------------------------------------------------
    localparam CLK_PERIOD = 20; // Período de reloj = 20 ns (f = 50 MHz)

    reg        clk;
    reg        arst;
    reg        start;
    reg        valid;
    reg  [3:0] dato;

    wire       busy;
    wire       done;
    wire [3:0] verificador;

    integer errores;
    integer ciclos_resta;

    // Instancia del circuito bajo prueba (UUT)
    verificador_legajo uut (
        .clk         (clk),
        .arst        (arst),
        .start       (start),
        .valid       (valid),
        .dato        (dato),
        .busy        (busy),
        .done        (done),
        .verificador (verificador)
    );

    // -------------------------------------------------------------------------
    // 2. Generador de reloj
    // -------------------------------------------------------------------------
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // -------------------------------------------------------------------------
    // 3. Tareas (Tasks)
    // -------------------------------------------------------------------------

    // Aplica reset asincrónico entre flancos y verifica estado inicial en cero
    task automatic aplicar_reset_asincronico;
        begin
            @(negedge clk);
            #(CLK_PERIOD / 4); // Disparo asincrónico (5 ns después del negedge)
            arst = 1'b1;
            #2; // Retardo para propagación combinacional
            if ((busy !== 1'b0) || (done !== 1'b0) || (verificador !== 4'd0)) begin
                $display("[ERROR] t=%0t ns: Reset asincronico no limpio salidas (busy=%b, done=%b, verif=%d)",
                         $time, busy, done, verificador);
                errores = errores + 1;
            end
            @(negedge clk);
            arst  = 1'b0;
            start = 1'b0;
            valid = 1'b0;
            dato  = 4'd0;
        end
    endtask

    // Ejecuta una prueba completa de 6 dígitos con opción de pausa y ruido
    task automatic probar_legajo;
        input [3:0] d0, d1, d2, d3, d4, d5;
        input [3:0] verif_esperado;
        input [3:0] verif_previo_esperado;
        input       insertar_pausa; // 1: prueba valid=0 a mitad de carga
        begin
            // 1. Disparo de inicio (start = 1 por 1 ciclo)
            @(negedge clk);
            start = 1'b1;
            valid = 1'b0;

            @(posedge clk);
            #1; // Esperar actualización de registros
            if (busy !== 1'b1) begin
                $display("[ERROR] t=%0t ns: busy no se activo tras start=1", $time);
                errores = errores + 1;
            end
            // Verificar Sección 6: el inicio no debe borrar el resultado anterior
            if (verificador !== verif_previo_esperado) begin
                $display("[ERROR] t=%0t ns: start borro el verificador previo (esperado=%0d, obtenido=%0d)",
                         $time, verif_previo_esperado, verificador);
                errores = errores + 1;
            end

            // 2. Envío de los 3 primeros dígitos en ráfaga continua (valid = 1)
            @(negedge clk);
            start = 1'b0;
            valid = 1'b1;
            dato  = d0;

            @(negedge clk);
            // Probamos que start=1 sea ignorado mientras busy=1 (Sección 3)
            start = 1'b1;
            dato  = d1;

            @(negedge clk);
            start = 1'b0;
            dato  = d2;

            // 3. Pausa opcional con valid = 0 (Sección 3 y Pregunta 9.d)
            if (insertar_pausa) begin
                @(negedge clk);
                valid = 1'b0;
                dato  = 4'd9; // Dato basura que NO debe sumarse mientras valid=0
                repeat (2) @(negedge clk);
            end

            // 4. Envío de los 3 últimos dígitos
            @(negedge clk);
            valid = 1'b1;
            dato = d3;

            @(negedge clk);
            dato = d4;

            @(negedge clk);
            dato = d5;

            // Tras el flanco ascendente del 6to dígito, bajamos valid
            @(posedge clk);
            @(negedge clk);
            valid = 1'b0;
            dato  = 4'd0;

            // 5. Esperar cálculo del resto (S_MOD) inyectando ruido en valid
            ciclos_resta = 0;
            while (done !== 1'b1) begin
                // Probamos que valid=1 sea ignorado durante el cálculo del resto (Sección 5)
                valid = 1'b1;
                dato  = 4'd8;
                @(posedge clk);
                #1;
                if (done !== 1'b1) begin
                    ciclos_resta = ciclos_resta + 1;
                    if (busy !== 1'b1) begin
                        $display("[ERROR] t=%0t ns: busy cayo antes de terminar S_MOD", $time);
                        errores = errores + 1;
                    end
                end
                if (ciclos_resta > 30) begin
                    $display("[FATAL] t=%0t ns: Timeout esperando done=1", $time);
                    $finish;
                end
            end

            // Limpiamos valid tras detectar done=1
            valid = 1'b0;
            dato  = 4'd0;

            // 6. Verificar resultado en el ciclo exacto donde done == 1 (Sección 6)
            if ((busy !== 1'b0) || (verificador !== verif_esperado)) begin
                $display("[ERROR] Legajo %0d%0d%0d%0d%0d%0d -> esperado=%0d, obtenido=%0d, busy=%b",
                         d0, d1, d2, d3, d4, d5, verif_esperado, verificador, busy);
                errores = errores + 1;
            end else begin
                $display("[OK] Legajo %0d%0d%0d%0d%0d%0d (%s) -> Verif = %0d | Restas: %2d (ciclos S_MOD: %2d) | t=%4t ns",
                d0, d1, d2, d3, d4, d5, (insertar_pausa ? "pausa" : "rafaga"), 
                verificador, ciclos_resta, ciclos_resta + 1, $time);
            end

            // 7. Verificar que done dure EXACTAMENTE 1 ciclo de reloj (Sección 6)
            @(posedge clk);
            #1;
            if (done !== 1'b0) begin
                $display("[ERROR] t=%0t ns: done duro mas de 1 ciclo de reloj", $time);
                errores = errores + 1;
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // 4. Secuencia principal de simulación
    // -------------------------------------------------------------------------
    initial begin
        // Volcado de ondas para GTKWave
        $dumpfile("tb_verificador_legajo.vcd");
        $dumpvars(0, tb_verificador_legajo);

        // Inicialización
        errores = 0;
        arst    = 1'b0;
        start   = 1'b0;
        valid   = 1'b0;
        dato    = 4'd0;

        $display("=======================================================================================");
        $display(" INICIO DE SIMULACION: verificador_legajo (CLK_PERIOD = %0d ns)", CLK_PERIOD);
        $display("=======================================================================================");

        // Reset inicial
        aplicar_reset_asincronico();

        // Tabla de pruebas obligatorias de la Sección 8:
        // Formato: probar_legajo(d0, d1, d2, d3, d4, d5, esperado, previo, pausa)
        probar_legajo(4'd1, 4'd2, 4'd3, 4'd4, 4'd5, 4'd6, 4'd0, 4'd0, 1'b0); // 123456 -> S=77  -> 0
        probar_legajo(4'd6, 4'd5, 4'd4, 4'd3, 4'd2, 4'd1, 4'd2, 4'd0, 1'b1); // 654321 -> S=112 -> 2 (con pausa valid=0)
        probar_legajo(4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd5, 4'd2, 1'b0); // 111111 -> S=27  -> 5
        probar_legajo(4'd1, 4'd0, 4'd0, 4'd0, 4'd0, 4'd7, 4'd0, 4'd5, 1'b1); // 100007 -> S=21  -> resto 10 -> 0
        probar_legajo(4'd0, 4'd0, 4'd0, 4'd0, 4'd0, 4'd0, 4'd0, 4'd0, 1'b0); // 000000 -> S=0   -> 0 (0 restas)
        probar_legajo(4'd9, 4'd9, 4'd9, 4'd9, 4'd9, 4'd9, 4'd1, 4'd0, 1'b0); // 999999 -> S=243 -> 1 (22 restas)

        // ---------------------------------------------------------------------
        // PRUEBA CON LEGAJO PROPIO (Reemplazá estos dígitos por tu legajo)
        // Ejemplo: 204710 -> S = 2*7 + 0*6 + 4*5 + 7*4 + 1*3 + 0*2 = 65
        // 65 = 5 * 11 + 10 -> Resto = 10 -> Verificador = 0
        // ---------------------------------------------------------------------
        probar_legajo(4'd2, 4'd0, 4'd4, 4'd7, 4'd1, 4'd0, 4'd0, 4'd1, 1'b0);

        // ---------------------------------------------------------------------
        // PRUEBA DE ABORTO POR RESET ASINCRÓNICO A MITAD DE OPERACIÓN
        // ---------------------------------------------------------------------
        @(negedge clk);
        start = 1'b1;
        @(negedge clk);
        start = 1'b0;
        valid = 1'b1;
        dato  = 4'd9;
        @(negedge clk);
        dato  = 4'd8;
        // Disparamos reset asincrónico mientras busy == 1
        aplicar_reset_asincronico();
        $display("[OK] Aborto por reset asincronico en mitad de carga verificado.");

        // Confirmar que tras el reset puede volver a operar normalmente
        probar_legajo(4'd1, 4'd2, 4'd3, 4'd4, 4'd5, 4'd6, 4'd0, 4'd0, 1'b0);

        #(CLK_PERIOD * 2);
        $display("=======================================================================================");
        if (errores == 0)
            $display(" RESULTADO FINAL: EXITO - Todas las pruebas pasaron sin errores.");
        else
            $display(" RESULTADO FINAL: FALLA - Se detectaron %0d errores.", errores);
        $display("=======================================================================================");
        $finish;
    end

endmodule