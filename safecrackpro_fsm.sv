module safecrack_fsm (
    input  logic        clk,
    input  logic        rstn,       // Ligado ao KEY[0] fisicamente no top
    input  logic [3:1]  key,        // KEY[0] foi removido daqui
    output logic [3:0]  d0, d1, d2, d3, // Todos os 4 dígitos visíveis o tempo todo
    output logic [1:0]  active,
    output logic        unlocked,
    output logic        failed
);

    localparam logic [3:0] PASS [0:3] = '{4'd1, 4'd2, 4'd1, 4'd2};

    localparam logic [27:0] T_OK  = 28'd250_000_000;
    localparam logic [27:0] T_ERR = 28'd150_000_000;

    typedef enum logic [1:0] {
        EDITING = 2'd0,
        CHECK   = 2'd1,
        SUCCESS = 2'd2,
        FAIL    = 2'd3
    } state_t;

    state_t state, next_state;

    logic [3:0] digits [0:3];
    logic [3:0] next_digits [0:3];
    logic [1:0] active_reg, next_active;
    logic [3:0] next_digit_val;
    logic [27:0] timer, next_timer;
    
    logic [3:1] key_pos, key_prev, key_edge;

    always_comb begin
        key_pos  = ~key; // Lógica invertida dos botões (ativos em baixa)
        key_edge = key_pos & ~key_prev;
    end

    always_ff @(posedge clk or negedge rstn) begin
        if (~rstn) begin
            state      <= EDITING;
            active_reg <= 2'd3; // Começa no HEX3
            timer      <= '0;
            key_prev   <= '0;
            digits[0]  <= '0;
            digits[1]  <= '0;
            digits[2]  <= '0;
            digits[3]  <= '0;
        end else begin
            state      <= next_state;
            active_reg <= next_active;
            timer      <= next_timer;
            key_prev   <= key_pos;
            digits[0]  <= next_digits[0];
            digits[1]  <= next_digits[1];
            digits[2]  <= next_digits[2];
            digits[3]  <= next_digits[3];
        end
    end

    always_comb begin
        next_state     = state;
        next_active    = active_reg;
        next_timer     = timer;
        next_digits[0] = digits[0];
        next_digits[1] = digits[1];
        next_digits[2] = digits[2];
        next_digits[3] = digits[3];
        next_digit_val = digits[active_reg];

        unique case (state)
            EDITING: begin
                if (key_edge[3]) begin
                    next_digit_val = (digits[active_reg] == 4'd0) ? 4'd9 : digits[active_reg] - 1;
                    next_digits[active_reg] = next_digit_val;
                end
                else if (key_edge[2]) begin
                    next_digit_val = (digits[active_reg] == 4'd9) ? 4'd0 : digits[active_reg] + 1;
                    next_digits[active_reg] = next_digit_val;
                end
                else if (key_edge[1]) begin
                    if (active_reg == 2'd0)
                        next_state = CHECK;
                    else
                        next_active = active_reg - 1; // Vai do 3 para o 0
                end
            end

            CHECK: begin
                // digits[3] é o 1º dígito digitado (HEX3) e digits[0] é o 4º (HEX0).
                // PASS[0..3] está na ordem de digitação (1º ao 4º dígito),
                // por isso a comparação é cruzada: digits[3]<->PASS[0], etc.
                if (digits[3] == PASS[0] && digits[2] == PASS[1] &&
                    digits[1] == PASS[2] && digits[0] == PASS[3]) begin
                    next_state = SUCCESS;
                    next_timer = T_OK;
                end else begin
                    next_state = FAIL;
                    next_timer = T_ERR;
                end
            end

            SUCCESS: begin
                if (timer > 0)
                    next_timer = timer - 1;
                else begin
                    next_state = EDITING;
                    next_digits[0] = '0; next_digits[1] = '0; 
                    next_digits[2] = '0; next_digits[3] = '0;
                    next_active = 2'd3;
                end
            end

            FAIL: begin
                if (timer > 0)
                    next_timer = timer - 1;
                else begin
                    next_state = EDITING;
                    next_digits[0] = '0; next_digits[1] = '0; 
                    next_digits[2] = '0; next_digits[3] = '0;
                    next_active = 2'd3;
                end
            end

            default: next_state = EDITING;
        endcase
    end

    always_comb begin
        d0       = digits[0];
        d1       = digits[1];
        d2       = digits[2];
        d3       = digits[3];
        active   = active_reg;
        unlocked = (state == SUCCESS);
        failed   = (state == FAIL);
    end

endmodule