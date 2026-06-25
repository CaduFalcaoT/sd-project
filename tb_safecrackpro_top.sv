module safecrack_tb;
    logic        clk;
    logic [3:0]  key;
    logic [6:0]  HEX0, HEX1, HEX2, HEX3, HEX4;
    logic [7:0]  LEDG;
    logic [17:0] LEDR;

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

    initial clk = 0;
    always #10 clk = ~clk;

    task press_key(input [3:0] k);
        key = ~k;       
        #40;
        key = 4'hF;     
        #40;
    endtask

    initial begin
        key = 4'hF;     
        #100;
        press_key(4'b0001); // KEY[0] = reset
        #200;

        // Dígito 1 (HEX3) -> Espera '1'
        press_key(4'b0100); 
        #100;
        press_key(4'b0010); 
        #200;

        // Dígito 2 (HEX2) -> Espera '2'
        press_key(4'b0100); 
        #100;
        press_key(4'b0100); 
        #100;
        press_key(4'b0010); 
        #200;

        // Dígito 3 (HEX1) -> Espera '1'
        press_key(4'b0100); 
        #100;
        press_key(4'b0010); 
        #200;

        // Dígito 4 (HEX0) -> Espera '2'
        press_key(4'b0100); 
        #100;
        press_key(4'b0100); 
        #100;
        press_key(4'b0010); 
        #200;

        if (LEDG == 8'hFF && LEDR == 18'b0) begin
            $display("SUCESSO: O cofre abriu! LEDG = %b", LEDG);
        end else begin
            $display("ERRO: O cofre continuou fechado. LEDG = %b, LEDR = %b", LEDG, LEDR);
        end
        
        $stop;
    end
endmodule