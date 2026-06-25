`timescale 1ns/1ps
// =====================================================================
// Testbench para safecrack_top (SafeCrack PRO)
//
// Compile todos os .sv e simule este modulo (work.safecrack_tb).
//
// Botoes (ativos em nivel baixo; mascara = bits a pressionar em '1'):
//   KEY[0] = 4'b0001 -> RESET
//   KEY[1] = 4'b0010 -> CONFIRMA / avanca dígito (no 4º, verifica a senha)
//   KEY[2] = 4'b0100 -> INCREMENTA o dígito ativo (seta direita, wrap 9->0)
//   KEY[3] = 4'b1000 -> DECREMENTA o dígito ativo (seta esquerda, wrap 0->9)
//
// Senha correta: 1-2-1-2 (1º ao 4º dígito).
//   digits[3] = 1º dígito (HEX3) ... digits[0] = 4º dígito (HEX0)
//
// Os estados SUCCESS/FAIL esperam 250M/150M ciclos. Para nao simular esse
// tempo, o testbench forca o contador interno 'timer' a zero (via 'force').
// =====================================================================

module safecrack_tb;

    // ----------------------------------------------------------------
    // Sinais
    // ----------------------------------------------------------------
    logic        clk;
    logic [3:0]  key;
    logic [6:0]  HEX0, HEX1, HEX2, HEX3, HEX4;
    logic [8:0]  LEDG;
    logic [17:0] LEDR;

    // ----------------------------------------------------------------
    // DUT
    // ----------------------------------------------------------------
    safecrack_top u_top (
        .CLOCK_50 (clk),
        .KEY      (key),
        .HEX0     (HEX0),
        .HEX1     (HEX1),
        .HEX2     (HEX2),
        .HEX3     (HEX3),
        .HEX4     (HEX4),
        .LEDG     (LEDG),
        .LEDR     (LEDR)
    );

    // ----------------------------------------------------------------
    // Clock: 50 MHz (periodo 20 ns)
    // ----------------------------------------------------------------
    initial clk = 0;
    always #10 clk = ~clk;

    // ----------------------------------------------------------------
    // Mascaras de botao e padroes de 7-seg (seg7_decoder, anodo comum)
    // ----------------------------------------------------------------
    localparam logic [3:0] RESET   = 4'b0001;
    localparam logic [3:0] CONFIRM = 4'b0010;
    localparam logic [3:0] INC     = 4'b0100;
    localparam logic [3:0] DEC     = 4'b1000;

    function automatic logic [6:0] seg7 (input int v);
        case (v)
            0: seg7 = 7'b1000000;
            1: seg7 = 7'b1111001;
            2: seg7 = 7'b0100100;
            3: seg7 = 7'b0110000;
            4: seg7 = 7'b0011001;
            5: seg7 = 7'b0010010;
            6: seg7 = 7'b0000010;
            7: seg7 = 7'b1111000;
            8: seg7 = 7'b0000000;
            9: seg7 = 7'b0010000;
            default: seg7 = 7'b1111111;
        endcase
    endfunction

    // ----------------------------------------------------------------
    // Contadores de resultado
    // ----------------------------------------------------------------
    int pass_cnt = 0, fail_cnt = 0, test_num = 0;

    task automatic check(input string nome, input logic cond);
        test_num++;
        if (cond) begin
            $display("  [PASS] #%0d: %s", test_num, nome);
            pass_cnt++;
        end else begin
            $display("  [FAIL] #%0d: %s  (t=%0t)", test_num, nome, $time);
            fail_cnt++;
        end
    endtask

    // ----------------------------------------------------------------
    // reset (KEY[0], assincrono e ativo em baixa)
    // ----------------------------------------------------------------
    task do_reset();
        key = 4'b1111;
        @(negedge clk);
        key = ~RESET;          // KEY[0] = 0
        repeat(3) @(posedge clk);
        @(negedge clk);
        key = 4'b1111;         // libera reset
        @(posedge clk);
    endtask

    // ----------------------------------------------------------------
    // press: pressiona uma mascara por 'hold' bordas e solta.
    // A deteccao de borda garante uma unica acao por chamada.
    // ----------------------------------------------------------------
    task automatic press(input logic [3:0] mask, input int hold = 3);
        @(negedge clk);
        key = ~mask;
        repeat(hold) @(posedge clk);
        @(negedge clk);
        key = 4'b1111;
        @(posedge clk);
    endtask

    // entra um valor no dígito ativo (a partir de 0) com cliques de INC
    task automatic enter_digit(input int val);
        for (int i = 0; i < val; i++) press(INC);
    endtask

    // ----------------------------------------------------------------
    // skip_timer: pula a espera de 5s/3s forcando 'timer' a 0,
    // levando a FSM de SUCCESS/FAIL de volta a EDITING.
    // ----------------------------------------------------------------
    task skip_timer();
        force u_top.u_fsm.timer = '0;
        @(posedge clk);        // SUCCESS/FAIL -> EDITING (zera digitos)
        release u_top.u_fsm.timer;
        @(posedge clk);
    endtask

    // ================================================================
    // Sequencia de testes
    // ================================================================
    initial begin
        $display("================================================");
        $display("   SafeCrack PRO - Testbench ModelSim");
        $display("================================================");

        // ------------------------------------------------------------
        // TESTE 1: Reset inicial
        // ------------------------------------------------------------
        $display("\n[Teste 1] Reset inicial");
        do_reset();
        check("Digitos zerados apos reset",
              u_top.u_fsm.digits[0] == 0 && u_top.u_fsm.digits[1] == 0 &&
              u_top.u_fsm.digits[2] == 0 && u_top.u_fsm.digits[3] == 0);
        check("Digito ativo = primeiro (active_reg = 3)",
              u_top.u_fsm.active_reg == 2'd3);
        check("LEDs vermelhos apagados", LEDR == 18'h00000);
        check("LEDs verdes apagados",    LEDG == 9'h000);
        check("HEX4 indica posicao 1",   HEX4 == seg7(1));
        check("HEX3 exibe 0", HEX3 == seg7(0));
        check("HEX0 exibe 0", HEX0 == seg7(0));

        // ------------------------------------------------------------
        // TESTE 2: Incremento do dígito ativo (KEY[2])
        // ------------------------------------------------------------
        $display("\n[Teste 2] Incremento - KEY[2]");
        press(INC);
        check("digits[3] = 1 apos 1 INC", u_top.u_fsm.digits[3] == 4'd1);
        check("HEX3 exibe 1",             HEX3 == seg7(1));
        press(INC);
        check("digits[3] = 2 apos 2 INC", u_top.u_fsm.digits[3] == 4'd2);
        check("HEX3 exibe 2",             HEX3 == seg7(2));

        // ------------------------------------------------------------
        // TESTE 3: Decremento do dígito ativo (KEY[3])
        // ------------------------------------------------------------
        $display("\n[Teste 3] Decremento - KEY[3]");
        press(DEC);
        check("digits[3] = 1 apos DEC", u_top.u_fsm.digits[3] == 4'd1);

        // ------------------------------------------------------------
        // TESTE 4: Wrap-around DEC 0 -> 9
        // ------------------------------------------------------------
        $display("\n[Teste 4] Wrap-around DEC: 0 -> 9");
        press(DEC);                       // 1 -> 0
        press(DEC);                       // 0 -> 9 (wrap)
        check("digits[3] = 9 apos wrap DEC", u_top.u_fsm.digits[3] == 4'd9);
        check("HEX3 exibe 9",                HEX3 == seg7(9));

        // ------------------------------------------------------------
        // TESTE 5: Wrap-around INC 9 -> 0
        // ------------------------------------------------------------
        $display("\n[Teste 5] Wrap-around INC: 9 -> 0");
        press(INC);                       // 9 -> 0 (wrap)
        check("digits[3] = 0 apos wrap INC", u_top.u_fsm.digits[3] == 4'd0);

        // ------------------------------------------------------------
        // TESTE 6: Senha CORRETA (1-2-1-2)
        // ------------------------------------------------------------
        $display("\n[Teste 6] Senha correta: 1-2-1-2");
        do_reset();

        enter_digit(1); press(CONFIRM);   // 1º dígito = 1
        check("digits[3] = 1", u_top.u_fsm.digits[3] == 4'd1);
        check("active_reg = 2 / HEX4 = 2", u_top.u_fsm.active_reg == 2'd2 && HEX4 == seg7(2));

        enter_digit(2); press(CONFIRM);   // 2º dígito = 2
        check("digits[2] = 2", u_top.u_fsm.digits[2] == 4'd2);

        enter_digit(1); press(CONFIRM);   // 3º dígito = 1
        check("digits[1] = 1", u_top.u_fsm.digits[1] == 4'd1);

        enter_digit(2); press(CONFIRM);   // 4º dígito = 2 -> CHECK -> SUCCESS
        check("digits[0] = 2", u_top.u_fsm.digits[0] == 4'd2);
        check("LEDs VERDES acesos (cofre aberto)", LEDG == 9'h1FF);
        check("LEDs vermelhos apagados",           LEDR == 18'h00000);

        skip_timer();
        check("Retorno automatico a EDITING (digitos zerados)",
              u_top.u_fsm.digits[0] == 0 && u_top.u_fsm.digits[3] == 0);
        check("Apos retorno: dígito ativo = primeiro",
              u_top.u_fsm.active_reg == 2'd3);

        // ------------------------------------------------------------
        // TESTE 7: Senha ERRADA (0-0-0-0)
        // ------------------------------------------------------------
        $display("\n[Teste 7] Senha errada: 0-0-0-0");
        do_reset();
        press(CONFIRM);                   // avanca sem alterar (todos 0)
        press(CONFIRM);
        press(CONFIRM);
        press(CONFIRM);                   // 4º confirma -> CHECK -> FAIL
        check("LEDs VERMELHOS acesos (senha errada)", LEDR == 18'h3FFFF);
        check("LEDs verdes apagados",                 LEDG == 9'h000);

        skip_timer();
        check("Retorno automatico apos FAIL (digitos zerados)",
              u_top.u_fsm.digits[0] == 0 && u_top.u_fsm.digits[3] == 0);

        // ------------------------------------------------------------
        // TESTE 8: Independencia dos dígitos por posicao
        // ------------------------------------------------------------
        $display("\n[Teste 8] Independencia dos digitos");
        do_reset();
        enter_digit(5);                   // 1º dígito = 5
        check("digits[3] = 5", u_top.u_fsm.digits[3] == 4'd5);
        press(CONFIRM);                   // avanca para o 2º
        check("digits[2] = 0 (nao alterado)", u_top.u_fsm.digits[2] == 4'd0);
        enter_digit(7);                   // 2º dígito = 7
        check("digits[2] = 7", u_top.u_fsm.digits[2] == 4'd7);
        check("digits[3] = 5 (inalterado)", u_top.u_fsm.digits[3] == 4'd5);
        check("digits[1] = 0 (nao alterado)", u_top.u_fsm.digits[1] == 4'd0);

        // ------------------------------------------------------------
        // TESTE 9: Estabilidade sem botao pressionado
        // ------------------------------------------------------------
        $display("\n[Teste 9] Sem botao: estado estavel");
        do_reset();
        repeat(10) @(posedge clk);
        check("Digitos inalterados sem botao",
              u_top.u_fsm.digits[0] == 0 && u_top.u_fsm.digits[3] == 0);
        check("Dígito ativo inalterado (active_reg = 3)",
              u_top.u_fsm.active_reg == 2'd3);
        check("Sem LEDs vermelhos", LEDR == 18'h00000);
        check("Sem LEDs verdes",    LEDG == 9'h000);

        // ------------------------------------------------------------
        // Resultado final
        // ------------------------------------------------------------
        $display("\n================================================");
        $display("   RESULTADO FINAL: %0d / %0d testes passaram",
                 pass_cnt, test_num);
        if (fail_cnt == 0)
            $display("   TODOS OS TESTES PASSARAM!");
        else
            $display("   %0d TESTE(S) FALHARAM!", fail_cnt);
        $display("================================================");

        $stop;
    end

endmodule
