module top (
    input  logic clk,
    input  logic reset,
    input  logic [3:0] filas,
    output logic [3:0] columnas,
    output logic [3:0] anodos,
    output logic [6:0] siete_seg,
    output logic led_externo_contacto,
    output logic led_externo_pulso,
    output logic led_externo_bit0
);

    // ---------------------------------------------------------
    // Reset externo activo en 0
    // ---------------------------------------------------------
    logic rst_high;
    assign rst_high = ~reset;

    // ---------------------------------------------------------
    // Señales teclado
    // ---------------------------------------------------------
    logic tecla_v_raw;
    logic [3:0] tecla_p_raw;

    wire pulse_ok;
    wire [3:0] tecla_ok;

    logic pulse_fsm;

    // ---------------------------------------------------------
    // Señales FSM de captura
    // ---------------------------------------------------------
    logic [6:0] dividendo_bin;
    logic [4:0] divisor_bin;

    logic       valid_div;
    logic       mostrar_residuo;
    logic [3:0] s_est;

    logic [3:0] c1, d1, u1;
    logic [3:0] c2, d2, u2;

    // ---------------------------------------------------------
    // Señales divisor
    // ---------------------------------------------------------
    logic [6:0] cociente;
    logic [4:0] residuo;

    logic div_done;
    logic div_busy;
    logic div_zero;

    // ---------------------------------------------------------
    // Señales display
    // ---------------------------------------------------------
    logic [10:0] valor_display_bin;

    logic [3:0] res_m;
    logic [3:0] res_c;
    logic [3:0] res_d;
    logic [3:0] res_u;

    logic [3:0] v1;
    logic [3:0] v2;
    logic [3:0] v3;
    logic [3:0] v4;

    // ---------------------------------------------------------
    // LEDs de depuración
    // ---------------------------------------------------------
    assign led_externo_contacto = ~tecla_v_raw;
    assign led_externo_pulso    = ~pulse_ok;
    assign led_externo_bit0     = ~tecla_ok[0];

    // ---------------------------------------------------------
    // Scanner teclado 4x4
    // ---------------------------------------------------------
    scanner u_scan (
        .clk(clk),
        .reset(rst_high),
        .stop_scanning(tecla_v_raw),
        .filas(filas),
        .columnas(columnas),
        .tecla_detectada(tecla_v_raw),
        .pos_tecla(tecla_p_raw)
    );

    // ---------------------------------------------------------
    // Debouncer
    // ---------------------------------------------------------
    debounce #(.N(21)) u_debounce (
        .clk(clk),
        .rst(rst_high),
        .valido(tecla_v_raw),
        .tecla(tecla_p_raw),
        .limpio(pulse_ok),
        .seleccion(tecla_ok)
    );

    // ---------------------------------------------------------
    // Registro de pulso hacia FSM
    // Conserva la misma idea usada en el proyecto anterior.
    // ---------------------------------------------------------
    always_ff @(posedge clk or posedge rst_high) begin
        if (rst_high)
            pulse_fsm <= 1'b0;
        else
            pulse_fsm <= pulse_ok;
    end

    // ---------------------------------------------------------
    // FSM de captura de datos
    // A confirma dividendo y divisor.
    // B alterna entre cociente y residuo.
    // ---------------------------------------------------------
    FSM_control u_fsm (
        .clk(clk),
        .reset(rst_high),
        .pulse_tecla(pulse_fsm),
        .pos_tecla(tecla_ok),

        .dividendo_bin(dividendo_bin),
        .divisor_bin(divisor_bin),
        .valid_div(valid_div),
        .mostrar_residuo(mostrar_residuo),
        .estado_vis(s_est),

        .c1_o(c1),
        .d1_o(d1),
        .u1_o(u1),

        .c2_o(c2),
        .d2_o(d2),
        .u2_o(u2)
    );

    // ---------------------------------------------------------
    // Divisor entero sin signo
    // Usar el divisor_entero_fix.sv que ya validamos en FPGA.
    // ---------------------------------------------------------
    divisor_entero_fix #(
        .N(7),
        .M(5)
    ) u_divisor (
        .clk(clk),
        .reset(rst_high),
        .valid(valid_div),

        .A(dividendo_bin),
        .B(divisor_bin),

        .Q(cociente),
        .R(residuo),

        .done(div_done),
        .busy(div_busy),
        .div_zero(div_zero)
    );

    // ---------------------------------------------------------
    // Selector de resultado para display
    //
    // mostrar_residuo = 0 -> cociente
    // mostrar_residuo = 1 -> residuo
    // ---------------------------------------------------------
    always_comb begin
        if (div_zero) begin
            valor_display_bin = 11'd0;
        end else if (mostrar_residuo) begin
            valor_display_bin = {6'd0, residuo};
        end else begin
            valor_display_bin = {4'd0, cociente};
        end
    end

    // ---------------------------------------------------------
    // Conversión binario a BCD para mostrar Q o R
    // ---------------------------------------------------------
    bin_to_bcd u_bcd (
        .clk(clk),
        .reset(rst_high),
        .binario(valor_display_bin),
        .millar(res_m),
        .centena(res_c),
        .decena(res_d),
        .unidad(res_u)
    );

    // ---------------------------------------------------------
    // Selección de qué se muestra en el display
    // ---------------------------------------------------------
    always_comb begin

        if (s_est == 4'd8) begin

            if (div_zero) begin
                // División entre cero
                // Muestra: E000
                {v4, v3, v2, v1} = {4'hE, 4'd0, 4'd0, 4'd0};
            end else if (!div_done) begin
                // Mientras no está estable el resultado
                // Muestra: 0000
                {v4, v3, v2, v1} = {4'd0, 4'd0, 4'd0, 4'd0};
            end else begin
                // Resultado estable
                // B alterna entre cociente y residuo
                {v4, v3, v2, v1} = {res_m, res_c, res_d, res_u};
            end

        end else if (s_est < 4'd4) begin

            // Captura del dividendo
            // Muestra: -XYZ
            {v4, v3, v2, v1} = {4'hF, c1, d1, u1};

        end else begin

            // Captura del divisor
            // Muestra: -XYZ
            {v4, v3, v2, v1} = {4'hF, c2, d2, u2};

        end
    end

    // ---------------------------------------------------------
    // Controlador de displays 7 segmentos
    // ---------------------------------------------------------
    controlador_display_total u_disp (
        .clk(clk),
        .reset(rst_high),

        .val1(v1),
        .val2(v2),
        .val3(v3),
        .val4(v4),

        .anodos(anodos),
        .siete_seg(siete_seg)
    );

endmodule