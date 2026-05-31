module FSM_control (
    input  logic clk,
    input  logic reset,
    input  logic pulse_tecla,
    input  logic [3:0] pos_tecla,

    output logic [6:0] dividendo_bin,
    output logic [4:0] divisor_bin,
    output logic       valid_div,
    output logic       mostrar_residuo,
    output logic [3:0] estado_vis,

    output logic [3:0] c1_o, d1_o, u1_o,
    output logic [3:0] c2_o, d2_o, u2_o
);

    typedef enum logic [3:0] {
        S_N1_D1      = 4'd0,
        S_N1_D2      = 4'd1,
        S_N1_D3      = 4'd2,
        S_N1_ENTER   = 4'd3,
        S_N2_D1      = 4'd4,
        S_N2_D2      = 4'd5,
        S_N2_D3      = 4'd6,
        S_N2_ENTER   = 4'd7,
        S_RESULTADO  = 4'd8
    } estado_t;

    estado_t state;

    logic [3:0] c1, d1, u1;
    logic [3:0] c2, d2, u2;
    logic       sel_residuo;

    logic [13:0] n1_tmp;
    logic [13:0] n2_tmp;

    function automatic logic es_digito(input logic [3:0] tecla);
        begin
            unique case (tecla)
                4'h0, 4'h1, 4'h2, 4'h3, 4'h4,
                4'h5, 4'h6, 4'h7, 4'h8, 4'h9: es_digito = 1'b1;
                default: es_digito = 1'b0;
            endcase
        end
    endfunction

    function automatic logic es_enter(input logic [3:0] tecla);
        begin
            es_enter = (tecla == 4'hA);
        end
    endfunction

    function automatic logic es_selector(input logic [3:0] tecla);
        begin
            es_selector = (tecla == 4'hB);
        end
    endfunction

    function automatic logic [13:0] dec3_to_bin(
        input logic [3:0] c,
        input logic [3:0] d,
        input logic [3:0] u
    );
        logic [13:0] cw, dw, uw;
        begin
            cw = {10'd0, c};
            dw = {10'd0, d};
            uw = {10'd0, u};

            dec3_to_bin = (cw << 6) + (cw << 5) + (cw << 2) +
                          (dw << 3) + (dw << 1) + uw;
        end
    endfunction

    assign c1_o = c1;
    assign d1_o = d1;
    assign u1_o = u1;

    assign c2_o = c2;
    assign d2_o = d2;
    assign u2_o = u2;

    assign estado_vis      = state;
    assign mostrar_residuo = sel_residuo;

    // valid_div es combinacional para que el divisor lo vea en el mismo flanco
    // en que se confirma el divisor con A.
    assign valid_div = pulse_tecla && es_enter(pos_tecla) &&
                       ((state == S_N2_D2) || (state == S_N2_D3) || (state == S_N2_ENTER));

    assign n1_tmp = dec3_to_bin(c1, d1, u1);
    assign n2_tmp = dec3_to_bin(c2, d2, u2);

    // Saturación simple para cumplir el rango del hardware:
    // A: 0..127, B: 0..31.
    assign dividendo_bin = (n1_tmp > 14'd127) ? 7'd127 : n1_tmp[6:0];
    assign divisor_bin   = (n2_tmp > 14'd31)  ? 5'd31  : n2_tmp[4:0];

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= S_N1_D1;

            c1 <= 4'd0;
            d1 <= 4'd0;
            u1 <= 4'd0;

            c2 <= 4'd0;
            d2 <= 4'd0;
            u2 <= 4'd0;

            sel_residuo <= 1'b0;
        end else begin
            if (pulse_tecla) begin
                unique case (state)

                    // -------------------------
                    // Dividendo A
                    // -------------------------
                    S_N1_D1: begin
                        if (es_digito(pos_tecla)) begin
                            c1 <= d1;
                            d1 <= u1;
                            u1 <= pos_tecla;
                            state <= S_N1_D2;
                        end
                    end

                    S_N1_D2: begin
                        if (es_digito(pos_tecla)) begin
                            c1 <= d1;
                            d1 <= u1;
                            u1 <= pos_tecla;
                            state <= S_N1_D3;
                        end else if (es_enter(pos_tecla)) begin
                            state <= S_N2_D1;
                        end
                    end

                    S_N1_D3: begin
                        if (es_digito(pos_tecla)) begin
                            c1 <= d1;
                            d1 <= u1;
                            u1 <= pos_tecla;
                            state <= S_N1_ENTER;
                        end else if (es_enter(pos_tecla)) begin
                            state <= S_N2_D1;
                        end
                    end

                    S_N1_ENTER: begin
                        if (es_enter(pos_tecla)) begin
                            state <= S_N2_D1;
                        end
                    end

                    // -------------------------
                    // Divisor B
                    // -------------------------
                    S_N2_D1: begin
                        if (es_digito(pos_tecla)) begin
                            c2 <= d2;
                            d2 <= u2;
                            u2 <= pos_tecla;
                            state <= S_N2_D2;
                        end
                    end

                    S_N2_D2: begin
                        if (es_digito(pos_tecla)) begin
                            c2 <= d2;
                            d2 <= u2;
                            u2 <= pos_tecla;
                            state <= S_N2_D3;
                        end else if (es_enter(pos_tecla)) begin
                            state <= S_RESULTADO;
                        end
                    end

                    S_N2_D3: begin
                        if (es_digito(pos_tecla)) begin
                            c2 <= d2;
                            d2 <= u2;
                            u2 <= pos_tecla;
                            state <= S_N2_ENTER;
                        end else if (es_enter(pos_tecla)) begin
                            state <= S_RESULTADO;
                        end
                    end

                    S_N2_ENTER: begin
                        if (es_enter(pos_tecla)) begin
                            state <= S_RESULTADO;
                        end
                    end

                    // -------------------------
                    // Resultado
                    // -------------------------
                    S_RESULTADO: begin
                        if (es_selector(pos_tecla)) begin
                            sel_residuo <= ~sel_residuo;
                        end
                    end

                    default: begin
                        state <= S_N1_D1;
                        c1 <= 4'd0;
                        d1 <= 4'd0;
                        u1 <= 4'd0;
                        c2 <= 4'd0;
                        d2 <= 4'd0;
                        u2 <= 4'd0;
                        sel_residuo <= 1'b0;
                    end
                endcase
            end
        end
    end

endmodule
