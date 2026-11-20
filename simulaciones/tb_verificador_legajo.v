`timescale 1ns / 1ps

module tb_verificador_legajo;

    // 1. Parametros y señales de interconexion
    localparam CLK_PERIOD = 20; // Periodo de reloj = 20 ns (f = 50 MHz)

    //uut
    reg        clk;
    reg        arst;
    reg        start;
    reg        valid;
    reg  [3:0] dato;
    wire       busy;
    wire       done;
    wire [3:0] verificador;
    
    //auxiliares tb
    reg  [3:0] verif_previo;
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
    // 1. Generador de reloj
    // -------------------------------------------------------------------------
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // -------------------------------------------------------------------------
    // 2. Tareas (Tasks)
    // -------------------------------------------------------------------------

    // reset asincronico y verifica estado inicial
    task automatic aplicar_reset_asincronico;
        begin
            @(negedge clk);
            #(CLK_PERIOD / 4); // Disparo asincronico (5 ns post negedge)
            arst = 1'b1; #2; // Retardo para propagacion combinacional
            if ((busy !== 1'b0) || (done !== 1'b0) || (verificador !== 4'd0)) begin
                $display("[ERROR] t=%0t ns: Reset asincronico no limpio salidas (busy=%b, done=%b, verif=%d)",
                         $time, busy, done, verificador);
                errores = errores + 1;
            end
            @(negedge clk);
            arst  = 1'b0;
            verif_previo = 4'd0;
            start = 1'b0;
            valid = 1'b0;
            dato  = 4'd0;
            $display("                       --- Reset asincronico. ---");
        end
    endtask

    // coloca un digito en el flanco descendente con valid = 1
    task automatic enviar_digito(input [3:0] d);
        begin
            @(negedge clk);
            valid = 1'b1;
            dato  = d;
        end
    endtask

    // prueba un legajo completo (6 digitos) y verifica el resultado
    task automatic probar_legajo;
        input [3:0] d0, d1, d2, d3, d4, d5;
        input [3:0] verif_esperado;
        input       insertar_pausa; // 1: prueba valid=0 a mitad de carga
        begin
            // 1. Disparo de inicio (start = 1 por 1 ciclo)
            @(negedge clk); start = 1'b1; valid = 1'b0;
            @(posedge clk); #1; // Esperar actualizacion de registros
            if ((busy !== 1'b1) || (verificador !== verif_previo)) begin
                $display("[ERROR] t=%0t ns: Fallo en start (busy=%b, verif=%0d, esperado=%0d)",
                         $time, busy, verificador, verif_previo);
                errores = errores + 1;
            end
            // el inicio no debe borrar el resultado anterior
            if (verificador !== verif_previo) begin
                $display("[ERROR] t=%0t ns: start borro el verificador previo (esperado=%0d, obtenido=%0d)",
                         $time, verif_previo, verificador);
                errores = errores + 1;
            end

            // 2. Envio de los 3 primeros digitos (probando start=1 ignorado en d1)
            start = 1'b0; enviar_digito(d0);
            start = 1'b1; enviar_digito(d1);
            start = 1'b0; enviar_digito(d2);
            
            // 3. Pausa opcional con valid = 0
            if (insertar_pausa) begin
                @(negedge clk); valid = 1'b0; dato = 4'd9; // Basura ignorada
                repeat (10) @(negedge clk);
            end

            // 4. Envio de los 3 últimos digitos
            enviar_digito(d3);
            enviar_digito(d4);
            enviar_digito(d5);

            // Pasado un flanco ascendente desde el 6° digito, se asignan los valores
            @(negedge clk); valid = 1'b0; dato  = 4'd0;

            // 5. Esperar calculo del resto (S_MOD)
            ciclos_resta = 0;
            @(posedge clk); #1; // Primer flanco dentro de S_MOD (o salto directo a S_DONE si S < 11)
            while (done !== 1'b1) begin
                ciclos_resta = ciclos_resta + 1;
                if (busy !== 1'b1) begin
                    $display("[ERROR] t=%0t ns: busy=0 antes de terminar S_MOD", $time);
                    errores = errores + 1;
                end
                if (ciclos_resta > 30) begin
                    $display("[FATAL] t=%0t ns: Timeout esperando done=1", $time);
                    $finish;
                end
                @(posedge clk); #1; // Espera el siguiente flanco para reevaluar el while
            end

            // Limpiamos valid tras detectar done=1
            valid = 1'b0; dato  = 4'd0;

            // 6. Verificar resultado en el ciclo exacto donde done == 1
            if ((busy !== 1'b0) || (verificador !== verif_esperado)) begin
                $display("[ERROR] Legajo %0d%0d%0d%0d%0d%0d -> esperado=%0d, obtenido=%0d, busy=%b",
                         d0, d1, d2, d3, d4, d5, verif_esperado, verificador, busy);
                errores = errores + 1;
            end else begin
                $display("[OK] Legajo %0d%0d%0d%0d%0d%0d (%s) -> Verif = %0d | Restas: %2d (ciclos S_MOD: %2d) | t=%4t ns",
                d0, d1, d2, d3, d4, d5, (insertar_pausa ? "pausa" : "rafaga"), 
                verificador, ciclos_resta, ciclos_resta + 1, $time);
            end

            verif_previo = verificador; // Guardamos el resultado para la proxima prueba

            // 7. Verificar que done dure solo un ciclo
            @(posedge clk); #1;
            if (done !== 1'b0) begin
                $display("[ERROR] t=%0t ns: done duro mas de 1 ciclo de reloj", $time);
                errores = errores + 1;
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // 4. Simulacion
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("tb_verificador_legajo.vcd");
        $dumpvars(0, tb_verificador_legajo);

        errores = 0;
        arst    = 1'b0;
        start   = 1'b0;
        valid   = 1'b0;
        dato    = 4'd0;

        $display("=======================================================================================");
        $display(" INICIO DE SIMULACION: verificador_legajo (CLK_PERIOD = %0d ns)", CLK_PERIOD);
        $display("=======================================================================================");

        aplicar_reset_asincronico();

        // ---------------------------------------------------------------------
        // PRUEBA CON LEGAJO PROPIO
        // 204710 -> S = 65 = 5 * 11 + 10 -> Resto = 10 -> Verificador = 0
        probar_legajo(4'd2, 4'd0, 4'd4, 4'd7, 4'd1, 4'd0, 4'd0, 1'b0);
        // ---------------------------------------------------------------------
        probar_legajo(4'd1, 4'd2, 4'd3, 4'd4, 4'd5, 4'd6, 4'd0, 1'b1); // 123456 -> S=77  -> 0 (con pausa valid=0)
        probar_legajo(4'd6, 4'd5, 4'd4, 4'd3, 4'd2, 4'd1, 4'd2, 1'b1); // 654321 -> S=112 -> 2 (con pausa valid=0)
        probar_legajo(4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd1, 4'd5, 1'b0); // 111111 -> S=27  -> 5
        probar_legajo(4'd1, 4'd0, 4'd0, 4'd0, 4'd0, 4'd0, 4'd7, 1'b0); // 100007 -> S=21 (resto 10) -> 0
        probar_legajo(4'd0, 4'd0, 4'd0, 4'd0, 4'd0, 4'd0, 4'd0, 1'b1); // 000000 -> S=0   -> 0 (0 restas)
        probar_legajo(4'd9, 4'd9, 4'd9, 4'd9, 4'd9, 4'd9, 4'd1, 1'b0); // 999999 -> S=243 -> 1 (22 restas)
        //           (d0,   d1,   d2,   d3,   d4,   d5, esperado, pausa)

        // Reset Asincronico en medio de peracion (busy=1)
        @(negedge clk); start = 1'b1;
        enviar_digito(4'd9); start = 1'b0;
        aplicar_reset_asincronico();
        
        // al volver del reset opera normalment
        // probar_legajo(4'd1, 4'd2, 4'd3, 4'd4, 4'd5, 4'd6, 4'd0, 1'b0); // 123456 -> S=77  -> 0
        probar_legajo(4'd6, 4'd5, 4'd4, 4'd3, 4'd2, 4'd1, 4'd2, 1'b0); // 654321 -> S=112 -> 2
        // ---------------------------------------------------------------------

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