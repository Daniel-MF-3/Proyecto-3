`timescale 1ns/1ps

module tb_FSM_datos;

    // ---------------------------------------------------------
    // Señales de entrada
    // ---------------------------------------------------------
    logic clk;
    logic reset;
    logic pulse_tecla;
    logic [3:0] pos_tecla;

    // ---------------------------------------------------------
    // Señales de salida
    // ---------------------------------------------------------
    logic [6:0] dividendo_bin;
    logic [4:0] divisor_bin;

    logic valid_div;
    logic mostrar_residuo;
    logic [3:0] estado_vis;

    logic [3:0] c1_o;
    logic [3:0] d1_o;
    logic [3:0] u1_o;

    logic [3:0] c2_o;
    logic [3:0] d2_o;
    logic [3:0] u2_o;

    // ---------------------------------------------------------
    // DUT
    // ---------------------------------------------------------
    FSM_control dut (
        .clk(clk),
        .reset(reset),
        .pulse_tecla(pulse_tecla),
        .pos_tecla(pos_tecla),

        .dividendo_bin(dividendo_bin),
        .divisor_bin(divisor_bin),
        .valid_div(valid_div),
        .mostrar_residuo(mostrar_residuo),
        .estado_vis(estado_vis),

        .c1_o(c1_o),
        .d1_o(d1_o),
        .u1_o(u1_o),

        .c2_o(c2_o),
        .d2_o(d2_o),
        .u2_o(u2_o)
    );

    // ---------------------------------------------------------
    // Reloj
    // ---------------------------------------------------------
    always #5 clk = ~clk;

    // ---------------------------------------------------------
    // Reset
    // ---------------------------------------------------------
    task aplicar_reset;
        begin
            reset       = 1'b1;
            pulse_tecla = 1'b0;
            pos_tecla   = 4'd0;

            repeat (5) @(posedge clk);

            reset = 1'b0;

            repeat (3) @(posedge clk);
        end
    endtask

    // ---------------------------------------------------------
    // Enviar una tecla
    //
    // Códigos:
    //   0-9 -> dígitos
    //   A   -> 4'hA
    //   B   -> 4'hB
    // ---------------------------------------------------------
    task enviar_tecla;
        input [3:0] tecla;

        begin
            @(negedge clk);
            pos_tecla   = tecla;
            pulse_tecla = 1'b1;

            @(negedge clk);
            pulse_tecla = 1'b0;

            repeat (3) @(posedge clk);
        end
    endtask

    // ---------------------------------------------------------
    // Ingresar número decimal de hasta 3 dígitos
    // ---------------------------------------------------------
    task ingresar_numero;
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
    // Imprimir estado de la FSM
    // ---------------------------------------------------------
    task imprimir_estado;
        input string texto;

        begin
            $display("----------------------------------------");
            $display("%s", texto);
            $display("estado_vis       = %0d", estado_vis);

            $display("dividendo_bin    = %0d", dividendo_bin);
            $display("divisor_bin      = %0d", divisor_bin);

            $display("valid_div        = %b", valid_div);
            $display("mostrar_residuo  = %b", mostrar_residuo);

            $display("Display N1       = %0d%0d%0d", c1_o, d1_o, u1_o);
            $display("Display N2       = %0d%0d%0d", c2_o, d2_o, u2_o);
            $display("----------------------------------------");
            $display("");
        end
    endtask

    // ---------------------------------------------------------
    // Verificación simple
    // ---------------------------------------------------------
    task verificar_valor;
        input string nombre;
        input integer obtenido;
        input integer esperado;

        begin
            if (obtenido == esperado) begin
                $display("OK: %s = %0d", nombre, obtenido);
            end else begin
                $display("ERROR: %s = %0d, esperado = %0d",
                         nombre, obtenido, esperado);
            end
        end
    endtask

    // ---------------------------------------------------------
    // Prueba completa de captura:
    // dividendo -> A -> divisor -> A
    // ---------------------------------------------------------
    task probar_captura;
        input integer dividendo;
        input integer divisor;

        begin
            aplicar_reset();

            $display("========================================");
            $display("PRUEBA FSM_DATOS: %0d / %0d", dividendo, divisor);
            $display("========================================");

            ingresar_numero(dividendo);
            imprimir_estado("Despues de ingresar dividendo");

            verificar_valor("dividendo_bin", dividendo_bin, dividendo);

            enviar_tecla(4'hA);
            imprimir_estado("Despues de presionar A para confirmar dividendo");

            ingresar_numero(divisor);
            imprimir_estado("Despues de ingresar divisor");

            verificar_valor("divisor_bin", divisor_bin, divisor);

            enviar_tecla(4'hA);
            imprimir_estado("Despues de presionar A para confirmar divisor");

            verificar_valor("dividendo_bin final", dividendo_bin, dividendo);
            verificar_valor("divisor_bin final", divisor_bin, divisor);

            if (valid_div)
                $display("OK: valid_div se activo.");
            else
                $display("AVISO: valid_div no esta alto en este instante. Puede ser pulso de 1 ciclo.");

            $display("");
        end
    endtask

    // ---------------------------------------------------------
    // Prueba de tecla B
    // ---------------------------------------------------------
    task probar_tecla_B;

        begin
            $display("========================================");
            $display("PRUEBA TECLA B");
            $display("========================================");

            imprimir_estado("Antes de presionar B");

            enviar_tecla(4'hB);
            imprimir_estado("Despues de presionar B una vez");

            enviar_tecla(4'hB);
            imprimir_estado("Despues de presionar B dos veces");

            $display("");
        end
    endtask

    // ---------------------------------------------------------
    // Secuencia principal
    // ---------------------------------------------------------
    initial begin
        clk         = 1'b0;
        reset       = 1'b0;
        pulse_tecla = 1'b0;
        pos_tecla   = 4'd0;

        $display("");
        $display("========================================");
        $display(" TESTBENCH FSM_DATOS");
        $display("========================================");
        $display("");

        // Caso normal de 2 dígitos / 1 dígito
        probar_captura(11, 2);
        probar_tecla_B();

        // Caso máximo requerido
        probar_captura(127, 31);
        probar_tecla_B();

        // Caso pequeño
        probar_captura(1, 1);
        probar_tecla_B();

        // División entre cero: la FSM solo captura;
        // el error lo detecta el divisor.
        probar_captura(78, 0);

        $display("========================================");
        $display(" FIN TESTBENCH FSM_DATOS");
        $display("========================================");

        $stop;
    end

endmodule
