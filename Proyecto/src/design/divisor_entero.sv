module divisor_entero_fix #(
    parameter N = 7,   // dividendo: 0 a 127
    parameter M = 5    // divisor:   0 a 31
)(
    input  logic         clk,
    input  logic         reset,
    input  logic         valid,
    input  logic [N-1:0] A,
    input  logic [M-1:0] B,

    output logic [N-1:0] Q,
    output logic [M-1:0] R,
    output logic         done,
    output logic         busy,
    output logic         div_zero
);

    // ---------------------------------------------------------
    // Estados Moore
    // ---------------------------------------------------------
    logic [1:0] state, nextstate;

    parameter IDLE    = 2'b00;
    parameter RUN     = 2'b01;
    parameter DONE_ST = 2'b10;
    parameter ERR_Z   = 2'b11;

    // ---------------------------------------------------------
    // Registros internos
    // ---------------------------------------------------------
    logic [N-1:0] q_work;
    logic [N-1:0] r_work;
    logic [N-1:0] b_ext;

    // ---------------------------------------------------------
    // Registro de estado
    // ---------------------------------------------------------
    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            state <= IDLE;
        else
            state <= nextstate;
    end

    // ---------------------------------------------------------
    // Lógica de siguiente estado
    // ---------------------------------------------------------
    always_comb begin
        case (state)

            IDLE: begin
                if (valid && (B == {M{1'b0}}))
                    nextstate = ERR_Z;
                else if (valid)
                    nextstate = RUN;
                else
                    nextstate = IDLE;
            end

            RUN: begin
                if (r_work >= b_ext)
                    nextstate = RUN;
                else
                    nextstate = DONE_ST;
            end

            DONE_ST: begin
                nextstate = DONE_ST;
            end

            ERR_Z: begin
                nextstate = ERR_Z;
            end

            default: begin
                nextstate = IDLE;
            end

        endcase
    end

    // ---------------------------------------------------------
    // Ruta de datos
    //
    // Algoritmo:
    //   q_work = 0
    //   r_work = A
    //   mientras r_work >= B:
    //       r_work = r_work - B
    //       q_work = q_work + 1
    //
    // Al terminar:
    //   Q = q_work
    //   R = r_work
    // ---------------------------------------------------------
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            q_work   <= {N{1'b0}};
            r_work   <= {N{1'b0}};
            b_ext    <= {N{1'b0}};

            Q        <= {N{1'b0}};
            R        <= {M{1'b0}};
            done     <= 1'b0;
            busy     <= 1'b0;
            div_zero <= 1'b0;
        end else begin

            case (state)

                IDLE: begin
                    Q        <= {N{1'b0}};
                    R        <= {M{1'b0}};
                    done     <= 1'b0;
                    busy     <= 1'b0;
                    div_zero <= 1'b0;

                    q_work   <= {N{1'b0}};
                    r_work   <= {N{1'b0}};
                    b_ext    <= {N{1'b0}};

                    if (valid) begin
                        if (B == {M{1'b0}}) begin
                            Q        <= {N{1'b0}};
                            R        <= {M{1'b0}};
                            done     <= 1'b1;
                            busy     <= 1'b0;
                            div_zero <= 1'b1;
                        end else begin
                            q_work <= {N{1'b0}};
                            r_work <= A;
                            b_ext  <= {{(N-M){1'b0}}, B};

                            done     <= 1'b0;
                            busy     <= 1'b1;
                            div_zero <= 1'b0;
                        end
                    end
                end

                RUN: begin
                    busy <= 1'b1;
                    done <= 1'b0;

                    if (r_work >= b_ext) begin
                        r_work <= r_work - b_ext;
                        q_work <= q_work + {{(N-1){1'b0}}, 1'b1};
                    end else begin
                        Q    <= q_work;
                        R    <= r_work[M-1:0];
                        busy <= 1'b0;
                        done <= 1'b1;
                    end
                end

                DONE_ST: begin
                    busy <= 1'b0;
                    done <= 1'b1;

                    // Mantiene Q y R estables
                    Q <= Q;
                    R <= R;
                end

                ERR_Z: begin
                    Q        <= {N{1'b0}};
                    R        <= {M{1'b0}};
                    busy     <= 1'b0;
                    done     <= 1'b1;
                    div_zero <= 1'b1;
                end

                default: begin
                    busy <= 1'b0;
                    done <= 1'b0;
                end

            endcase
        end
    end

endmodule