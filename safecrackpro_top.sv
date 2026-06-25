module safecrack_top (
    input  logic        CLOCK_50,
    input  logic [3:0]  KEY,
    output logic [6:0]  HEX0, HEX1, HEX2, HEX3,
    output logic [6:0]  HEX4,      // Novo display para o dígito ativo
    output logic [7:0]  LEDG,      // 8 LEDs verdes na DE2-115
    output logic [17:0] LEDR       // 18 LEDs vermelhos na DE2-115
);

    logic [3:0] d0, d1, d2, d3;
    logic [1:0] active;
    logic unlocked, failed;

    // FSM
    safecrack_fsm u_fsm (
        .clk      (CLOCK_50),
        .rstn     (KEY[0]),      // KEY[0] entra só no reset
        .key      (KEY[3:1]),    // FSM só vê os botões 3 a 1
        .d0       (d0),
        .d1       (d1),
        .d2       (d2),
        .d3       (d3),
        .active   (active),
        .unlocked (unlocked),
        .failed   (failed)
    );

    // Decodificadores da Senha
    seg7_decoder u_hex0 (.num(d0), .seg(HEX0));
    seg7_decoder u_hex1 (.num(d1), .seg(HEX1));
    seg7_decoder u_hex2 (.num(d2), .seg(HEX2));
    seg7_decoder u_hex3 (.num(d3), .seg(HEX3));

    // Decodificador do Dígito Ativo
    logic [3:0] active_index;
    // Transforma o índice (3 a 0) em valor visual (1 a 4)
    assign active_index = 4'd4 - {2'b00, active}; 
    seg7_decoder u_hex4 (.num(active_index), .seg(HEX4));

    // Saídas de LEDs
    always_comb begin
        LEDG = unlocked ? 8'hFF   : 8'h00;
        LEDR = failed   ? 18'h3FFFF : 18'h00000;
    end

endmodule