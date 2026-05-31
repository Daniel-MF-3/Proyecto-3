`timescale 1ns/1ps

module tb_top;

    // ---------------------------------------------------------
    // Señales del top
    // ---------------------------------------------------------
    logic clk;
    logic reset;              // reset externo activo en 0
    logic [3:0] filas;
    logic [3:0] columnas;
    logic [3:0] anodos;
    logic [6:0] siete_seg;

    logic led_externo_contacto;
    logic led_externo_pulso;
    logic led_externo_bit0;

    // ---------------------------------------------------------
    // Instancia del top
    // ---------------------------------------------------------
    top uut (
        .clk(clk),
        .reset(reset),
        .filas(filas),
        .columnas(columnas),
        .anodos(anodos),
        .siete_seg(siete_seg),
        .led_externo_contacto(led_externo_contacto),
        .led_externo_pulso(led_externo_pulso),
        .led_externo_bit0(led_externo_bit0)
    );

    // ---------------------------------------------------------
    // Reloj de 27 MHz
    // Periodo aproximado = 37.037 ns
    // ---------------------------------------------------------
    always #18.518 clk = ~clk;

    // ---------------------------------------------------------
    // Tarea: reset del sistema
    // ---------------------------------------------------------
    task reset_sistema;
        begin
            $display("");
            $display("Aplicando reset...");

            reset = 1'b0;       // activo en 0
            filas = 4'b1111;

            // Soltar fuerzas por seguridad
            release uut.tecla_ok;
            release uut.pulse_fsm;

            repeat (10) @(posedge clk);

            reset = 1'b1;       // desactiva reset

            repeat (10) @(posedge clk);

            $display("Reset liberado.");
            $display("");
        end
    endtask

    // ---------------------------------------------------------
    // Tarea: enviar una tecla ya limpia hacia la FSM
    //
    // Esta tarea evita simular scanner + debounce.
    // Fuerza:
    //   uut.tecla_ok
    //   uut.pulse_fsm
    //
    // Códigos usados:
    //   0-9 -> números
    //   A   -> 4'hA
    //   B   -> 4'hB
    //   D   -> 4'hD
    // ---------------------------------------------------------
    task enviar_tecla;
        input [3:0] tecla;
        begin
            @(negedge clk);

            force uut.tecla_ok  = tecla;
            force uut.pulse_fsm = 1'b1;

            @(negedge clk);

            force uut.pulse_fsm = 1'b0;

            @(negedge clk);

            release uut.tecla_ok;
            release uut.pulse_fsm;

            // Pequeña pausa entre teclas
            repeat (5) @(posedge clk);
        end
    endtask

    // ---------------------------------------------------------
    // Tarea: ingresar número decimal de hasta 3 dígitos
    //
    // Ejemplos:
    //   ingresar_numero_3dig(127)
    //   ingresar_numero_3dig(11)
    //   ingresar_numero_3dig(1)
    // ---------------------------------------------------------
    task ingresar_numero_3dig;
        input integer numero;

        integer centenas;
        integer decenas;
        integer unidades;

        begin
            centenas = numero / 100;
            decenas  = (numero / 10) % 10;
            unidades = numero % 10;

            if (numero >= 100) begin
                enviar_tecla(centenas[3:0]);
                enviar_tecla(decenas[3:0]);
                enviar_tecla(unidades[3:0]);
            end else if (numero >= 10) begin
                enviar_tecla(decenas[3:0]);
                enviar_tecla(unidades[3:0]);
            end else begin
                enviar_tecla(unidades[3:0]);
            end
        end
    endtask

    // ---------------------------------------------------------
    // Tarea: esperar resultado estable del divisor
    // ---------------------------------------------------------
    task esperar_done;
        begin
            wait (uut.div_done == 1'b1 || uut.div_zero == 1'b1);
            repeat (5) @(posedge clk);
        end
    endtask

    // ---------------------------------------------------------
    // Tarea: imprimir estado interno relevante
    // ---------------------------------------------------------
    task imprimir_estado;
        input string etiqueta;

        begin
            $display("----------------------------------------");
            $display("%s", etiqueta);

            $display("Estado FSM       = %0d", uut.s_est);
            $display("Dividendo bin    = %0d", uut.dividendo_bin);
            $display("Divisor bin      = %0d", uut.divisor_bin);
            $display("valid_div        = %b",  uut.valid_div);

            $display("div_done         = %b",  uut.div_done);
            $display("div_zero         = %b",  uut.div_zero);
            $display("mostrar_residuo  = %b",  uut.mostrar_residuo);

            $display("Cociente Q       = %0d", uut.cociente);
            $display("Residuo R        = %0d", uut.residuo);

            $display("BCD display      = %h%h%h%h",
                     uut.v4, uut.v3, uut.v2, uut.v1);

            $display("----------------------------------------");
            $display("");
        end
    endtask

    // ---------------------------------------------------------
    // Tarea: probar una división completa usando la interfaz
    //
    // Secuencia:
    //   ingresar A
    //   presionar A
    //   ingresar B
    //   presionar A
    //   leer cociente
    //   presionar B
    //   leer residuo
    // ---------------------------------------------------------
    task probar_division;
        input integer dividendo;
        input integer divisor;
        input integer esperado_Q;
        input integer esperado_R;

        begin
            reset_sistema();

            $display("========================================");
            $display("Prueba: %0d / %0d", dividendo, divisor);
            $display("========================================");

            // Ingresar dividendo
            ingresar_numero_3dig(dividendo);
            imprimir_estado("Despues de ingresar dividendo");

            // Confirmar dividendo con A
            enviar_tecla(4'hA);
            imprimir_estado("Despues de presionar A para dividendo");

            // Ingresar divisor
            ingresar_numero_3dig(divisor);
            imprimir_estado("Despues de ingresar divisor");

            // Confirmar divisor con A e iniciar division
            enviar_tecla(4'hA);

            esperar_done();

            imprimir_estado("Resultado inicial despues de division");

            if (divisor == 0) begin
                if (uut.div_zero) begin
                    $display("RESULTADO DIV_ZERO: OK");
                end else begin
                    $display("RESULTADO DIV_ZERO: ERROR");
                end
            end else begin
                if (uut.cociente == esperado_Q && uut.residuo == esperado_R) begin
                    $display("RESULTADO MATEMATICO: OK");
                end else begin
                    $display("RESULTADO MATEMATICO: ERROR");
                    $display("Esperado Q = %0d, R = %0d", esperado_Q, esperado_R);
                end
            end

            $display("");

            // Alternar con B
            enviar_tecla(4'hB);
            repeat (10) @(posedge clk);

            imprimir_estado("Despues de presionar B");

            $display("Fin prueba %0d / %0d", dividendo, divisor);
            $display("");
        end
    endtask

    // ---------------------------------------------------------
    // Secuencia principal
    // ---------------------------------------------------------
    initial begin
        clk   = 1'b0;
        reset = 1'b1;
        filas = 4'b1111;

        $display("");
        $display("========================================");
        $display(" TESTBENCH SISTEMA COMPLETO - TOP");
        $display("========================================");
        $display("");

        // Casos validados en placa
        probar_division(11,  2,  5, 1);
        probar_division(11,  3,  3, 2);
        probar_division(127, 31, 4, 3);

        // Caso pequeño
        probar_division(1,   1,  1, 0);

        // Division entre cero
        probar_division(78,  0,  0, 0);

        $display("========================================");
        $display(" FIN DE SIMULACION");
        $display("========================================");

        $stop;
    end

endmodule