`define sil   32'd50000000

`define c3  32'd131
`define d3  32'd147
`define e3  32'd165
`define f3  32'd175
`define g3  32'd196
`define a3  32'd220
`define b3  32'd247

`define c4  32'd262   
`define d4  32'd294
`define e4  32'd330 
`define f4  32'd349
`define g4  32'd392
`define a4  32'd440
`define b4  32'd494

`define c5  32'd524
`define d5  32'd588
`define e5  32'd660
`define f5  32'd698
`define g5  32'd784
`define a5  32'd880
`define b5  32'd988

module final_project_top (
    input wire clk,
    input wire rst,
    input wire [15:0] sw, 
    inout wire PS2_CLK,
    inout wire PS2_DATA,
    output wire [3:0] vgaRed,
    output wire [3:0] vgaGreen,
    output wire [3:0] vgaBlue,
    output wire hsync,
    output wire vsync,
    output wire [15:0] led, 
    output wire [3:0] digit, 
    output wire [6:0] display, 
    output wire audio_mclk, // master clock
    output wire audio_lrck, // left-right clock
    output wire audio_sck,  // serial clock
    output wire audio_sdin // serial audio data input
); 

    wire clk_25MHz, clk_22;
    wire clk26; 
    wire valid;
    wire [9:0] h_cnt; //640
    wire [9:0] v_cnt;  //480
    wire [0:95] bg, monster_bg; 
    wire [0:7] bg_top, monster_top; 
    wire [15:0] pos_x, pos_y, jump_y, base_y; 
    wire falling; 
    wire [0:199] speed_mem; 
    reg [3:0] move; 
    reg [15:0] nums; 
    reg [3:0] clk_counter; 

    wire [15:0] audio_in_left, audio_in_right;
    wire [31:0] freqL, freqR;          
    wire [21:0] freq_outL, freq_outR; 
    wire clkDiv22;
    wire [3:0] sound;

    reg [3:0] state, next_state; 
    wire [511:0] key_down; 
    wire [8:0] last_change; 
    wire key_valid; 
    reg win; 

    wire [0:119] offsets; 
    wire [0:9] offsets_top; 

    parameter Init = 0; 
    parameter Play = 1; 
    parameter Finish = 2; 

    parameter SPACE_CODE = 9'b0_0010_1001; // 29 
    parameter LEFT_CODE =  9'b0_0110_1001; // 69 => 1 
    parameter RIGHT_CODE = 9'b0_0111_1010; // 7A => 3 
    // use num key 1/3 for left/right  

    parameter move_left = 1; 
    parameter move_right = 2; 

    KeyboardDecoder kd2 (.rst(rst), .clk(clk), .PS2_DATA(PS2_DATA), .PS2_CLK(PS2_CLK), .key_down(key_down), .last_change(last_change), .key_valid(key_valid)); 

    clock_divider #(.n(26)) (.clk(clk), .clk_div(clk26));

    always @(posedge clk) begin
        if (rst) state <= Init; 
        else begin 
            case (state)
                Init: begin 
                    if (key_valid && key_down[last_change] && last_change == SPACE_CODE) state <= Play; 
                    win <= 0; 
                end 
                Play: begin 
                    if (pos_y >= 479) state <= Finish;
                    else if (pos_y <= 60) begin 
                        state <= Finish; 
                        win <= 1; 
                    end else state <= Play; 
                end 
                Finish: begin 
                    if (clk_counter >= 4) state <= Init; 
                    else state <= Finish; 
                end 
            endcase
        end 
    end

    always @(negedge clk) begin 
        case (state)
            Init: begin 
                move <= 0; 
            end 
            Play: begin 
                if (key_valid && last_change == LEFT_CODE && key_down[LEFT_CODE] == 1'b1) begin 
                    move <= move_left; 
                end else if (key_valid && last_change == RIGHT_CODE && key_down[RIGHT_CODE] == 1'b1) begin 
                    move <= move_right; 
                end else if (key_valid && last_change == LEFT_CODE && key_down[LEFT_CODE] == 1'b0) begin 
                    move <= 0; 
                end else if (key_valid && last_change == RIGHT_CODE && key_down[RIGHT_CODE] == 1'b0) begin 
                    move <= 0; 
                end 
            end 
            Finish: begin 
                move <= 0; 
            end 
        endcase
    end 

    always @(*) begin 
        case (state)
            Init: begin 
                nums = 16'haaaa; 
            end 
            Play: begin 
                nums[3:0]  = base_y % 10; 
                nums[7:4] = (base_y / 10) % 10; 
                nums[11:8] = (base_y / 100) % 10; 
                nums[15:12] = (base_y / 1000) % 10; 
            end 
            Finish: begin 
                if (win) nums =  16'habcd; 
                else nums = 16'he05f; 
            end 
        endcase
    end 

    clk_wiz clk_wiz_0_inst(
      .clk(clk),
      .clk1(clk_25MHz),
      .clk22(clk_22)
    );

    pixel_gen pixel_gen_inst(
       .h_cnt(h_cnt),
       .v_cnt(v_cnt), 
       .state(state),
       .bg(bg), 
       .monster_bg(monster_bg), 
       .bg_top(bg_top), 
       .monster_top(monster_top), 
       .pos_x(pos_x), 
       .pos_y(pos_y), 
       .base_y(base_y),
       .falling(falling), 
       .offsets(offsets), 
       .offsets_top(offsets_top), 
       .vgaRed(vgaRed),
       .vgaGreen(vgaGreen),
       .vgaBlue(vgaBlue)
    );

    vga_controller   vga_inst(
      .pclk(clk_25MHz),
      .reset(rst),
      .hsync(hsync),
      .vsync(vsync),
      .valid(valid),
      .h_cnt(h_cnt),
      .v_cnt(v_cnt)
    );

    always @(posedge clk26) begin 
        case (state)
            Init: clk_counter <= 0; 
            Play: clk_counter <= 0; 
            Finish: clk_counter <= clk_counter + 1'b1; 
        endcase
    end 

    bg_gen bg_ben0 (.clk(clk), .rst(rst), .base_y(base_y), .bg(bg), .bg_top(bg_top)); 
    monster_gen monster_gen0 (.clk(clk), .rst(rst), .base_y(base_y), .monster_bg(monster_bg), .monster_top(monster_top)); 
    char_gen char_gen0 (.clk(clk), .rst(rst), .state(state), .move(move), .pos_x(pos_x), .pos_y(pos_y), .base_y(base_y), .bg(bg), .monster_bg(monster_bg), .falling(falling), .save(sw[0]), .speed_mem(speed_mem), .sound(sound), .offsets(offsets), .offsets_top(offsets_top)); 
    speed_gen speed_gen0 (.mem(speed_mem)); 
    sound_gen sound_gen0 (.clk(clk), .rst(rst), .sound(sound), .freqL(freqL), .freqR(freqR)); 
    offset_gen offset_gen0 (.clk(clk), .rst(rst), .base_y(base_y), .offsets(offsets), .offsets_top(offsets_top)); 

    SevenSegment ss (.display(display), .digit(digit), .nums(nums), .rst(rst), .clk(clk)); 


    
    clock_divider #(.n(22)) clock_22(.clk(clk), .clk_div(clkDiv22));  
    assign freq_outL = 50000000 / freqL;  
    assign freq_outR = 50000000 / freqR;  

    note_gen noteGen_00(
        .clk(clk), 
        .rst(rst), 
        .volume(3'b000),
        .note_div_left(freq_outL),  
        .note_div_right(freq_outR), 
        .audio_left(audio_in_left),    
        .audio_right(audio_in_right)   
    );

    speaker_control sc(
        .clk(clk), 
        .rst(rst), 
        .audio_in_left(audio_in_left),     
        .audio_in_right(audio_in_right),   
        .audio_mclk(audio_mclk),           
        .audio_lrck(audio_lrck),           
        .audio_sck(audio_sck),             
        .audio_sdin(audio_sdin)            
    );

endmodule


module monster_gen (
    input wire clk, 
    input wire rst, 
    input [15:0] base_y, 
    output wire [0:95] monster_bg, 
    output wire [0:7] monster_top 
); 

    parameter max_row = 95; 
    reg [7:0] mem [0:max_row]; 
    wire [15:0] start_i; 

    // each block is 40*40, 8 blocks in a row, 12 rows in the screen, max_row rows in total, 8*max_row blocks in total 
    // if monster_bg[i] is 1, there is a monster at block i

    always @(*) begin 
        mem[95] = 8'b0000_0000; 
        mem[94] = 8'b0000_0000; 
        mem[93] = 8'b0001_0000; 
        mem[92] = 8'b0000_0000; 
        mem[91] = 8'b0000_0000; 
        mem[90] = 8'b0000_0000; 
        mem[89] = 8'b0000_0100; 
        mem[88] = 8'b0000_0000; 
        mem[87] = 8'b0000_0000; 
        mem[86] = 8'b0000_0000; 
        mem[85] = 8'b0010_0000; 
        mem[84] = 8'b0000_0000;  

        mem[83] = 8'b0000_0000; 
        mem[82] = 8'b0000_0000; 
        mem[81] = 8'b0000_0000; 
        mem[80] = 8'b0000_0000; 
        mem[79] = 8'b0000_0000; 
        mem[78] = 8'b0100_0000; 
        mem[77] = 8'b0000_0000; 
        mem[76] = 8'b0000_0000; 
        mem[75] = 8'b0000_0000; 
        mem[74] = 8'b0000_0000; 
        mem[73] = 8'b0000_0000; 
        mem[72] = 8'b0000_0000;  

        mem[71] = 8'b0000_0000; 
        mem[70] = 8'b0000_0000; 
        mem[69] = 8'b0000_0000; 
        mem[68] = 8'b0000_0000; 
        mem[67] = 8'b0000_0000; 
        mem[66] = 8'b0000_0000; 
        mem[65] = 8'b0000_0000; 
        mem[64] = 8'b0000_0000; 
        mem[63] = 8'b0000_1000; 
        mem[62] = 8'b0000_0000; 
        mem[61] = 8'b0000_0000; 
        mem[60] = 8'b0000_0000;  

        mem[59] = 8'b0000_0000; 
        mem[58] = 8'b0000_0000; 
        mem[57] = 8'b0000_0000; 
        mem[56] = 8'b0000_0000; 
        mem[55] = 8'b0000_0000; 
        mem[54] = 8'b0000_0000; 
        mem[53] = 8'b0000_0000; 
        mem[52] = 8'b0000_0000; 
        mem[51] = 8'b0000_0000; 
        mem[50] = 8'b0000_0000; 
        mem[49] = 8'b0000_0000; 
        mem[48] = 8'b0000_0000;  

        mem[47] = 8'b0000_0000; 
        mem[46] = 8'b0000_0000; 
        mem[45] = 8'b0000_0000; 
        mem[44] = 8'b0000_0000; 
        mem[43] = 8'b0000_0000; 
        mem[42] = 8'b0000_0000; 
        mem[41] = 8'b0000_0000; 
        mem[40] = 8'b0000_0000; 
        mem[39] = 8'b0000_0000; 
        mem[38] = 8'b0000_0000; 
        mem[37] = 8'b0000_0000; 
        mem[36] = 8'b0000_0000;  

        mem[35] = 8'b0000_0000; 
        mem[34] = 8'b0001_0000; 
        mem[33] = 8'b0000_0000; 
        mem[32] = 8'b0000_0000; 
        mem[31] = 8'b0000_0000; 
        mem[30] = 8'b0000_0000; 
        mem[29] = 8'b0000_0000; 
        mem[28] = 8'b0000_0000; 
        mem[27] = 8'b0000_0000; 
        mem[26] = 8'b0000_0000; 
        mem[25] = 8'b0000_0000; 
        mem[24] = 8'b0000_0000;  

        mem[23] = 8'b0000_0000; 
        mem[22] = 8'b0000_0000; 
        mem[21] = 8'b0000_0000; 
        mem[20] = 8'b0000_0000; 
        mem[19] = 8'b0000_0000; 
        mem[18] = 8'b0000_0000; 
        mem[17] = 8'b0000_0000; 
        mem[16] = 8'b0000_0000; 
        mem[15] = 8'b0000_0000; 
        mem[14] = 8'b0000_0000; 
        mem[13] = 8'b0000_0000; 
        mem[12] = 8'b0000_0000;  

        mem[11] = 8'b0000_0000; 
        mem[10] = 8'b0000_0000; 
        mem[9] =  8'b0000_0000; 
        mem[8] =  8'b0000_0000; 
        mem[7] =  8'b0000_0000; 
        mem[6] =  8'b0000_0000; 
        mem[5] =  8'b0000_0000; 
        mem[4] =  8'b0000_0000; 
        mem[3] =  8'b0000_0000; 
        mem[2] =  8'b0000_0000; 
        mem[1] =  8'b0000_0000; 
        mem[0] =  8'b0000_0000; 
    end 

    assign start_i = (base_y / 40 <= max_row - 11) ? (base_y / 40) : max_row - 11; 

    assign monster_bg = {
        mem[start_i + 11], 
        mem[start_i + 10], 
        mem[start_i + 9], 
        mem[start_i + 8], 
        mem[start_i + 7], 
        mem[start_i + 6], 
        mem[start_i + 5], 
        mem[start_i + 4], 
        mem[start_i + 3], 
        mem[start_i + 2], 
        mem[start_i + 1], 
        mem[start_i + 0]
    }; 

    assign monster_top = (start_i + 12 <= max_row) ? mem[start_i + 12] : mem[max_row]; 

endmodule

module offset_gen (
    input wire clk, 
    input wire rst, 
    input [15:0] base_y, 
    output wire [0:119] offsets, 
    output wire [0:9] offsets_top 
); 

    parameter max_row = 95; 

    wire [15:0] start_i; 
    wire clk18; 
    integer i;
    reg [9:0] mem [0:95]; 

    clock_divider #(.n(21)) (.clk(clk), .clk_div(clk18)); 

    always @(posedge clk18) begin
        if (rst) begin
            mem[95] <= 0;
            mem[94] <= 25; 
            mem[93] <= 0; 
            mem[92] <= 0; 
            mem[91] <= 77; 
            mem[90] <= 34;
            mem[89] <= 0;
            mem[88] <= 70;
            mem[87] <= 0;
            mem[86] <= 79;
            mem[85] <= 0;
            mem[84] <= 0; 

            mem[83] <= 46;
            mem[82] <= 0; 
            mem[81] <= 90; 
            mem[80] <= 0; 
            mem[79] <= 53; 
            mem[78] <= 0;
            mem[77] <= 10;
            mem[76] <= 0;
            mem[75] <= 15;
            mem[74] <= 0;
            mem[73] <= 0;
            mem[72] <= 0; 

            mem[71] <= 20;
            mem[70] <= 0; 
            mem[69] <= 6; 
            mem[68] <= 0; 
            mem[67] <= 0; 
            mem[66] <= 77;
            mem[65] <= 0;
            mem[64] <= 0;
            mem[63] <= 0;
            mem[62] <= 0;
            mem[61] <= 100;
            mem[60] <= 0; 

            mem[59] <= 0;
            mem[58] <= 0; 
            mem[57] <= 0; 
            mem[56] <= 4; 
            mem[55] <= 0; 
            mem[54] <= 0;
            mem[53] <= 0;
            mem[52] <= 90;
            mem[51] <= 0;
            mem[50] <= 0;
            mem[49] <= 0;
            mem[48] <= 0; 

            mem[47] <= 0;
            mem[46] <= 0; 
            mem[45] <= 51; 
            mem[44] <= 0; 
            mem[43] <= 0; 
            mem[42] <= 0;
            mem[41] <= 90;
            mem[40] <= 0;
            mem[39] <= 0;
            mem[38] <= 0;
            mem[37] <= 0;
            mem[36] <= 0; 

            mem[35] <= 75;
            mem[34] <= 0; 
            mem[33] <= 0; 
            mem[32] <= 0; 
            mem[31] <= 0; 
            mem[30] <= 56;
            mem[29] <= 0;
            mem[28] <= 0;
            mem[27] <= 0;
            mem[26] <= 89;
            mem[25] <= 0;
            mem[24] <= 0; 

            mem[23] <= 0;
            mem[22] <= 0; 
            mem[21] <= 123; 
            mem[20] <= 0; 
            mem[19] <= 0; 
            mem[18] <= 0;
            mem[17] <= 44;
            mem[16] <= 0;
            mem[15] <= 0;
            mem[14] <= 50;
            mem[13] <= 0;
            mem[12] <= 0; 

            mem[11] <= 0;
            mem[10] <= 0; 
            mem[9]  <= 220; 
            mem[8]  <= 0; 
            mem[7]  <= 0; 
            mem[6]  <= 0;
            mem[5]  <= 0;
            mem[4]  <= 0;
            mem[3]  <= 0;
            mem[2]  <= 0;
            mem[1]  <= 0;
            mem[0]  <= 0; 
        end else begin 
            for (i=0; i <= 95; i=i+1) begin 
                if (mem[i] != 0) begin 
                    if (mem[i][0] == 1'b1) begin
                        mem[i] <= (mem[i] >= 159) ? 158 : mem[i] + 2; 
                    end else begin 
                        mem[i] <= (mem[i] <= 2) ? 1 : mem[i] - 2;
                    end 
                end 
            end 
        end 
    end

    assign offsets = {
        mem[start_i + 11], 
        mem[start_i + 10], 
        mem[start_i + 9], 
        mem[start_i + 8], 
        mem[start_i + 7], 
        mem[start_i + 6], 
        mem[start_i + 5], 
        mem[start_i + 4], 
        mem[start_i + 3], 
        mem[start_i + 2], 
        mem[start_i + 1], 
        mem[start_i + 0]
    }; 

    assign start_i = (base_y / 40 <= max_row - 11) ? (base_y / 40) : max_row - 11; 
    assign offsets_top = (start_i + 12 <= max_row) ? mem[start_i + 12] : mem[max_row]; 

endmodule


module bg_gen (
    input wire clk, 
    input wire rst, 
    input [15:0] base_y, 
    output wire [0:95] bg, 
    output wire [0:7] bg_top 
); 

    parameter max_row = 95; 
    reg [7:0] mem [0:max_row]; 
    wire [15:0] start_i; 

    // each block is 40*40, 8 blocks in a row, 12 rows in the screen, max_row rows in total, 8*max_row blocks in total 
    // if bg[i] is 1, there is a platform at the bottom of block i

    always @(*) begin 
        mem[95] = 8'b0000_0000; 
        mem[94] = 8'b0000_0000; 
        mem[93] = 8'b0000_0000; 
        mem[92] = 8'b0000_0000; 
        mem[91] = 8'b0000_0000; 
        mem[90] = 8'b0000_0000; 
        mem[89] = 8'b0000_0000; 
        mem[88] = 8'b0000_0000; 
        mem[87] = 8'b0000_0000; 
        mem[86] = 8'b0000_0000; 
        mem[85] = 8'b0000_0000; 
        mem[84] = 8'b0000_0000;  

        mem[83] = 8'b0000_0000; 
        mem[82] = 8'b0001_0000; 
        mem[81] = 8'b0000_0000; 
        mem[80] = 8'b0000_0000; 
        mem[79] = 8'b0000_0000; 
        mem[78] = 8'b0000_0000; 
        mem[77] = 8'b0000_0000; 
        mem[76] = 8'b0000_0010; 
        mem[75] = 8'b0000_0000; 
        mem[74] = 8'b0000_0000; 
        mem[73] = 8'b0001_0010; 
        mem[72] = 8'b0000_0000;  

        mem[71] = 8'b0000_0001; 
        mem[70] = 8'b0010_0000; 
        mem[69] = 8'b0000_0000; 
        mem[68] = 8'b0000_0000; 
        mem[67] = 8'b0100_0010; 
        mem[66] = 8'b0000_0000; 
        mem[65] = 8'b0000_0000; 
        mem[64] = 8'b0010_0100; 
        mem[63] = 8'b0000_0000; 
        mem[62] = 8'b0000_0000; 
        mem[61] = 8'b0000_0000; 
        mem[60] = 8'b0010_0000;  

        mem[59] = 8'b0000_1000; 
        mem[58] = 8'b0001_0000; 
        mem[57] = 8'b0000_0000; 
        mem[56] = 8'b0000_0000; 
        mem[55] = 8'b0000_0000; 
        mem[54] = 8'b0010_0000; 
        mem[53] = 8'b0000_0000; 
        mem[52] = 8'b0000_0000; 
        mem[51] = 8'b0000_0000; 
        mem[50] = 8'b0100_0010; 
        mem[49] = 8'b0001_0000; 
        mem[48] = 8'b0000_0000;  

        mem[47] = 8'b0010_0001; 
        mem[46] = 8'b0000_0010; 
        mem[45] = 8'b0000_0000; 
        mem[44] = 8'b0000_0000; 
        mem[43] = 8'b0000_1000; 
        mem[42] = 8'b0000_0000; 
        mem[41] = 8'b0000_0000; 
        mem[40] = 8'b0010_0000; 
        mem[39] = 8'b0000_0000; 
        mem[38] = 8'b0100_0010; 
        mem[37] = 8'b1000_0000; 
        mem[36] = 8'b0000_0000;  

        mem[35] = 8'b0000_0000; 
        mem[34] = 8'b0000_0000; 
        mem[33] = 8'b0100_0000; 
        mem[32] = 8'b0000_0000; 
        mem[31] = 8'b0001_0000; 
        mem[30] = 8'b0000_0000; 
        mem[29] = 8'b0000_0001; 
        mem[28] = 8'b1000_0000; 
        mem[27] = 8'b0000_0000; 
        mem[26] = 8'b0000_0000; 
        mem[25] = 8'b0000_0000; 
        mem[24] = 8'b0000_0010;  

        mem[23] = 8'b0100_0000; 
        mem[22] = 8'b0000_0000; 
        mem[21] = 8'b0000_0000; 
        mem[20] = 8'b0001_0000; 
        mem[19] = 8'b1000_0000; 
        mem[18] = 8'b0000_0000; 
        mem[17] = 8'b0000_0000; 
        mem[16] = 8'b1000_0000; 
        mem[15] = 8'b0001_0000; 
        mem[14] = 8'b0000_0000; 
        mem[13] = 8'b0000_1000; 
        mem[12] = 8'b0010_0000;  

        mem[11] = 8'b0000_0001; 
        mem[10] = 8'b0000_0010; 
        mem[9] =  8'b0000_0000; 
        mem[8] =  8'b0000_1000; 
        mem[7] =  8'b0001_0000; 
        mem[6] =  8'b0000_0000; 
        mem[5] =  8'b0100_0000; 
        mem[4] =  8'b1000_0000; 
        mem[3] =  8'b0000_1000; 
        mem[2] =  8'b0000_0010; 
        mem[1] =  8'b0100_0000; 
        mem[0] =  8'b0000_0000; 
    end 

    assign start_i = (base_y / 40 <= max_row - 11) ? (base_y / 40) : max_row - 11; 

    assign bg = {
        mem[start_i + 11], 
        mem[start_i + 10], 
        mem[start_i + 9], 
        mem[start_i + 8], 
        mem[start_i + 7], 
        mem[start_i + 6], 
        mem[start_i + 5], 
        mem[start_i + 4], 
        mem[start_i + 3], 
        mem[start_i + 2], 
        mem[start_i + 1], 
        mem[start_i + 0]
    }; 

    assign bg_top = (start_i + 12 <= max_row) ? mem[start_i + 12] : mem[max_row]; 

endmodule

module sound_gen (
    input clk, 
    input rst, 
    input [3:0] sound, 
    output reg [31:0] freqL, 
    output reg [31:0] freqR 
); 
    reg [3:0] state; 
    reg [7:0] clk_counter; 
    reg play;
    wire [31:0] bgmL, bgmR;
    wire [11:0] ibeatNum;
    wire clk18, clk_32hz; 

    parameter none = 0; 
    parameter bounce = 1; 
    parameter hit = 2; 
    parameter victory = 3; 
    parameter background = 4; 

    clock_divider #(.n(18)) (.clk(clk), .clk_div(clk18)); 

    clock_32_hz clock_32_hz_0_inst(
      .clk(clk),
      .rst(rst),
      .clk_32hz(clk_32hz)
    );

    music_control #(.LEN(320)) musicCtrl_00 ( 
        .clk(clk_32hz),
        .rst(rst),
        .play(play), 
        .ibeat(ibeatNum)
    );

    music_example music_00 (
        .ibeatNum(ibeatNum),
        .en(1'b1),
        .toneL(bgmL),
        .toneR(bgmR)
    );

    always @(negedge clk18) begin 
        if (rst) begin 
            clk_counter <= 0; 
            play <= 0;
            state <= none; 
        end else begin 
            play <= 1;
            case (state) 
                none: begin 
                    state <= sound; 
                    clk_counter <= 0; 
                    play <= 0;
                end 
                background: begin 
                    state <= sound; 
                    clk_counter <= 0; 
                end
                bounce: begin 
                    if (clk_counter >= 25) begin 
                        state <= background; 
                        clk_counter <= 0; 
                    end else begin 
                        state <= bounce; 
                        clk_counter <= (clk_counter == 8'hff) ? 0 : clk_counter + 1'b1; 
                    end 
                end 
                hit: begin
                    if (clk_counter >= 140) begin 
                        state <= background; 
                        clk_counter <= 0; 
                    end else begin 
                        state <= hit; 
                        clk_counter <= (clk_counter == 8'hff) ? 0 : clk_counter + 1'b1; 
                    end 
                end 
                victory: begin 
                    if (clk_counter >= 140) begin 
                        state <= background; 
                        clk_counter <= 0; 
                    end else begin 
                        state <= victory; 
                        clk_counter <= (clk_counter == 8'hff) ? 0 : clk_counter + 1'b1; 
                    end 
                end 
            endcase
        end 
    end 

    always @(*) begin
        freqL = bgmL; freqR <= bgmR; 
        case (state) 
            none: begin 
                freqL = `sil; freqR <= `sil; 
            end 
            bounce: begin 
                if (clk_counter > 10 && clk_counter <= 20) begin 
                    freqR <= `a5; 
                end else begin 
                    freqR <= `e5; 
                end 
            end 
            hit: begin
                if (clk_counter < 20) begin 
                    freqR <= `b4; 
                end else if (clk_counter < 40) begin 
                    freqR <= `a4; 
                end else if (clk_counter < 60) begin 
                    freqR <= `g4;  
                end else if (clk_counter < 80) begin 
                    freqR <= `f4;  
                end else if (clk_counter < 100) begin 
                    freqR <= `e4; 
                end else if (clk_counter < 120) begin 
                    freqR <= `d4; 
                end else if (clk_counter < 140) begin 
                    freqR <= `c4; 
                end else begin 
                    freqR <= `sil; 
                end 
            end 
            victory: begin 
                if (clk_counter < 50) begin 
                    freqL <= `e5; freqR <= `e5;  
                end else if (clk_counter < 140) begin 
                    freqL <= `a5; freqR <= `a5; 
                end else begin 
                    freqL <= `sil; freqR <= `sil; 
                end 
            end 
        endcase
    end

endmodule

module char_gen (
    input wire clk, 
    input wire rst, 
    input [3:0] state, 
    input [3:0] move, 
    input [0:95] bg, 
    input [0:95] monster_bg, 
    input [0:199] speed_mem, 
    input save, 
    input [0:119] offsets, 
    input [0:9] offsets_top,
    output reg [15:0] pos_x, 
    output reg [15:0] pos_y, 
    output reg [15:0] base_y, 
    output reg falling, 
    output reg [3:0] sound
); 
    wire clk24, clk18; 
    reg dir; 
    reg [7:0] position_l, position_r, position_lt, position_rt; 
    reg [7:0] clk_counter, clk_counter2; 
    wire [511:0] key_down; 
    wire [8:0] last_change; 
    wire key_valid; 
    reg [15:0] char_y, next_base_y; 

    wire [9:0] offset, offset_start; 

    parameter Init = 0; 
    parameter Play = 1; 
    parameter Finish = 2;

    parameter up = 1; 
    parameter down = 0; 

    parameter move_left = 1; 
    parameter move_right = 2; 

    parameter jump_clk_counter = 200; 
    parameter max_row = 95; 

    parameter char_w = 30; 
    parameter char_h = 60; 

    parameter none = 0; 
    parameter bounce = 1; 
    parameter hit = 2; 
    parameter victory = 3;  
    parameter background = 4; 

    clock_divider #(.n(18)) (.clk(clk), .clk_div(clk24)); 
    clock_divider #(.n(17)) (.clk(clk), .clk_div(clk18)); 

    always @(posedge clk24) begin
        case (state)
            Init: pos_x <= 330; 
            Play: begin  
                if (move == move_left) begin 
                    pos_x <= (pos_x > 160) ? pos_x - 1'b1 : 449;   
                end else if (move == move_right) begin 
                    pos_x <= (pos_x < 449) ? pos_x + 1'b1 : 160;
                end 
            end 
            Finish: pos_x <= 330; 
        endcase
    end

    always @(posedge clk18) begin 
        case (state) 
            Init: base_y <= 0; 
            Play: begin 
                if (base_y < next_base_y) base_y <= base_y + 1'b1; 
            end 
            Finish: base_y <= 0; 
        endcase
    end 

    // pos_x ([160,479], 160 for left), pos_y ([0,479], 0 for top) for VGA
    // char_y for actual position on y axis (0 for bottom)
    // base_y for position of the bottom of the screen on y axis
    always @(posedge clk24) begin 
        case (state)
            Init: begin 
                char_y <= 130; 
                dir <= up; 
                clk_counter <= 0; 
                // clk_counter2 <= 0; 
                next_base_y <= 0; 
                falling <= 0; 
                sound <= none;  
            end 
            Play: begin 
                if (dir == up) begin 
                    if (clk_counter >= jump_clk_counter) begin 
                        // start dropping 
                        char_y <= char_y - 1'b1; 
                        dir <= down; 
                        clk_counter <= clk_counter - 1'b1; 
                        sound <= background; 
                    end else if (!save && (monster_bg[position_lt] || monster_bg[position_rt])) begin 
                        // bump into monster, start falling
                        char_y <= char_y - 1'b1; 
                        dir <= down; 
                        clk_counter <= clk_counter - 1'b1; 
                        falling <= 1; 
                        sound <= hit; 
                    end else begin 
                        // bouncing 
                        clk_counter <= clk_counter + 1'b1; 
                        if (speed_mem[clk_counter] == 1'b1) char_y <= char_y + 1'b1;  // speed control 
                        if (pos_y <= 61) sound <= victory; 
                        else sound <= background; 
                    end 
                end else begin // dir == down 
                    if (falling) begin 
                        // falling (have hit monster)
                        clk_counter <= (clk_counter == 0) ? 0 : clk_counter - 1'b1; 
                        if (speed_mem[clk_counter] == 1'b1) char_y <= char_y - 1'b1;  
                        sound <= background; 
                    end else if ((monster_bg[position_l] || monster_bg[position_r])) begin 
                        // landed on monster, start bouncing
                        char_y <= char_y + 1'b1; 
                        dir <= up; 
                        clk_counter <= 0; 
                        if (char_y >= 130 && (char_y / 40 - 3) * 40 >= base_y) begin // show three lower platforms 
                            if ((char_y / 40 - 3) * 40 >= (max_row - 11) * 40) next_base_y <= (max_row - 11) * 40; 
                            else next_base_y <= (char_y / 40 - 3) * 40; 
                        end 
                        sound <= bounce; 
                    end else if (save && (position_l >= 88 || position_r >= 88) && (pos_y - base_y % 40) % 40 <= 39 && (pos_y - base_y % 40) % 40 >= 29) begin 
                        // sw[0] is on, landed on the bottom of the screen, start bouncing
                        char_y <= char_y + 1'b1; 
                        dir <= up; 
                        clk_counter <= 0; 
                        if (char_y >= 130 && (char_y / 40 - 3) * 40 >= base_y) begin // show three lower platforms 
                            if ((char_y / 40 - 3) * 40 >= (max_row - 11) * 40) next_base_y <= (max_row - 11) * 40; 
                            else next_base_y <= (char_y / 40 - 3) * 40; 
                        end 
                        sound <= bounce; 
                    end else if (offset == 0 && (bg[position_l] || bg[position_r]) && (pos_y - base_y % 40) % 40 <= 39 && (pos_y - base_y % 40) % 40 >= 29) begin 
                        // landed on platform, start bouncing 
                        char_y <= char_y + 1'b1; 
                        dir <= up; 
                        clk_counter <= 0; 
                        if (char_y >= 130 && (char_y / 40 - 3) * 40 >= base_y) begin // show three lower platforms 
                            if ((char_y / 40 - 3) * 40 >= (max_row - 11) * 40) next_base_y <= (max_row - 11) * 40; 
                            else next_base_y <= (char_y / 40 - 3) * 40; 
                        end 
                        sound <= bounce;
                    end else if (offset != 0 && ((offset <= pos_x - 160 && pos_x - 160 < offset + 40) || (offset <= pos_x - 160 + char_w && pos_x - 160 + char_w < offset + 40)) && (pos_y - base_y % 40) % 40 <= 39 && (pos_y - base_y % 40) % 40 >= 29) begin 
                        // landed on moving platform, start bouncing 
                        char_y <= char_y + 1'b1; 
                        dir <= up; 
                        clk_counter <= 0; 
                        if (char_y >= 130 && (char_y / 40 - 3) * 40 >= base_y) begin // show three lower platforms 
                            if ((char_y / 40 - 3) * 40 >= (max_row - 11) * 40) next_base_y <= (max_row - 11) * 40; 
                            else next_base_y <= (char_y / 40 - 3) * 40; 
                        end 
                        sound <= bounce; 
                    end else begin 
                        // dropping (have not hit monster)
                        clk_counter <= (clk_counter == 0) ? 0 : clk_counter - 1'b1; 
                        if (speed_mem[clk_counter] == 1'b1) char_y <= char_y - 1'b1; 
                        if (pos_y >= 478) sound <= hit; 
                        else sound <= background; 
                    end 
                end 
            end 
            Finish: begin 
                char_y <= 130; 
                dir <= up; 
                clk_counter <= 0; 
                next_base_y <= 0; 
                falling <= 0; 
                sound <= none; 
            end 
        endcase
    end 
    
    // position_l/r for left/right bottom corner of char
    // position_lt/rt for left/right top corner 
    always @(*) begin
        position_l = (pos_x - 160) / 40 + ((pos_y - base_y % 40) / 40) * 8; 
        position_r = ((pos_x - 160 + char_w) % 320) / 40 + ((pos_y - base_y % 40) / 40) * 8; 
        position_lt = (pos_x - 160) / 40 + (((pos_y - base_y % 40)-char_h) / 40) * 8; 
        position_rt = ((pos_x - 160 + char_w) % 320) / 40 + (((pos_y - base_y % 40)-char_h) / 40) * 8; 
    end

    always @(*) begin 
        pos_y = 479 - char_y + base_y; 
    end 

    assign offset_start = (pos_y < base_y % 40) ? 120 : (pos_y - (base_y % 40)) / 40 * 10; 
    assign offset = (offset_start >= 120) ? offsets_top : {offsets[offset_start], offsets[offset_start + 1], offsets[offset_start + 2], offsets[offset_start + 3], offsets[offset_start + 4], offsets[offset_start + 5], offsets[offset_start + 6], offsets[offset_start + 7], offsets[offset_start + 8], offsets[offset_start + 9], offsets[offset_start + 10]};  

endmodule 


module pixel_gen(
   input [9:0] h_cnt,
   input [9:0] v_cnt,
   input [3:0] state,
   input [0:95] bg, 
   input [0:95] monster_bg, 
   input [0:7] bg_top, 
   input [0:7] monster_top, 
   input [15:0] pos_x, 
   input [15:0] pos_y, 
   input [15:0] base_y, 
   input [0:119] offsets, 
   input [0:9] offsets_top, 
   input falling, 
   output reg [3:0] vgaRed,
   output reg [3:0] vgaGreen,
   output reg [3:0] vgaBlue
);
    
    reg [15:0] position; 
    wire [15:0] fp1_start, fp2_start, fp3_start; 
    wire [15:0] fp2_start_2; 
    wire [9:0] offset, offset_start; 

    parameter char_w = 30; 
    parameter char_h = 60; 

    parameter Init = 0; 
    parameter Play = 1; 
    parameter Finish = 2; 

    parameter [11:0] fp1 [0:1799] = {12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hEEE, 12'hCCD, 12'hDDD, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFE, 12'hDDD, 12'hAAA, 12'h888, 12'h888, 12'hCCC, 12'hFFE, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hBBB, 12'h554, 12'h110, 12'h110, 12'h110, 12'h443, 12'hBBB, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hBBB, 12'h554, 12'h320, 12'h440, 12'h551, 12'h552, 12'h432, 12'h555, 12'hDDC, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hEEE, 12'h665, 12'h220, 12'h550, 12'h881, 12'h992, 12'h993, 12'h773, 12'h442, 12'h988, 12'hFEE, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hAA9, 12'h110, 12'h661, 12'hBB4, 12'hCC4, 12'hCC3, 12'hCC4, 12'hDD7, 12'hBB7, 12'h331, 12'hCCB, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hEEE, 12'h552, 12'h550, 12'hAA2, 12'hBB3, 12'hCC2, 12'hCD2, 12'hCC3, 12'hDD5, 12'hCC6, 12'h995, 12'h553, 12'hEED, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hBBA, 12'h220, 12'h992, 12'hCC2, 12'hDD3, 12'hDC3, 12'hCC1, 12'hCC1, 12'hCC3, 12'hDD5, 12'hCC6, 12'h652, 12'hAA8, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFE, 12'h553, 12'h450, 12'hBC2, 12'hCC2, 12'hED4, 12'hED4, 12'hCC2, 12'hCC2, 12'hDC3, 12'hCC3, 12'hCC4, 12'hAA4, 12'h653, 12'hFEE, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hDDC, 12'h120, 12'h892, 12'hCC2, 12'hCC2, 12'hDC3, 12'hDD4, 12'hCC2, 12'hCC1, 12'hCC2, 12'hDD3, 12'hCC3, 12'hBC5, 12'h542, 12'hA99, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hA98, 12'h330, 12'hBB3, 12'hBB2, 12'hDD3, 12'hCC3, 12'hCB2, 12'hCC2, 12'hCC1, 12'hCC1, 12'hDD3, 12'hCC3, 12'hDD6, 12'h774, 12'h554, 12'hFFE, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'h664, 12'h660, 12'hCC3, 12'hCC3, 12'hDD3, 12'hDC3, 12'hCC2, 12'hCC2, 12'hDC2, 12'hCC1, 12'hCC2, 12'hCC3, 12'hDD6, 12'hDC9, 12'h220, 12'hDDC, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'h320, 12'hAA2, 12'hCC2, 12'hCD3, 12'hDD4, 12'hDD4, 12'hCC3, 12'hDD4, 12'hCC3, 12'hCC2, 12'hCC1, 12'hCC2, 12'hDC4, 12'hED8, 12'h552, 12'hAA9, 12'hFFE, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hCBB, 12'h330, 12'hAB2, 12'hCC2, 12'hDD4, 12'hDD4, 12'hDD4, 12'hCC3, 12'hDD5, 12'hDD4, 12'hCC2, 12'hCC1, 12'hCC1, 12'hCC2, 12'hDD6, 12'h873, 12'h885, 12'hFFE, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'h877, 12'h440, 12'hBC3, 12'hCC1, 12'hDD4, 12'hDD4, 12'hDD3, 12'hCC2, 12'hDD5, 12'hEE6, 12'hCC2, 12'hCC1, 12'hCC0, 12'hCC0, 12'hCC3, 12'hAA3, 12'h552, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'h321, 12'h662, 12'hBB3, 12'hCD3, 12'hDE5, 12'hCD4, 12'hCC2, 12'hCB1, 12'hCC3, 12'hDD4, 12'hCC2, 12'hCC1, 12'hCC0, 12'hCC0, 12'hCC1, 12'hAB3, 12'h441, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hEDD, 12'h110, 12'h884, 12'hBB4, 12'hDD5, 12'hBB3, 12'hAA2, 12'hCC2, 12'hDC2, 12'hCC2, 12'hDD3, 12'hCC1, 12'hCC1, 12'hCC0, 12'hCC1, 12'hCC1, 12'hBB4, 12'h441, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hBBA, 12'h100, 12'h994, 12'h771, 12'hCC5, 12'h881, 12'h770, 12'hCC3, 12'hDC2, 12'hCC1, 12'hCC1, 12'hBC0, 12'hCC1, 12'hCC1, 12'hCC1, 12'hCC2, 12'hCC5, 12'h441, 12'hEEE, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hCCC, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'h886, 12'h110, 12'hBB5, 12'h210, 12'hBB5, 12'h550, 12'h550, 12'hCC3, 12'hCC2, 12'hDC2, 12'hCC1, 12'hCC1, 12'hCC1, 12'hCC1, 12'hCC1, 12'hCC2, 12'hCC6, 12'h441, 12'hDDC, 12'hFFF, 12'hFFF, 12'hFFF, 12'hDDD, 12'h454, 12'h898, 12'hDDD, 12'hFFF, 12'hFFF, 12'hFFF, 12'hBBA, 12'h330, 12'h550, 12'hCC5, 12'h320, 12'hA94, 12'h770, 12'h760, 12'hCC3, 12'hCC2, 12'hDD2, 12'hCC1, 12'hCC1, 12'hCC1, 12'hDC2, 12'hCC2, 12'hCC2, 12'hCC5, 12'h552, 12'hDDC, 12'hFFF, 12'hFFF, 12'hFFF, 12'hABA, 12'h110, 12'h443, 12'h777, 12'h999, 12'h999, 12'h999, 12'h553, 12'h330, 12'h993, 12'hCD5, 12'h770, 12'hBA3, 12'h991, 12'hAA0, 12'hCC2, 12'hCC2, 12'hDC2, 12'hCC1, 12'hCC1, 12'hCC1, 12'hDC2, 12'hCC3, 12'hCC2, 12'hCC5, 12'h553, 12'hDDC, 12'hFFF, 12'hFFF, 12'hFFF, 12'h787, 12'h110, 12'h110, 12'h000, 12'h221, 12'h321, 12'h330, 12'h220, 12'h670, 12'hCC4, 12'hDE5, 12'hDC4, 12'hCC3, 12'hCC2, 12'hCC2, 12'hDD2, 12'hDC2, 12'hCC1, 12'hCC1, 12'hCC1, 12'hCC2, 12'hDD3, 12'hDC3, 12'hCC2, 12'hCC4, 12'h552, 12'hEDD, 12'hFFF, 12'hFFF, 12'hFFF, 12'h665, 12'h663, 12'h652, 12'h320, 12'h330, 12'h430, 12'h550, 12'h991, 12'hBB3, 12'hDC4, 12'hDD4, 12'hCC2, 12'hCC2, 12'hCC2, 12'hDC2, 12'hDC2, 12'hDC2, 12'hCC1, 12'hCC1, 12'hCC1, 12'hDC3, 12'hED4, 12'hDC4, 12'hCC2, 12'hCC4, 12'h552, 12'hEED, 12'hFFF, 12'hFFF, 12'hFFF, 12'h543, 12'h996, 12'h662, 12'h651, 12'h883, 12'h982, 12'h991, 12'hBB2, 12'hCC2, 12'hDD3, 12'hDD3, 12'hCC1, 12'hDC2, 12'hCC2, 12'hDD2, 12'hCC2, 12'hCC2, 12'hCC1, 12'hCC1, 12'hCC2, 12'hDD3, 12'hED4, 12'hDC3, 12'hCC1, 12'hCC4, 12'h662, 12'hEED, 12'hFFF, 12'hFFF, 12'hFEE, 12'h442, 12'hCB7, 12'h660, 12'h881, 12'hDD5, 12'hDD4, 12'hCC2, 12'hBB1, 12'hCC2, 12'hCC2, 12'hCC2, 12'hDC2, 12'hDC1, 12'hDD2, 12'hDD2, 12'hCC1, 12'hCC1, 12'hCC1, 12'hCC1, 12'hCC3, 12'hDD4, 12'hDC3, 12'hCC2, 12'hCC1, 12'hCC4, 12'h663, 12'hEEE, 12'hFFF, 12'hFFF, 12'hFEF, 12'h442, 12'hCC7, 12'h550, 12'hAA3, 12'hDD6, 12'hCC3, 12'hBB3, 12'hBB2, 12'hCC3, 12'hCC2, 12'hCC1, 12'hCB1, 12'hCC1, 12'hCC1, 12'hCC1, 12'hCC1, 12'hCC1, 12'hCC1, 12'hCC2, 12'hDC3, 12'hDD3, 12'hCC2, 12'hCC1, 12'hCC1, 12'hCC4, 12'h663, 12'hEEE, 12'hFFF, 12'hFFF, 12'hEEE, 12'h442, 12'hCC8, 12'h450, 12'hAA5, 12'h994, 12'h540, 12'h440, 12'h440, 12'h760, 12'hAA2, 12'hCC1, 12'hCC1, 12'hCC1, 12'hCC1, 12'hCC1, 12'hCC1, 12'hCC1, 12'hCC1, 12'hCC1, 12'hDD2, 12'hDC2, 12'hCC1, 12'hCC1, 12'hCC1, 12'hCC4, 12'h552, 12'hFFD, 12'hFFF, 12'hFFF, 12'hEEE, 12'h443, 12'hCC9, 12'h230, 12'h774, 12'h553, 12'h432, 12'h442, 12'h442, 12'h330, 12'h770, 12'hBC2, 12'hCC1, 12'hCC0, 12'hCC0, 12'hCC0, 12'hCC1, 12'hCC1, 12'hCC1, 12'hCC1, 12'hCC1, 12'hCC1, 12'hCC0, 12'hCC1, 12'hCC2, 12'hCC4, 12'h551, 12'hFFE, 12'hFFF, 12'hFFF, 12'hEEF, 12'h443, 12'hAA9, 12'h110, 12'h110, 12'h443, 12'hAAA, 12'hCCB, 12'hAAA, 12'h442, 12'h110, 12'hBB3, 12'hBC2, 12'hCC1, 12'hCC1, 12'hCC1, 12'hCC1, 12'hCC1, 12'hCC1, 12'hCC1, 12'hCC1, 12'hCC1, 12'hCC1, 12'hCC2, 12'hDD3, 12'hCC5, 12'h663, 12'hFFE, 12'hFFF, 12'hFFF, 12'hFFF, 12'h444, 12'h443, 12'h110, 12'h665, 12'hBBB, 12'hEEE, 12'hEEF, 12'hEEE, 12'hBAA, 12'h100, 12'h993, 12'hCD4, 12'hCC1, 12'hCC1, 12'hCC1, 12'hCC2, 12'hCC2, 12'hCC2, 12'hCC2, 12'hCC1, 12'hCC1, 12'hCC2, 12'hCC3, 12'hDD4, 12'hCC6, 12'h663, 12'hFFE, 12'hFFF, 12'hFFF, 12'hFFF, 12'h888, 12'h221, 12'h555, 12'hBBB, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hEEE, 12'h322, 12'h663, 12'hDD6, 12'hCC3, 12'hCC3, 12'hCC3, 12'hDD4, 12'hDC4, 12'hDC4, 12'hCC3, 12'hCB2, 12'hBB2, 12'hBB2, 12'hAA2, 12'hBB3, 12'hAA4, 12'h552, 12'hFFE, 12'hFFF, 12'hFFF, 12'hFFF, 12'hDDD, 12'h444, 12'hCBB, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'h777, 12'h553, 12'hCC7, 12'hCC5, 12'hBB4, 12'hBB4, 12'hCC5, 12'hBB5, 12'hBB4, 12'hAA3, 12'h991, 12'h992, 12'h882, 12'h770, 12'h771, 12'h661, 12'h432, 12'hEEE, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hDDD, 12'hEEE, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'h999, 12'h221, 12'h563, 12'h451, 12'h440, 12'h440, 12'h441, 12'h330, 12'h330, 12'h230, 12'h220, 12'h220, 12'h330, 12'h110, 12'h120, 12'h220, 12'h000, 12'hCCD, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hAAA, 12'h110, 12'h341, 12'h441, 12'h340, 12'h341, 12'h441, 12'h341, 12'h341, 12'h441, 12'h441, 12'h451, 12'h452, 12'h452, 12'h452, 12'h452, 12'h222, 12'hDEE, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hABA, 12'h120, 12'h451, 12'h461, 12'h461, 12'h572, 12'h672, 12'h673, 12'h683, 12'h783, 12'h783, 12'h793, 12'h793, 12'h893, 12'h793, 12'h784, 12'h554, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'h9A9, 12'h342, 12'h784, 12'h783, 12'h682, 12'h793, 12'h793, 12'h794, 12'h895, 12'h8A5, 12'h8A5, 12'h8A4, 12'h893, 12'h793, 12'h894, 12'h795, 12'h776, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'h898, 12'h232, 12'h673, 12'h673, 12'h683, 12'h683, 12'h795, 12'h8A6, 12'h896, 12'h796, 12'h8A6, 12'h795, 12'h683, 12'h673, 12'h673, 12'h674, 12'h555, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'h898, 12'h121, 12'h341, 12'h351, 12'h452, 12'h462, 12'h573, 12'h785, 12'h675, 12'h564, 12'h674, 12'h563, 12'h452, 12'h341, 12'h342, 12'h442, 12'h333, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'h788, 12'h000, 12'h000, 12'h000, 12'h010, 12'h010, 12'h120, 12'h230, 12'h230, 12'h130, 12'h230, 12'h120, 12'h120, 12'h110, 12'h000, 12'h000, 12'h222, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'h676, 12'h221, 12'h342, 12'h352, 12'h462, 12'h573, 12'h684, 12'h684, 12'h683, 12'h572, 12'h573, 12'h573, 12'h562, 12'h564, 12'h665, 12'h787, 12'h555, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'h665, 12'h453, 12'h673, 12'h682, 12'h793, 12'h794, 12'h8A5, 12'h8B5, 12'h8A5, 12'h7A4, 12'h8A4, 12'h8A5, 12'h8A5, 12'h9A6, 12'h897, 12'hBCB, 12'h777, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'h665, 12'h563, 12'h784, 12'h793, 12'h793, 12'h793, 12'h794, 12'h7A4, 12'h8A5, 12'h8A5, 12'h9B6, 12'h9B6, 12'hBC8, 12'hAB8, 12'hAA8, 12'hCDB, 12'h888, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'h666, 12'h443, 12'h664, 12'h684, 12'h563, 12'h462, 12'h573, 12'h573, 12'h674, 12'h564, 12'h675, 12'h775, 12'h674, 12'h775, 12'h454, 12'h454, 12'h777, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'h676, 12'h121, 12'h343, 12'h564, 12'h453, 12'h342, 12'h452, 12'h342, 12'h342, 12'h342, 12'h453, 12'h554, 12'h442, 12'h564, 12'h554, 12'h333, 12'h777, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'h777, 12'h000, 12'h121, 12'h554, 12'h453, 12'h452, 12'h452, 12'h341, 12'h341, 12'h341, 12'h342, 12'h342, 12'h452, 12'h564, 12'h776, 12'h443, 12'h665, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'h888, 12'h000, 12'h111, 12'h443, 12'h453, 12'h453, 12'h453, 12'h564, 12'h564, 12'h674, 12'h674, 12'h674, 12'h675, 12'h786, 12'h776, 12'h443, 12'h555, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hCCC, 12'h555, 12'h222, 12'h232, 12'h454, 12'h443, 12'h221, 12'h231, 12'h454, 12'h564, 12'h342, 12'h342, 12'h332, 12'h332, 12'h332, 12'h443, 12'h777, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hBBB, 12'h555, 12'h222, 12'h898, 12'h777, 12'h111, 12'h232, 12'h776, 12'h787, 12'h121, 12'h454, 12'h554, 12'h333, 12'h121, 12'h665, 12'hAAA, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hAAA, 12'h666, 12'hFFF, 12'hFFF, 12'h555, 12'h888, 12'hFFF, 12'hFFF, 12'h343, 12'hDDD, 12'hEED, 12'hABA, 12'h555, 12'hEEE, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hBBB, 12'h666, 12'hFFF, 12'hFFF, 12'h666, 12'h889, 12'hFFF, 12'hFFF, 12'h444, 12'hDDD, 12'hEFF, 12'hDDD, 12'h566, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hAAA, 12'h666, 12'hFFF, 12'hFFF, 12'h777, 12'h888, 12'hFFF, 12'hFFF, 12'h666, 12'hCCC, 12'hFFF, 12'hEEE, 12'h666, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hEEE, 12'hDDD, 12'h888, 12'h666, 12'hFFF, 12'hFFF, 12'h777, 12'h999, 12'hFFF, 12'hFFF, 12'h666, 12'hBBB, 12'hFFF, 12'hEEE, 12'h555, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hAAA, 12'h444, 12'h222, 12'h666, 12'hFFF, 12'hEEE, 12'h555, 12'h888, 12'hFFF, 12'hFFF, 12'h666, 12'hAAA, 12'hFFF, 12'hDDD, 12'h444, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hCCC, 12'h555, 12'h555, 12'h999, 12'hFFF, 12'h999, 12'h333, 12'h777, 12'hFFE, 12'hBBB, 12'h444, 12'hBBB, 12'hDDD, 12'h888, 12'h444, 12'hFFE, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hEEE, 12'hBBB, 12'hBBB, 12'hDDD, 12'hFFF, 12'h776, 12'h333, 12'h999, 12'hEEE, 12'h666, 12'h333, 12'hDDD, 12'hAAA, 12'h333, 12'h767, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hEEE, 12'hFFF, 12'hFFF, 12'hFFF, 12'hCCC, 12'hBBB, 12'hEEE, 12'hFFF, 12'h888, 12'h999, 12'hFFF, 12'hFFF, 12'hAAB, 12'hDDD, 12'hFFF, 12'hFFF, 12'hFFF };
    parameter [11:0] fp2 [0:399] = {12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFE, 12'hFFE, 12'hEFE, 12'hEFD, 12'hEFD, 12'hEFD, 12'hEFD, 12'hEFD, 12'hEFD, 12'hEFD, 12'hDED, 12'hEFD, 12'hEFD, 12'hEFD, 12'hEFD, 12'hEFD, 12'hEFD, 12'hEFD, 12'hEFD, 12'hFFD, 12'hEFD, 12'hEFD, 12'hEFD, 12'hFFD, 12'hEFD, 12'hEFD, 12'hEFD, 12'hEFD, 12'hFFE, 12'hEFD, 12'hFFE, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hEFE, 12'hAA8, 12'h785, 12'h794, 12'h794, 12'h683, 12'h683, 12'h693, 12'h793, 12'h7A3, 12'h793, 12'h693, 12'h693, 12'h692, 12'h692, 12'h692, 12'h692, 12'h692, 12'h692, 12'h692, 12'h692, 12'h693, 12'h7A3, 12'h7A3, 12'h793, 12'h693, 12'h793, 12'h7A3, 12'h682, 12'h793, 12'h683, 12'h784, 12'h786, 12'hBBB, 12'hEEF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hCCB, 12'h9A7, 12'h9B7, 12'h9B6, 12'h9B6, 12'h9B5, 12'h8B4, 12'h8B4, 12'h8B3, 12'h8B3, 12'h8B3, 12'h8B3, 12'h8B3, 12'h7B2, 12'h7B2, 12'h7B2, 12'h7B2, 12'h7B2, 12'h7B2, 12'h7B2, 12'h7A2, 12'h7B2, 12'h7B2, 12'h7A2, 12'h7A2, 12'h7B2, 12'h7A2, 12'h7A2, 12'h7A2, 12'h7B2, 12'h7A2, 12'h8A3, 12'h794, 12'h675, 12'h443, 12'hBBB, 12'hFFF, 12'hFFF, 12'hFFF, 12'hABA, 12'h896, 12'hBD8, 12'hAC7, 12'hAC6, 12'hAC6, 12'h9C6, 12'h9C6, 12'h9C5, 12'h9C4, 12'h9C4, 12'h8C4, 12'h8C4, 12'h9C4, 12'h9D5, 12'hAD5, 12'h9D5, 12'h9D5, 12'h9C4, 12'h9C4, 12'h8C3, 12'h8B3, 12'h8B3, 12'h8C4, 12'h8C4, 12'h8C4, 12'h8B3, 12'h8C4, 12'h9D5, 12'hAE6, 12'h9D5, 12'h8C4, 12'hAD6, 12'h9C6, 12'hBC9, 12'h887, 12'h998, 12'hFFF, 12'hFFF, 12'hCCC, 12'h776, 12'hBC8, 12'hAC6, 12'hAC5, 12'hCF8, 12'hAD7, 12'hAD7, 12'hAD6, 12'h9D4, 12'h8C3, 12'h7B2, 12'h7B2, 12'h7B2, 12'h8C3, 12'h8B3, 12'h8B3, 12'h8B3, 12'h8B3, 12'h8B3, 12'h8B3, 12'h8B3, 12'h8C3, 12'h9D4, 12'h9C4, 12'h8C3, 12'h8C3, 12'h8C3, 12'h8C3, 12'h9C4, 12'h9C4, 12'h8C4, 12'h8C3, 12'h9C5, 12'h9B6, 12'hAB8, 12'h564, 12'hAAA, 12'hFFF, 12'hFFF, 12'hAAA, 12'h897, 12'hAC8, 12'h9C5, 12'h8B3, 12'hAE6, 12'hAE5, 12'h9D5, 12'h9D5, 12'h8C3, 12'h7C1, 12'h7C1, 12'h7C2, 12'h7C2, 12'h8C3, 12'h8C3, 12'h8C3, 12'h8C3, 12'h8C3, 12'h8C2, 12'h8C2, 12'h8C2, 12'h8C3, 12'h7C2, 12'h7C2, 12'h7C2, 12'h8C2, 12'h7B2, 12'h7B1, 12'h7B1, 12'h7B2, 12'h7B1, 12'h6A1, 12'h7B3, 12'h794, 12'h463, 12'h676, 12'hDDD, 12'hFFF, 12'hFFF, 12'hDDE, 12'h675, 12'h784, 12'h794, 12'h8A3, 12'h7A3, 12'h7B3, 12'h7A3, 12'h7B2, 12'h6B2, 12'h6B1, 12'h7B1, 12'h7B1, 12'h7B2, 12'h7B3, 12'h7B2, 12'h7B2, 12'h7B2, 12'h7B2, 12'h7B2, 12'h7B2, 12'h7B2, 12'h7B2, 12'h7B2, 12'h7B2, 12'h7B1, 12'h7B2, 12'h7A1, 12'h7B2, 12'h6A2, 12'h7A2, 12'h7A1, 12'h7A2, 12'h682, 12'h462, 12'h786, 12'hEEE, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hDDC, 12'h887, 12'h342, 12'h462, 12'h683, 12'h693, 12'h7A4, 12'h7A3, 12'h7A3, 12'h7A3, 12'h7A3, 12'h7A3, 12'h7A3, 12'h7A3, 12'h7A3, 12'h7A3, 12'h7A3, 12'h7A3, 12'h7A3, 12'h7A3, 12'h7A3, 12'h7A3, 12'h7A3, 12'h7A3, 12'h7A3, 12'h7A3, 12'h7A3, 12'h793, 12'h682, 12'h582, 12'h361, 12'h573, 12'h8A7, 12'hCDB, 12'hFFE, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hEED, 12'hDEC, 12'hCD9, 12'hAC7, 12'hAC7, 12'hAC7, 12'h9C6, 12'hAC6, 12'hAC6, 12'hAC6, 12'hAC6, 12'hAC6, 12'hAC6, 12'hAC6, 12'hAC6, 12'hAC6, 12'hAC7, 12'hAC7, 12'hBD7, 12'hAD7, 12'hAD7, 12'hAD7, 12'hBD7, 12'hBD7, 12'hBD8, 12'hBD8, 12'hBD8, 12'hCDA, 12'hEFD, 12'hEFD, 12'hFFE, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF}; 
    parameter [11:0] fp3 [0:1599] = {12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hAAA, 12'h878, 12'hFEF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hEFF, 12'hAAA, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hBBB, 12'hBBB, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hBBB, 12'h222, 12'hCCC, 12'hFFF, 12'hFFF, 12'hFFF, 12'hCCC, 12'h000, 12'hDDD, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'h888, 12'h111, 12'h999, 12'hDDD, 12'hDDD, 12'hBBA, 12'hAA9, 12'h888, 12'h221, 12'h988, 12'hDDD, 12'hEEE, 12'hEEE, 12'hAAA, 12'h000, 12'hEEE, 12'hFFF, 12'hFFF, 12'hFFF, 12'h999, 12'h999, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hDDD, 12'h333, 12'h211, 12'h321, 12'h211, 12'h310, 12'h310, 12'h310, 12'h200, 12'h210, 12'h422, 12'h433, 12'h644, 12'h422, 12'h000, 12'hCBB, 12'hEED, 12'hFFF, 12'hEED, 12'h333, 12'h666, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'h998, 12'h210, 12'h100, 12'h410, 12'h854, 12'hA65, 12'hB65, 12'hB55, 12'h943, 12'h954, 12'h955, 12'h944, 12'h834, 12'h400, 12'h300, 12'h522, 12'h644, 12'h877, 12'h877, 12'h212, 12'hBAB, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hAAA, 12'hCCC, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hEEE, 12'hBBB, 12'hCCC, 12'hFFF, 12'hFFF, 12'hCCB, 12'h311, 12'h411, 12'h844, 12'h843, 12'hC66, 12'hC65, 12'hD65, 12'hD65, 12'hC66, 12'hC66, 12'hB66, 12'hB66, 12'hB66, 12'hB55, 12'h944, 12'hA55, 12'h844, 12'h633, 12'h300, 12'h200, 12'h877, 12'hFEE, 12'hFFF, 12'hFFF, 12'hFFF, 12'hAAA, 12'h111, 12'h777, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hCCC, 12'h444, 12'h333, 12'h666, 12'hCBB, 12'h544, 12'h300, 12'h955, 12'hB66, 12'hC66, 12'hD65, 12'hE66, 12'hD65, 12'hC65, 12'hB65, 12'h733, 12'h632, 12'h743, 12'hA55, 12'hC66, 12'hD77, 12'hD66, 12'hC66, 12'hB55, 12'h722, 12'h743, 12'h522, 12'h422, 12'h766, 12'hBBB, 12'hBBB, 12'h222, 12'h333, 12'hDDD, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hEEE, 12'hCCC, 12'h666, 12'h211, 12'h200, 12'h844, 12'hB66, 12'hC66, 12'hC55, 12'hD55, 12'hD54, 12'hC55, 12'hB55, 12'h621, 12'h200, 12'h100, 12'h200, 12'h854, 12'hA55, 12'hB45, 12'hC44, 12'hD55, 12'hD65, 12'hC65, 12'hB65, 12'hB65, 12'h743, 12'h200, 12'h111, 12'h111, 12'h333, 12'hDDE, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFEE, 12'h211, 12'h522, 12'hB66, 12'hC66, 12'hC65, 12'hC54, 12'hD44, 12'hD44, 12'hC44, 12'hA44, 12'h300, 12'h653, 12'h775, 12'h210, 12'h300, 12'hA55, 12'hC45, 12'hC44, 12'hC44, 12'hC44, 12'hC55, 12'hC55, 12'hC66, 12'hB65, 12'hB76, 12'h644, 12'h100, 12'hDDD, 12'hFFF, 12'hEEF, 12'h999, 12'h999, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hBAA, 12'h200, 12'h956, 12'hC67, 12'hC56, 12'hC55, 12'hC55, 12'hC44, 12'hC44, 12'hC55, 12'h822, 12'h310, 12'h886, 12'h220, 12'h875, 12'h300, 12'h833, 12'hB55, 12'hC55, 12'hB44, 12'hC55, 12'hB55, 12'hB55, 12'hC55, 12'hC66, 12'hB66, 12'hEBA, 12'h211, 12'h888, 12'hCCD, 12'h334, 12'h000, 12'h999, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hEEE, 12'h211, 12'h522, 12'hB77, 12'hB66, 12'hB55, 12'hB55, 12'hB55, 12'hC55, 12'hD55, 12'hC55, 12'h933, 12'h410, 12'hA97, 12'h885, 12'h753, 12'h300, 12'h834, 12'hA55, 12'h834, 12'h510, 12'h400, 12'h511, 12'hA45, 12'hC55, 12'hC55, 12'hD77, 12'hFCB, 12'h644, 12'h000, 12'h111, 12'h333, 12'hBBB, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hEEE, 12'h555, 12'h444, 12'h443, 12'h100, 12'hA55, 12'hB55, 12'h944, 12'h400, 12'h400, 12'h722, 12'hD76, 12'hD66, 12'hC55, 12'hB44, 12'h400, 12'h300, 12'h310, 12'h300, 12'h732, 12'hA56, 12'h622, 12'h200, 12'h210, 12'h532, 12'h200, 12'h411, 12'hB55, 12'hC55, 12'hC65, 12'hD98, 12'hA87, 12'h110, 12'hBBB, 12'hEEE, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFEF, 12'hCCC, 12'h565, 12'h000, 12'h210, 12'hB56, 12'hA44, 12'h410, 12'h310, 12'h210, 12'h100, 12'h843, 12'hC76, 12'hC65, 12'hD65, 12'hA44, 12'hA44, 12'hA44, 12'hB55, 12'hB55, 12'h944, 12'h100, 12'h441, 12'hBB8, 12'hBB8, 12'h553, 12'h310, 12'hA44, 12'hC55, 12'hC65, 12'hC66, 12'hB98, 12'h100, 12'h887, 12'hEEE, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hA99, 12'h000, 12'h633, 12'hC66, 12'h933, 12'h310, 12'h774, 12'h885, 12'h775, 12'h310, 12'h954, 12'hC65, 12'hD55, 12'hC55, 12'hC55, 12'hC55, 12'hC55, 12'hB55, 12'h621, 12'h100, 12'h9A7, 12'h884, 12'h773, 12'h996, 12'h310, 12'hA43, 12'hD65, 12'hD55, 12'hD76, 12'hB87, 12'h100, 12'h110, 12'h444, 12'hEEE, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'h655, 12'h100, 12'h955, 12'hB55, 12'h711, 12'h531, 12'h985, 12'h431, 12'h986, 12'h532, 12'h521, 12'hC65, 12'hD65, 12'hC55, 12'hC55, 12'hC55, 12'hB55, 12'hB45, 12'h610, 12'h210, 12'hBC8, 12'h995, 12'h772, 12'h885, 12'h310, 12'hA53, 12'hC64, 12'hD65, 12'hC65, 12'h955, 12'h100, 12'h111, 12'h222, 12'h655, 12'hCCC, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFEF, 12'h322, 12'h300, 12'hA66, 12'hB55, 12'h721, 12'h631, 12'hBA7, 12'hA86, 12'hA97, 12'h410, 12'h833, 12'hC65, 12'hC54, 12'hB44, 12'hC55, 12'h822, 12'hA44, 12'hC55, 12'h822, 12'h100, 12'h985, 12'hBA7, 12'hA85, 12'h531, 12'h400, 12'hB54, 12'hC54, 12'hD55, 12'hC66, 12'h632, 12'h211, 12'hDCC, 12'hBBB, 12'h888, 12'hBBB, 12'hFFF, 12'hFFF, 12'hEEE, 12'h888, 12'h888, 12'h000, 12'h422, 12'hB77, 12'hB66, 12'h833, 12'h410, 12'h753, 12'h753, 12'h410, 12'h954, 12'hB55, 12'hC55, 12'hC44, 12'h700, 12'hB44, 12'h821, 12'h711, 12'hC55, 12'hC55, 12'h621, 12'h410, 12'h410, 12'h300, 12'h400, 12'h933, 12'hC55, 12'hC55, 12'hC55, 12'hB55, 12'h411, 12'h766, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFEF, 12'h767, 12'h222, 12'h000, 12'h100, 12'h733, 12'hB66, 12'hA65, 12'h732, 12'h420, 12'h621, 12'h843, 12'hB55, 12'hB55, 12'hC45, 12'hB45, 12'hB44, 12'hC55, 12'hB55, 12'hB55, 12'hC55, 12'hC56, 12'hB56, 12'hA55, 12'h955, 12'h945, 12'hA55, 12'hA55, 12'hB55, 12'hB55, 12'hA55, 12'hA66, 12'h200, 12'hA99, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hDDD, 12'h100, 12'h544, 12'hB88, 12'hB77, 12'hB76, 12'hA65, 12'hA55, 12'hA55, 12'hA55, 12'hB55, 12'hB55, 12'hB55, 12'hC56, 12'hC55, 12'hB55, 12'hC66, 12'hC66, 12'hC56, 12'hC66, 12'hB67, 12'hB67, 12'hB67, 12'hB67, 12'hB67, 12'hB66, 12'h955, 12'h744, 12'h733, 12'h301, 12'h201, 12'hDDD, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'h322, 12'h100, 12'h633, 12'h844, 12'h944, 12'h954, 12'h944, 12'h933, 12'h933, 12'hA33, 12'h933, 12'h934, 12'h934, 12'h933, 12'h933, 12'h823, 12'h822, 12'h822, 12'h711, 12'h611, 12'h511, 12'h501, 12'h400, 12'h400, 12'h300, 12'h300, 12'h300, 12'h300, 12'h100, 12'h433, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hCCC, 12'h333, 12'h000, 12'h100, 12'h301, 12'h400, 12'h300, 12'h300, 12'h300, 12'h300, 12'h400, 12'h400, 12'h400, 12'h300, 12'h400, 12'h500, 12'h400, 12'h500, 12'h600, 12'h600, 12'h711, 12'h711, 12'h822, 12'h933, 12'hA34, 12'hA45, 12'hB77, 12'hEBB, 12'h433, 12'h100, 12'h111, 12'h666, 12'hDDE, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hABA, 12'h222, 12'h222, 12'h222, 12'h211, 12'h866, 12'h967, 12'hA76, 12'hA77, 12'hA76, 12'hA65, 12'hB65, 12'hB55, 12'hA65, 12'hA65, 12'hB65, 12'hB65, 12'hB66, 12'hB65, 12'hB66, 12'hB55, 12'hB55, 12'hB65, 12'hB65, 12'hA55, 12'hB56, 12'hB67, 12'hD9A, 12'h756, 12'h211, 12'h888, 12'h999, 12'h555, 12'hBBC, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hCDD, 12'hAAA, 12'hEEE, 12'hEDE, 12'h655, 12'h100, 12'h311, 12'h755, 12'hA66, 12'hA66, 12'hB66, 12'hB55, 12'hC65, 12'hC65, 12'hC65, 12'hC65, 12'hC55, 12'hC65, 12'hB65, 12'hC66, 12'hB65, 12'hB65, 12'hA65, 12'hA54, 12'h944, 12'h844, 12'h856, 12'h433, 12'h322, 12'h888, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hBBB, 12'h100, 12'h322, 12'h311, 12'h411, 12'h622, 12'h622, 12'h832, 12'h833, 12'h943, 12'h833, 12'h943, 12'h933, 12'h833, 12'h833, 12'h732, 12'h732, 12'h632, 12'h521, 12'h511, 12'h511, 12'h311, 12'h200, 12'h988, 12'hDDD, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hCCC, 12'h222, 12'h444, 12'hDDD, 12'hCBC, 12'hAAA, 12'h322, 12'h311, 12'h655, 12'h533, 12'h422, 12'h422, 12'h321, 12'h422, 12'h210, 12'h100, 12'h322, 12'h544, 12'h543, 12'h100, 12'hA88, 12'hCBB, 12'hBAA, 12'h322, 12'hBBB, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hCCC, 12'h777, 12'hDDD, 12'hFFF, 12'hFFF, 12'hEEE, 12'h333, 12'h777, 12'hEEE, 12'hEEE, 12'hDDD, 12'hDDD, 12'hDDD, 12'hCCC, 12'h666, 12'h222, 12'hCCC, 12'hEEE, 12'hCCC, 12'h000, 12'hCCC, 12'hFFF, 12'hFFF, 12'h888, 12'hAAA, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hBBB, 12'h222, 12'hBBB, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'h666, 12'h222, 12'hEEE, 12'hFFF, 12'hEEE, 12'h111, 12'h888, 12'hFFF, 12'hFFF, 12'hEEE, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'h666, 12'h222, 12'hEEE, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hEEE, 12'h555, 12'h444, 12'hEEE, 12'hFFF, 12'hFFF, 12'h333, 12'h777, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF, 12'hFFF}; 

    assign fp1_start = (h_cnt - pos_x + (v_cnt - (pos_y - char_h + 1)) * char_w); 
    assign fp2_start = (h_cnt % 40 + ((v_cnt + 40 - (base_y % 40)) % 40 - 30) * 40); 
    assign fp3_start = (h_cnt % 40 + ((v_cnt + 40 - (base_y % 40)) % 40) * 40); 

    always @(*) begin 
        case (state)
            Init: begin 
                {vgaRed, vgaGreen, vgaBlue} = 12'hfff; 
            end 
            Play: begin 
                if (h_cnt >= 480 || h_cnt <= 159) {vgaRed, vgaGreen, vgaBlue} = 12'h000; // out of border 
                else if (((position < 96 && monster_bg[position] == 1'b1) || (position >= 96 && monster_top[position % 96] == 1'b1)) && fp3[fp3_start] != 12'hFFF) begin 
                    {vgaRed, vgaGreen, vgaBlue} = fp3[fp3_start]; // monster 
                end else if (pos_x + char_w < 480 && h_cnt >= pos_x && h_cnt < pos_x + char_w && v_cnt <= pos_y && v_cnt > pos_y - char_h && fp1[fp1_start] != 12'hFFF) begin 
                    {vgaRed, vgaGreen, vgaBlue} = fp1[fp1_start];  // char 
                end else if (offset == 0 && ((position < 96 && bg[position] == 1'b1) || (position >= 96 && bg_top[position % 96] == 1'b1))) begin  // platform 
                    if ((v_cnt + 40 - (base_y % 40)) % 40 <= 39 && (v_cnt + 40 - (base_y % 40)) % 40 >= 30) {vgaRed, vgaGreen, vgaBlue} = fp2[fp2_start]; 
                    else {vgaRed, vgaGreen, vgaBlue} = 12'hfff; 
                end else if (offset != 0 && offset <= h_cnt - 160 && h_cnt - 160 < offset + 40) begin // moving platform 
                    if ((v_cnt + 40 - (base_y % 40)) % 40 <= 39 && (v_cnt + 40 - (base_y % 40)) % 40 >= 30) {vgaRed, vgaGreen, vgaBlue} = fp2[fp2_start_2]; 
                    else {vgaRed, vgaGreen, vgaBlue} = 12'hfff; 
                end else begin 
                    {vgaRed, vgaGreen, vgaBlue} = 12'hfff; // background 
                end 
            end 
            Finish: begin 
                {vgaRed, vgaGreen, vgaBlue} = 12'hfff; 
            end 
        endcase
    end 

    always @(*) begin
        if (h_cnt >= 480 || h_cnt <= 159) position = 0; 
        else begin 
            if (v_cnt < base_y % 40) position = (h_cnt - 160) / 40 + 96; 
            else position = (h_cnt - 160) / 40 + (v_cnt - (base_y % 40)) / 40 * 8; 
        end 
    end

    assign offset_start = (v_cnt < base_y % 40) ? 120 : (v_cnt - (base_y % 40)) / 40 * 10; 
    assign offset = (offset_start >= 120) ? offsets_top : {offsets[offset_start], offsets[offset_start + 1], offsets[offset_start + 2], offsets[offset_start + 3], offsets[offset_start + 4], offsets[offset_start + 5], offsets[offset_start + 6], offsets[offset_start + 7], offsets[offset_start + 8], offsets[offset_start + 9], offsets[offset_start + 10]};  
    assign fp2_start_2 = ((h_cnt - 160 - offset) % 40 + ((v_cnt + 40 - (base_y % 40)) % 40 - 30) * 40); 

endmodule

module speed_gen (
    output reg [0:199] mem
); 

    always @(*) begin 
        mem[0] = 1'b1; 
        mem[1] = 1'b1;
        mem[2] = 1'b1;
        mem[3] = 1'b1;
        mem[4] = 1'b1;
        mem[5] = 1'b1;
        mem[6] = 1'b1;
        mem[7] = 1'b1;
        mem[8] = 1'b1;
        mem[9] = 1'b1;
        mem[10] = 1'b1;
        mem[11] = 1'b1;
        mem[12] = 1'b1;
        mem[13] = 1'b1;
        mem[14] = 1'b1;
        mem[15] = 1'b1;
        mem[16] = 1'b1;
        mem[17] = 1'b1;
        mem[18] = 1'b1;
        mem[19] = 1'b1;
        mem[20] = 1'b1;
        mem[21] = 1'b1;
        mem[22] = 1'b1;
        mem[23] = 1'b1;
        mem[24] = 1'b1;
        mem[25] = 1'b1;
        mem[26] = 1'b1;
        mem[27] = 1'b1;
        mem[28] = 1'b1;
        mem[29] = 1'b1;
        mem[30] = 1'b1;
        mem[31] = 1'b1;
        mem[32] = 1'b1;
        mem[33] = 1'b1;
        mem[34] = 1'b1;
        mem[35] = 1'b1;
        mem[36] = 1'b1;
        mem[37] = 1'b1;
        mem[38] = 1'b1;
        mem[39] = 1'b1;
        mem[40] = 1'b1;
        mem[41] = 1'b1;
        mem[42] = 1'b1;
        mem[43] = 1'b1;
        mem[44] = 1'b1;
        mem[45] = 1'b1;
        mem[46] = 1'b1;
        mem[47] = 1'b1;
        mem[48] = 1'b1;
        mem[49] = 1'b1;
        mem[50] = 1'b1;
        mem[51] = 1'b1;
        mem[52] = 1'b1;
        mem[53] = 1'b1;
        mem[54] = 1'b1;
        mem[55] = 1'b1;
        mem[56] = 1'b1;
        mem[57] = 1'b1;
        mem[58] = 1'b1;
        mem[59] = 1'b1;
        mem[60] = 1'b1;
        mem[61] = 1'b1;
        mem[62] = 1'b1;
        mem[63] = 1'b1;
        mem[64] = 1'b1;
        mem[65] = 1'b1;
        mem[66] = 1'b1;
        mem[67] = 1'b1;
        mem[68] = 1'b1;
        mem[69] = 1'b1;
        mem[70] = 1'b1;
        mem[71] = 1'b1;
        mem[72] = 1'b1;
        mem[73] = 1'b1;
        mem[74] = 1'b1;
        mem[75] = 1'b1;
        mem[76] = 1'b1;
        mem[77] = 1'b1;
        mem[78] = 1'b1;
        mem[79] = 1'b1;
        mem[80] = 1'b1;
        mem[81] = 1'b1;
        mem[82] = 1'b1;
        mem[83] = 1'b1;
        mem[84] = 1'b1;
        mem[85] = 1'b1;
        mem[86] = 1'b1;
        mem[87] = 1'b1;
        mem[88] = 1'b1;
        mem[89] = 1'b1;
        mem[90] = 1'b1;
        mem[91] = 1'b1;
        mem[92] = 1'b1;
        mem[93] = 1'b1;
        mem[94] = 1'b1;
        mem[95] = 1'b1;
        mem[96] = 1'b1;
        mem[97] = 1'b1;
        mem[98] = 1'b1;
        mem[99] = 1'b1;
        mem[100] = 1'b1;
        mem[101] = 1'b0;
        mem[102] = 1'b1;
        mem[103] = 1'b0;
        mem[104] = 1'b1;
        mem[105] = 1'b0;
        mem[106] = 1'b1;
        mem[107] = 1'b0;
        mem[108] = 1'b1;
        mem[109] = 1'b0;
        mem[110] = 1'b1;
        mem[111] = 1'b0;
        mem[112] = 1'b1;
        mem[113] = 1'b0;
        mem[114] = 1'b1;
        mem[115] = 1'b0;
        mem[116] = 1'b1;
        mem[117] = 1'b0;
        mem[118] = 1'b1;
        mem[119] = 1'b0;
        mem[120] = 1'b1;
        mem[121] = 1'b0;
        mem[122] = 1'b1;
        mem[123] = 1'b0;
        mem[124] = 1'b1;
        mem[125] = 1'b0;
        mem[126] = 1'b1;
        mem[127] = 1'b0;
        mem[128] = 1'b1;
        mem[129] = 1'b0;
        mem[130] = 1'b1;
        mem[131] = 1'b0;
        mem[132] = 1'b1;
        mem[133] = 1'b0;
        mem[134] = 1'b1;
        mem[135] = 1'b0;
        mem[136] = 1'b1;
        mem[137] = 1'b0;
        mem[138] = 1'b1;
        mem[139] = 1'b0;
        mem[140] = 1'b1;
        mem[141] = 1'b0;
        mem[142] = 1'b1;
        mem[143] = 1'b0;
        mem[144] = 1'b1;
        mem[145] = 1'b0;
        mem[146] = 1'b1;
        mem[147] = 1'b0;
        mem[148] = 1'b1;
        mem[149] = 1'b0;
        mem[150] = 1'b1;
        mem[151] = 1'b0;
        mem[152] = 1'b0;
        mem[153] = 1'b1;
        mem[154] = 1'b0;
        mem[155] = 1'b0;
        mem[156] = 1'b1;
        mem[157] = 1'b0;
        mem[158] = 1'b0;
        mem[159] = 1'b1;
        mem[160] = 1'b0;
        mem[161] = 1'b0;
        mem[162] = 1'b1;
        mem[163] = 1'b0;
        mem[164] = 1'b0;
        mem[165] = 1'b1;
        mem[166] = 1'b0;
        mem[167] = 1'b0;
        mem[168] = 1'b1;
        mem[169] = 1'b0;
        mem[170] = 1'b0;
        mem[171] = 1'b0;
        mem[172] = 1'b1;
        mem[173] = 1'b0;
        mem[174] = 1'b0;
        mem[175] = 1'b0;
        mem[176] = 1'b1;
        mem[177] = 1'b0;
        mem[178] = 1'b0;
        mem[179] = 1'b0;
        mem[180] = 1'b0;
        mem[181] = 1'b1;
        mem[182] = 1'b0;
        mem[183] = 1'b0;
        mem[184] = 1'b0;
        mem[185] = 1'b0;
        mem[186] = 1'b0;
        mem[187] = 1'b0;
        mem[188] = 1'b1;
        mem[189] = 1'b0;
        mem[190] = 1'b0;
        mem[191] = 1'b0;
        mem[192] = 1'b0;
        mem[193] = 1'b0;
        mem[194] = 1'b0;
        mem[195] = 1'b0;
        mem[196] = 1'b0;
        mem[197] = 1'b0;
        mem[198] = 1'b0;
        mem[199] = 1'b0;
    end 

endmodule



// ====================
// provided modules
// ====================
module clock_divider #(parameter n=25) (clk, clk_div);
    input clk;
    output clk_div;

    reg [n-1:0] num = 0;
    wire [n-1:0] next_num;

    always @(posedge clk) begin
        num <= next_num;
    end

    assign next_num = num + 1;
    assign clk_div = num[n-1];
endmodule


module debounce (pb, clk, pb_debounced);
    input pb;
    input clk;
    output pb_debounced;

    reg [3:0] shift_reg;

    always @(posedge clk) begin
        shift_reg[3:1] <= shift_reg[2:0];
        shift_reg[0] <= pb;
    end

    assign pb_debounced = ((shift_reg == 4'b1111) ? 1'b1 : 1'b0);
endmodule


module one_pulse (pb_debounced, clk, pb_one_pulse);
    input pb_debounced;
    input clk;
    output pb_one_pulse;
    
    reg pb_one_pulse;
    reg pb_debounced_delay;

    always @(posedge clk) begin
        if(pb_debounced == 1'b1 && pb_debounced_delay == 1'b0) begin
            pb_one_pulse <= 1'b1;
        end else begin
            pb_one_pulse <= 1'b0;
        end            
        pb_debounced_delay <= pb_debounced;
    end
endmodule


module SevenSegment(
	output reg [6:0] display,
	output reg [3:0] digit, 
	input wire [15:0] nums, // four 4-bits BCD number
	input wire rst,
	input wire clk  // Input 100Mhz clock
);
    
    reg [15:0] clk_divider;
    reg [3:0] display_num;
    
    always @ (posedge clk, posedge rst) begin
    	if (rst) begin
    		clk_divider <= 15'b0;
    	end else begin
    		clk_divider <= clk_divider + 15'b1;
    	end
    end
    
    always @ (posedge clk_divider[15], posedge rst) begin
    	if (rst) begin
    		display_num <= 4'b0000;
    		digit <= 4'b1111;
    	end else begin
    		case (digit)
    			4'b1110 : begin
    					display_num <= nums[7:4];
    					digit <= 4'b1101;
    				end
    			4'b1101 : begin
						display_num <= nums[11:8];
						digit <= 4'b1011;
					end
    			4'b1011 : begin
						display_num <= nums[15:12];
						digit <= 4'b0111;
					end
    			4'b0111 : begin
						display_num <= nums[3:0];
						digit <= 4'b1110;
					end
    			default : begin
						display_num <= nums[3:0];
						digit <= 4'b1110;
					end				
    		endcase
    	end
    end
    
    always @ (*) begin
    	case (display_num)
    		0 : display = 7'b1000000;	//0000, O 
			1 : display = 7'b1111001;   //0001                                                
			2 : display = 7'b0100100;   //0010                                                
			3 : display = 7'b0110000;   //0011                                             
			4 : display = 7'b0011001;   //0100                                               
			5 : display = 7'b0010010;   //0101, S                                               
			6 : display = 7'b0000010;   //0110
			7 : display = 7'b1111000;   //0111
			8 : display = 7'b0000000;   //1000
			9 : display = 7'b0010000;	//1001
			10: display = 7'b0111111;   // -
			11: display = 7'b1100010;   // W
			12: display = 7'b1001111;   // I 
			13: display = 7'b1001000;   // N 
			14: display = 7'b1000111;   // L 
			15: display = 7'b0000110;   // E 
			default : display = 7'b1111111;
    	endcase
    end
    
endmodule


module KeyboardDecoder(
    input wire rst,
    input wire clk,
    inout wire PS2_DATA,
    inout wire PS2_CLK,
    output reg [511:0] key_down,
    output wire [8:0] last_change,
    output reg key_valid
);
    
    parameter [1:0] INIT			= 2'b00;
    parameter [1:0] WAIT_FOR_SIGNAL = 2'b01;
    parameter [1:0] GET_SIGNAL_DOWN = 2'b10;
    parameter [1:0] WAIT_RELEASE    = 2'b11;
    
    parameter [7:0] IS_INIT			= 8'hAA;
    parameter [7:0] IS_EXTEND		= 8'hE0;
    parameter [7:0] IS_BREAK		= 8'hF0;
    
    reg [9:0] key;		// key = {been_extend, been_break, key_in}
    reg [1:0] state;
    reg been_ready, been_extend, been_break;
    
    wire [7:0] key_in;
    wire is_extend;
    wire is_break;
    wire valid;
    wire err;
    
    wire [511:0] key_decode = 1 << last_change;
    assign last_change = {key[9], key[7:0]};
    
    KeyboardCtrl inst (
		.key_in(key_in),
		.is_extend(is_extend),
		.is_break(is_break),
		.valid(valid),
		.err(err),
		.PS2_DATA(PS2_DATA),
		.PS2_CLK(PS2_CLK),
		.rst(rst),
		.clk(clk)
	);
	
	one_pulse op (
		.pb_one_pulse(pulse_been_ready),
		.pb_debounced(been_ready),
		.clk(clk)
	);

    always @ (posedge clk, posedge rst) begin
    	if (rst) begin
    		state <= INIT;
    		been_ready  <= 1'b0;
    		been_extend <= 1'b0;
    		been_break  <= 1'b0;
    		key <= 10'b0_0_0000_0000;
    	end else begin
    		state <= state;
			been_ready  <= been_ready;
			been_extend <= (is_extend) ? 1'b1 : been_extend;
			been_break  <= (is_break ) ? 1'b1 : been_break;
			key <= key;
    		case (state)
    			INIT : begin
    					if (key_in == IS_INIT) begin
    						state <= WAIT_FOR_SIGNAL;
    						been_ready  <= 1'b0;
							been_extend <= 1'b0;
							been_break  <= 1'b0;
							key <= 10'b0_0_0000_0000;
    					end else begin
    						state <= INIT;
    					end
    				end
    			WAIT_FOR_SIGNAL : begin
    					if (valid == 0) begin
    						state <= WAIT_FOR_SIGNAL;
    						been_ready <= 1'b0;
    					end else begin
    						state <= GET_SIGNAL_DOWN;
    					end
    				end
    			GET_SIGNAL_DOWN : begin
						state <= WAIT_RELEASE;
						key <= {been_extend, been_break, key_in};
						been_ready  <= 1'b1;
    				end
    			WAIT_RELEASE : begin
    					if (valid == 1) begin
    						state <= WAIT_RELEASE;
    					end else begin
    						state <= WAIT_FOR_SIGNAL;
    						been_extend <= 1'b0;
    						been_break  <= 1'b0;
    					end
    				end
    			default : begin
    					state <= INIT;
						been_ready  <= 1'b0;
						been_extend <= 1'b0;
						been_break  <= 1'b0;
						key <= 10'b0_0_0000_0000;
    				end
    		endcase
    	end
    end
    
    always @ (posedge clk, posedge rst) begin
    	if (rst) begin
    		key_valid <= 1'b0;
    		key_down <= 511'b0;
    	end else if (key_decode[last_change] && pulse_been_ready) begin
    		key_valid <= 1'b1;
    		if (key[8] == 0) begin
    			key_down <= key_down | key_decode;
    		end else begin
    			key_down <= key_down & (~key_decode);
    		end
    	end else begin
    		key_valid <= 1'b0;
			key_down <= key_down;
    	end
    end

endmodule


module vga_controller (
    input wire pclk, reset,
    output wire hsync, vsync, valid,
    output wire [9:0]h_cnt,
    output wire [9:0]v_cnt
    );

    reg [9:0]pixel_cnt;
    reg [9:0]line_cnt;
    reg hsync_i,vsync_i;

    parameter HD = 640;
    parameter HF = 16;
    parameter HS = 96;
    parameter HB = 48;
    parameter HT = 800; 
    parameter VD = 480;
    parameter VF = 10;
    parameter VS = 2;
    parameter VB = 33;
    parameter VT = 525;
    parameter hsync_default = 1'b1;
    parameter vsync_default = 1'b1;

    always @(posedge pclk)
        if (reset)
            pixel_cnt <= 0;
        else
            if (pixel_cnt < (HT - 1))
                pixel_cnt <= pixel_cnt + 1;
            else
                pixel_cnt <= 0;

    always @(posedge pclk)
        if (reset)
            hsync_i <= hsync_default;
        else
            if ((pixel_cnt >= (HD + HF - 1)) && (pixel_cnt < (HD + HF + HS - 1)))
                hsync_i <= ~hsync_default;
            else
                hsync_i <= hsync_default; 

    always @(posedge pclk)
        if (reset)
            line_cnt <= 0;
        else
            if (pixel_cnt == (HT -1))
                if (line_cnt < (VT - 1))
                    line_cnt <= line_cnt + 1;
                else
                    line_cnt <= 0;

    always @(posedge pclk)
        if (reset)
            vsync_i <= vsync_default; 
        else if ((line_cnt >= (VD + VF - 1)) && (line_cnt < (VD + VF + VS - 1)))
            vsync_i <= ~vsync_default; 
        else
            vsync_i <= vsync_default; 

    assign hsync = hsync_i;
    assign vsync = vsync_i;
    assign valid = ((pixel_cnt < HD) && (line_cnt < VD));

    assign h_cnt = (pixel_cnt < HD) ? pixel_cnt : 10'd0;
    assign v_cnt = (line_cnt < VD) ? line_cnt : 10'd0;

endmodule


module clk_wiz(clk1, clk, clk22);
    input clk;
    output clk1;
    output clk22;
    reg [21:0] num;
    wire [21:0] next_num;

    always @(posedge clk) begin
    num <= next_num;
    end

    assign next_num = num + 1'b1;
    assign clk1 = num[1];
    assign clk22 = num[21];
endmodule

module clock_32_hz (clk, rst, clk_32hz);
    output reg clk_32hz;
    input clk, rst; 
    reg [20:0] count;
    always @(posedge clk, posedge rst) begin
        if(rst) begin
            count <= 0;
            clk_32hz <= 0;
        end else if (count == 21'd1562500) begin 
            count <= 0;
            clk_32hz <= ~clk_32hz;
        end else begin
            count <= count + 1'b1;    
        end 
    end
endmodule

module note_gen(
    input clk, // clock from crystal
    input rst, // active high reset
    input [2:0] volume, 
    input [21:0] note_div_left, // div for note generation
    input [21:0] note_div_right,
    output [15:0] audio_left,
    output [15:0] audio_right
    );

    // Declare internal signals
    reg [21:0] clk_cnt_next, clk_cnt;
    reg [21:0] clk_cnt_next_2, clk_cnt_2;
    reg b_clk, b_clk_next;
    reg c_clk, c_clk_next;

    // Note frequency generation
    // clk_cnt, clk_cnt_2, b_clk, c_clk
    always @(posedge clk or posedge rst)
        if (rst == 1'b1)
            begin
                clk_cnt <= 22'd0;
                clk_cnt_2 <= 22'd0;
                b_clk <= 1'b0;
                c_clk <= 1'b0;
            end
        else
            begin
                clk_cnt <= clk_cnt_next;
                clk_cnt_2 <= clk_cnt_next_2;
                b_clk <= b_clk_next;
                c_clk <= c_clk_next;
            end
    
    // clk_cnt_next, b_clk_next
    always @*
        if (clk_cnt == note_div_left)
            begin
                clk_cnt_next = 22'd0;
                b_clk_next = ~b_clk;
            end
        else
            begin
                clk_cnt_next = clk_cnt + 1'b1;
                b_clk_next = b_clk;
            end

    // clk_cnt_next_2, c_clk_next
    always @*
        if (clk_cnt_2 == note_div_right)
            begin
                clk_cnt_next_2 = 22'd0;
                c_clk_next = ~c_clk;
            end
        else
            begin
                clk_cnt_next_2 = clk_cnt_2 + 1'b1;
                c_clk_next = c_clk;
            end

    // Assign the amplitude of the note
    // Volume is controlled here
    assign audio_left = (note_div_left == 22'd1) ? 16'h0000 : 
                                (b_clk == 1'b0) ? 16'hE000 : 16'h2000;
    assign audio_right = (note_div_right == 22'd1) ? 16'h0000 : 
                                (c_clk == 1'b0) ? 16'hE000 : 16'h2000;
endmodule

module speaker_control(
    input clk,  // clock from the crystal
    input rst,  // active high reset
    input [15:0] audio_in_left, // left channel audio data input
    input [15:0] audio_in_right, // right channel audio data input
    output audio_mclk, // master clock
    output audio_lrck, // left-right clock, Word Select clock, or sample rate clock
    output audio_sck, // serial clock
    output reg audio_sdin // serial audio data input
    ); 

    // Declare internal signal nodes 
    wire [8:0] clk_cnt_next;
    reg [8:0] clk_cnt;
    reg [15:0] audio_left, audio_right;

    // Counter for the clock divider
    assign clk_cnt_next = clk_cnt + 1'b1;

    always @(posedge clk or posedge rst)
        if (rst == 1'b1)
            clk_cnt <= 9'd0;
        else
            clk_cnt <= clk_cnt_next;

    // Assign divided clock output
    assign audio_mclk = clk_cnt[1];
    assign audio_lrck = clk_cnt[8];
    assign audio_sck = 1'b1; // use internal serial clock mode

    // audio input data buffer
    always @(posedge clk_cnt[8] or posedge rst)
        if (rst == 1'b1)
            begin
                audio_left <= 16'd0;
                audio_right <= 16'd0;
            end
        else
            begin
                audio_left <= audio_in_left;
                audio_right <= audio_in_right;
            end

    always @*
        case (clk_cnt[8:4])
            5'b00000: audio_sdin = audio_right[0];
            5'b00001: audio_sdin = audio_left[15];
            5'b00010: audio_sdin = audio_left[14];
            5'b00011: audio_sdin = audio_left[13];
            5'b00100: audio_sdin = audio_left[12];
            5'b00101: audio_sdin = audio_left[11];
            5'b00110: audio_sdin = audio_left[10];
            5'b00111: audio_sdin = audio_left[9];
            5'b01000: audio_sdin = audio_left[8];
            5'b01001: audio_sdin = audio_left[7];
            5'b01010: audio_sdin = audio_left[6];
            5'b01011: audio_sdin = audio_left[5];
            5'b01100: audio_sdin = audio_left[4];
            5'b01101: audio_sdin = audio_left[3];
            5'b01110: audio_sdin = audio_left[2];
            5'b01111: audio_sdin = audio_left[1];
            5'b10000: audio_sdin = audio_left[0];
            5'b10001: audio_sdin = audio_right[15];
            5'b10010: audio_sdin = audio_right[14];
            5'b10011: audio_sdin = audio_right[13];
            5'b10100: audio_sdin = audio_right[12];
            5'b10101: audio_sdin = audio_right[11];
            5'b10110: audio_sdin = audio_right[10];
            5'b10111: audio_sdin = audio_right[9];
            5'b11000: audio_sdin = audio_right[8];
            5'b11001: audio_sdin = audio_right[7];
            5'b11010: audio_sdin = audio_right[6];
            5'b11011: audio_sdin = audio_right[5];
            5'b11100: audio_sdin = audio_right[4];
            5'b11101: audio_sdin = audio_right[3];
            5'b11110: audio_sdin = audio_right[2];
            5'b11111: audio_sdin = audio_right[1];
            default: audio_sdin = 1'b0;
        endcase

endmodule

module music_control (
	input clk, 
	input rst, 
	input play,  
	output reg [11:0] ibeat
);
	parameter LEN = 4096;
    reg [11:0] next_ibeat;

	always @(posedge clk, posedge rst) begin
		if (rst || play == 0) begin
			ibeat <= 0;
		end else begin
            ibeat <= next_ibeat;
		end
	end

    always @* begin
        next_ibeat = (ibeat < LEN - 1) ? (ibeat + 1) : 0;
    end

endmodule

module music_example (
	input [11:0] ibeatNum,
	input en,
	output reg [31:0] toneL,
    output reg [31:0] toneR
);

    always @* begin
        if(en == 1) begin
            case(ibeatNum)
                12'd0: toneR = `e3;     12'd1: toneR = `e3; 
                12'd2: toneR = `e3;     12'd3: toneR = `e3;
                12'd4: toneR = `e3;	    12'd5: toneR = `e3;
                12'd6: toneR = `e3;  	12'd7: toneR = `e3;
                12'd8: toneR = `e3;	    12'd9: toneR = `e3;
                12'd10: toneR = `e3;	12'd11: toneR = `e3;
                12'd12: toneR = `e3;	12'd13: toneR = `e3;
                12'd14: toneR = `e3;	12'd15: toneR = `e3;

                12'd16: toneR = `e3;	12'd17: toneR = `e3;
                12'd18: toneR = `e3;	12'd19: toneR = `e3;
                12'd20: toneR = `e3;	12'd21: toneR = `e3;
                12'd22: toneR = `e3;	12'd23: toneR = `e3;
                12'd24: toneR = `e3;	12'd25: toneR = `e3;
                12'd26: toneR = `e3;	12'd27: toneR = `e3;
                12'd28: toneR = `e3;	12'd29: toneR = `e3;
                12'd30: toneR = `e3;	12'd31: toneR = `sil;

                12'd32: toneR = `e3;	12'd33: toneR = `e3; 
                12'd34: toneR = `e3;	12'd35: toneR = `e3;
                12'd36: toneR = `e3;	12'd37: toneR = `e3;
                12'd38: toneR = `e3;	12'd39: toneR = `e3;
                12'd40: toneR = `e3;	12'd41: toneR = `e3;
                12'd42: toneR = `e3;	12'd43: toneR = `e3;
                12'd44: toneR = `e3;	12'd45: toneR = `e3;
                12'd46: toneR = `e3;	12'd47: toneR = `e3;

                12'd48: toneR = `e3;	12'd49: toneR = `e3; 
                12'd50: toneR = `e3;	12'd51: toneR = `e3;
                12'd52: toneR = `e3;	12'd53: toneR = `e3;
                12'd54: toneR = `e3;	12'd55: toneR = `e3;
                12'd56: toneR = `e3;	12'd57: toneR = `e3;
                12'd58: toneR = `e3;	12'd59: toneR = `e3;
                12'd60: toneR = `e3;	12'd61: toneR = `e3;
                12'd62: toneR = `e3;	12'd63: toneR = `e3;

                12'd64: toneR = `f3;	12'd65: toneR = `f3; 
                12'd66: toneR = `f3;    12'd67: toneR = `f3;
                12'd68: toneR = `f3;	12'd69: toneR = `f3;
                12'd70: toneR = `f3;	12'd71: toneR = `f3;
                12'd72: toneR = `f3;	12'd73: toneR = `f3;
                12'd74: toneR = `f3;	12'd75: toneR = `f3;
                12'd76: toneR = `f3;	12'd77: toneR = `f3;
                12'd78: toneR = `f3;	12'd79: toneR = `f3;

                12'd80: toneR = `f3;	12'd81: toneR = `f3;
                12'd82: toneR = `f3;    12'd83: toneR = `f3;
                12'd84: toneR = `f3;    12'd85: toneR = `f3;
                12'd86: toneR = `f3;    12'd87: toneR = `f3;
                12'd88: toneR = `f3;    12'd89: toneR = `f3;
                12'd90: toneR = `f3;    12'd91: toneR = `f3;
                12'd92: toneR = `f3;    12'd93: toneR = `f3;
                12'd94: toneR = `f3;    12'd95: toneR = `f3;

                12'd96: toneR = `g3;	12'd97: toneR = `g3; 
                12'd98: toneR = `g3; 	12'd99: toneR = `g3;
                12'd100: toneR = `g3;	12'd101: toneR = `g3;
                12'd102: toneR = `g3;	12'd103: toneR = `g3;
                12'd104: toneR = `g3;	12'd105: toneR = `g3;
                12'd106: toneR = `g3;	12'd107: toneR = `g3;
                12'd108: toneR = `g3;	12'd109: toneR = `g3;
                12'd110: toneR = `g3;	12'd111: toneR = `g3;

                12'd112: toneR = `g3;	12'd113: toneR = `g3; 
                12'd114: toneR = `g3;	12'd115: toneR = `g3;
                12'd116: toneR = `g3;	12'd117: toneR = `g3;
                12'd118: toneR = `g3;	12'd119: toneR = `g3;
                12'd120: toneR = `g3;	12'd121: toneR = `g3;
                12'd122: toneR = `g3;	12'd123: toneR = `g3;
                12'd124: toneR = `g3;	12'd125: toneR = `g3;
                12'd126: toneR = `g3;	12'd127: toneR = `g3;

                12'd128: toneR = `e3;   12'd129: toneR = `e3; 
                12'd130: toneR = `e3;   12'd131: toneR = `e3;
                12'd132: toneR = `e3;	12'd133: toneR = `e3;
                12'd134: toneR = `e3;  	12'd135: toneR = `e3;
                12'd136: toneR = `e3;	12'd137: toneR = `e3;
                12'd138: toneR = `e3;	12'd139: toneR = `e3;
                12'd140: toneR = `e3;	12'd141: toneR = `e3;
                12'd142: toneR = `e3;	12'd143: toneR = `e3;

                12'd144: toneR = `e3;	12'd145: toneR = `e3;
                12'd146: toneR = `e3;	12'd147: toneR = `e3;
                12'd148: toneR = `e3;	12'd149: toneR = `e3;
                12'd150: toneR = `e3;	12'd151: toneR = `e3;
                12'd152: toneR = `e3;	12'd153: toneR = `e3;
                12'd154: toneR = `e3;	12'd155: toneR = `e3;
                12'd156: toneR = `e3;	12'd157: toneR = `e3;
                12'd158: toneR = `e3;	12'd159: toneR = `sil;

                12'd160: toneR = `e3;	12'd161: toneR = `e3; 
                12'd162: toneR = `e3;	12'd163: toneR = `e3;
                12'd164: toneR = `e3;	12'd165: toneR = `e3;
                12'd166: toneR = `e3;	12'd167: toneR = `e3;
                12'd168: toneR = `e3;	12'd169: toneR = `e3;
                12'd170: toneR = `e3;	12'd171: toneR = `e3;
                12'd172: toneR = `e3;	12'd173: toneR = `e3;
                12'd174: toneR = `e3;	12'd175: toneR = `e3;

                12'd176: toneR = `e3;	12'd177: toneR = `e3; 
                12'd178: toneR = `e3;	12'd179: toneR = `e3;
                12'd180: toneR = `e3;	12'd181: toneR = `e3;
                12'd182: toneR = `e3;	12'd183: toneR = `e3;
                12'd184: toneR = `e3;	12'd185: toneR = `e3;
                12'd186: toneR = `e3;	12'd187: toneR = `e3;
                12'd188: toneR = `e3;	12'd189: toneR = `e3;
                12'd190: toneR = `e3;	12'd191: toneR = `e3;

                12'd192: toneR = `f3;	12'd193: toneR = `f3; 
                12'd194: toneR = `f3;   12'd195: toneR = `f3;
                12'd196: toneR = `f3;	12'd197: toneR = `f3;
                12'd198: toneR = `f3;	12'd199: toneR = `f3;
                12'd200: toneR = `f3;	12'd201: toneR = `f3;
                12'd202: toneR = `f3;	12'd203: toneR = `f3;
                12'd204: toneR = `f3;	12'd205: toneR = `f3;
                12'd206: toneR = `f3;	12'd207: toneR = `f3;

                12'd208: toneR = `f3;	12'd209: toneR = `f3;
                12'd210: toneR = `f3;   12'd211: toneR = `f3;
                12'd212: toneR = `f3;   12'd213: toneR = `f3;
                12'd214: toneR = `f3;   12'd215: toneR = `f3;
                12'd216: toneR = `f3;   12'd217: toneR = `f3;
                12'd218: toneR = `f3;   12'd219: toneR = `f3;
                12'd220: toneR = `f3;   12'd221: toneR = `f3;
                12'd222: toneR = `f3;   12'd223: toneR = `f3;

                12'd224: toneR = `g3;	12'd225: toneR = `g3; 
                12'd226: toneR = `g3; 	12'd227: toneR = `g3;
                12'd228: toneR = `g3;	12'd229: toneR = `g3;
                12'd230: toneR = `g3;	12'd231: toneR = `g3;
                12'd232: toneR = `g3;	12'd233: toneR = `g3;
                12'd234: toneR = `g3;	12'd235: toneR = `g3;
                12'd236: toneR = `g3;	12'd237: toneR = `g3;
                12'd238: toneR = `g3;	12'd239: toneR = `g3;

                12'd240: toneR = `g3;	12'd241: toneR = `g3; 
                12'd242: toneR = `g3;	12'd243: toneR = `g3;
                12'd244: toneR = `g3;	12'd245: toneR = `g3;
                12'd246: toneR = `g3;	12'd247: toneR = `g3;
                12'd248: toneR = `g3;	12'd249: toneR = `g3;
                12'd250: toneR = `g3;	12'd251: toneR = `g3;
                12'd252: toneR = `g3;	12'd253: toneR = `g3;
                12'd254: toneR = `g3;	12'd255: toneR = `g3;

                12'd256: toneR = `c3;   12'd257: toneR = `c3; 
                12'd258: toneR = `c3;   12'd259: toneR = `c3;
                12'd260: toneR = `c3;	12'd261: toneR = `c3;
                12'd262: toneR = `c3;  	12'd263: toneR = `c3;
                12'd264: toneR = `c3;	12'd265: toneR = `c3;
                12'd266: toneR = `c3;	12'd267: toneR = `sil;
                12'd268: toneR = `c3;	12'd269: toneR = `c3;
                12'd270: toneR = `c3;	12'd271: toneR = `c3;

                12'd272: toneR = `c3;	12'd273: toneR = `c3;
                12'd274: toneR = `c3;	12'd275: toneR = `c3;
                12'd276: toneR = `c3;	12'd277: toneR = `c3;
                12'd278: toneR = `c3;	12'd279: toneR = `sil;
                12'd280: toneR = `c3;	12'd281: toneR = `c3;
                12'd282: toneR = `c3;	12'd283: toneR = `c3;
                12'd284: toneR = `c3;	12'd285: toneR = `c3;
                12'd286: toneR = `c3;	12'd287: toneR = `sil;

                12'd288: toneR = `c3;	12'd289: toneR = `c3; 
                12'd290: toneR = `c3;	12'd291: toneR = `c3;
                12'd292: toneR = `c3;	12'd293: toneR = `c3;
                12'd294: toneR = `c3;	12'd295: toneR = `c3;
                12'd296: toneR = `c3;	12'd297: toneR = `c3;
                12'd298: toneR = `c3;	12'd299: toneR = `sil;
                12'd300: toneR = `sil;	12'd301: toneR = `sil;
                12'd302: toneR = `sil;	12'd303: toneR = `sil;

                12'd304: toneR = `sil;	12'd305: toneR = `sil; 
                12'd306: toneR = `sil;	12'd307: toneR = `sil;
                12'd308: toneR = `sil;	12'd309: toneR = `sil;
                12'd310: toneR = `sil;	12'd311: toneR = `sil;
                12'd312: toneR = `sil;	12'd313: toneR = `sil;
                12'd314: toneR = `sil;	12'd315: toneR = `sil;
                12'd316: toneR = `sil;	12'd317: toneR = `sil;
                12'd318: toneR = `sil;	12'd319: toneR = `sil;

                default : toneR = `sil;
            endcase
        end else begin
            toneR = `sil;
        end
    end

    always @(*) begin
        if(en == 1)begin
            case(ibeatNum)
                12'd0: toneL = `sil;  	12'd1: toneL = `sil; 
                12'd2: toneL = `sil;  	12'd3: toneL = `e5;
                12'd4: toneL = `e5;	    12'd5: toneL = `e5;
                12'd6: toneL = `e5;  	12'd7: toneL = `e5;
                12'd8: toneL = `e5;	    12'd9: toneL = `e5;
                12'd10: toneL = `e5;	12'd11: toneL = `sil;
                12'd12: toneL = `e5;	12'd13: toneL = `e5;
                12'd14: toneL = `e5;	12'd15: toneL = `e5;

                12'd16: toneL = `f5;	12'd17: toneL = `f5;
                12'd18: toneL = `f5;	12'd19: toneL = `f5;
                12'd20: toneL = `f5;	12'd21: toneL = `f5;
                12'd22: toneL = `f5;	12'd23: toneL = `f5;
                12'd24: toneL = `e5;	12'd25: toneL = `e5;
                12'd26: toneL = `e5;	12'd27: toneL = `e5;
                12'd28: toneL = `e5;	12'd29: toneL = `e5;
                12'd30: toneL = `e5;	12'd31: toneL = `e5;

                12'd32: toneL = `sil;	12'd33: toneL = `sil; 
                12'd34: toneL = `sil;	12'd35: toneL = `e5;
                12'd36: toneL = `e5;	12'd37: toneL = `e5;
                12'd38: toneL = `e5;	12'd39: toneL = `e5;
                12'd40: toneL = `e5;	12'd41: toneL = `e5;
                12'd42: toneL = `e5;	12'd43: toneL = `sil;
                12'd44: toneL = `e5;	12'd45: toneL = `e5;
                12'd46: toneL = `e5;	12'd47: toneL = `e5;

                12'd48: toneL = `f5;	12'd49: toneL = `f5; 
                12'd50: toneL = `f5;	12'd51: toneL = `f5;
                12'd52: toneL = `f5;	12'd53: toneL = `f5;
                12'd54: toneL = `f5;	12'd55: toneL = `f5;
                12'd56: toneL = `e5;	12'd57: toneL = `e5;
                12'd58: toneL = `e5;	12'd59: toneL = `e5;
                12'd60: toneL = `e5;	12'd61: toneL = `e5;
                12'd62: toneL = `e5;	12'd63: toneL = `e5;

                12'd64: toneL = `d5;	12'd65: toneL = `d5; 
                12'd66: toneL = `d5;    12'd67: toneL = `d5;
                12'd68: toneL = `d5;	12'd69: toneL = `d5;
                12'd70: toneL = `d5;	12'd71: toneL = `d5;
                12'd72: toneL = `d5;	12'd73: toneL = `d5;
                12'd74: toneL = `d5;	12'd75: toneL = `d5;
                12'd76: toneL = `c5;	12'd77: toneL = `c5;
                12'd78: toneL = `c5;	12'd79: toneL = `c5;

                12'd80: toneL = `c5;	12'd81: toneL = `c5;
                12'd82: toneL = `c5;    12'd83: toneL = `c5;
                12'd84: toneL = `c5;    12'd85: toneL = `c5;
                12'd86: toneL = `c5;    12'd87: toneL = `sil;
                12'd88: toneL = `c5;    12'd89: toneL = `c5;
                12'd90: toneL = `c5;    12'd91: toneL = `c5;
                12'd92: toneL = `c5;    12'd93: toneL = `c5;
                12'd94: toneL = `c5;    12'd95: toneL = `c5;

                12'd96: toneL = `b4;	12'd97: toneL = `b4; 
                12'd98: toneL = `b4; 	12'd99: toneL = `b4;
                12'd100: toneL = `b4;	12'd101: toneL = `b4;
                12'd102: toneL = `b4;	12'd103: toneL = `b4;
                12'd104: toneL = `b4;	12'd105: toneL = `b4;
                12'd106: toneL = `b4;	12'd107: toneL = `b4;
                12'd108: toneL = `c5;	12'd109: toneL = `c5;
                12'd110: toneL = `c5;	12'd111: toneL = `c5;

                12'd112: toneL = `c5;	12'd113: toneL = `c5; 
                12'd114: toneL = `c5;	12'd115: toneL = `c5;
                12'd116: toneL = `c5;	12'd117: toneL = `c5;
                12'd118: toneL = `c5;	12'd119: toneL = `c5;
                12'd120: toneL = `d5;	12'd121: toneL = `d5;
                12'd122: toneL = `d5;	12'd123: toneL = `d5;
                12'd124: toneL = `d5;	12'd125: toneL = `d5;
                12'd126: toneL = `d5;	12'd127: toneL = `d5;

                12'd128: toneL = `sil;  12'd129: toneL = `sil; 
                12'd130: toneL = `sil;  12'd131: toneL = `e5;
                12'd132: toneL = `e5;	12'd133: toneL = `e5;
                12'd134: toneL = `e5;  	12'd135: toneL = `e5;
                12'd136: toneL = `e5;	12'd137: toneL = `e5;
                12'd138: toneL = `e5;	12'd139: toneL = `sil;
                12'd140: toneL = `e5;	12'd141: toneL = `e5;
                12'd142: toneL = `e5;	12'd143: toneL = `e5;

                12'd144: toneL = `f5;	12'd145: toneL = `f5;
                12'd146: toneL = `f5;	12'd147: toneL = `f5;
                12'd148: toneL = `f5;	12'd149: toneL = `f5;
                12'd150: toneL = `f5;	12'd151: toneL = `f5;
                12'd152: toneL = `e5;	12'd153: toneL = `e5;
                12'd154: toneL = `e5;	12'd155: toneL = `e5;
                12'd156: toneL = `e5;	12'd157: toneL = `e5;
                12'd158: toneL = `e5;	12'd159: toneL = `e5;

                12'd160: toneL = `sil;	12'd161: toneL = `sil; 
                12'd162: toneL = `sil;	12'd163: toneL = `e5;
                12'd164: toneL = `e5;	12'd165: toneL = `e5;
                12'd166: toneL = `e5;	12'd167: toneL = `e5;
                12'd168: toneL = `e5;	12'd169: toneL = `e5;
                12'd170: toneL = `e5;	12'd171: toneL = `sil;
                12'd172: toneL = `e5;	12'd173: toneL = `e5;
                12'd174: toneL = `e5;	12'd175: toneL = `e5;

                12'd176: toneL = `f5;	12'd177: toneL = `f5; 
                12'd178: toneL = `f5;	12'd179: toneL = `f5;
                12'd180: toneL = `f5;	12'd181: toneL = `f5;
                12'd182: toneL = `f5;	12'd183: toneL = `f5;
                12'd184: toneL = `e5;	12'd185: toneL = `e5;
                12'd186: toneL = `e5;	12'd187: toneL = `e5;
                12'd188: toneL = `e5;	12'd189: toneL = `e5;
                12'd190: toneL = `e5;	12'd191: toneL = `e5;

                12'd192: toneL = `d5;	12'd193: toneL = `d5; 
                12'd194: toneL = `d5;   12'd195: toneL = `d5;
                12'd196: toneL = `d5;	12'd197: toneL = `d5;
                12'd198: toneL = `d5;	12'd199: toneL = `d5;
                12'd200: toneL = `d5;	12'd201: toneL = `d5;
                12'd202: toneL = `d5;	12'd203: toneL = `d5;
                12'd204: toneL = `c5;	12'd205: toneL = `c5;
                12'd206: toneL = `c5;	12'd207: toneL = `c5;

                12'd208: toneL = `c5;	12'd209: toneL = `c5;
                12'd210: toneL = `c5;   12'd211: toneL = `c5;
                12'd212: toneL = `c5;   12'd213: toneL = `c5;
                12'd214: toneL = `c5;   12'd215: toneL = `sil;
                12'd216: toneL = `c5;   12'd217: toneL = `c5;
                12'd218: toneL = `c5;   12'd219: toneL = `c5;
                12'd220: toneL = `c5;   12'd221: toneL = `c5;
                12'd222: toneL = `c5;   12'd223: toneL = `c5;

                12'd224: toneL = `b4;	12'd225: toneL = `b4; 
                12'd226: toneL = `b4; 	12'd227: toneL = `b4;
                12'd228: toneL = `b4;	12'd229: toneL = `b4;
                12'd230: toneL = `b4;	12'd231: toneL = `b4;
                12'd232: toneL = `b4;	12'd233: toneL = `b4;
                12'd234: toneL = `b4;	12'd235: toneL = `b4;
                12'd236: toneL = `c5;	12'd237: toneL = `c5;
                12'd238: toneL = `c5;	12'd239: toneL = `c5;

                12'd240: toneL = `c5;	12'd241: toneL = `c5; 
                12'd242: toneL = `c5;	12'd243: toneL = `c5;
                12'd244: toneL = `c5;	12'd245: toneL = `c5;
                12'd246: toneL = `c5;	12'd247: toneL = `c5;
                12'd248: toneL = `d5;	12'd249: toneL = `d5;
                12'd250: toneL = `d5;	12'd251: toneL = `d5;
                12'd252: toneL = `d5;	12'd253: toneL = `d5;
                12'd254: toneL = `d5;	12'd255: toneL = `d5;

                12'd256: toneL = `c5;   12'd257: toneL = `c5; 
                12'd258: toneL = `c5;   12'd259: toneL = `c5;
                12'd260: toneL = `c5;	12'd261: toneL = `c5;
                12'd262: toneL = `c5;  	12'd263: toneL = `c5;
                12'd264: toneL = `c5;	12'd265: toneL = `c5;
                12'd266: toneL = `c5;	12'd267: toneL = `sil;
                12'd268: toneL = `c5;	12'd269: toneL = `c5;
                12'd270: toneL = `c5;	12'd271: toneL = `c5;

                12'd272: toneL = `c5;	12'd273: toneL = `c5;
                12'd274: toneL = `c5;	12'd275: toneL = `c5;
                12'd276: toneL = `c5;	12'd277: toneL = `c5;
                12'd278: toneL = `c5;	12'd279: toneL = `sil;
                12'd280: toneL = `c5;	12'd281: toneL = `c5;
                12'd282: toneL = `c5;	12'd283: toneL = `c5;
                12'd284: toneL = `c5;	12'd285: toneL = `c5;
                12'd286: toneL = `c5;	12'd287: toneL = `sil;

                12'd288: toneL = `c5;	12'd289: toneL = `c5; 
                12'd290: toneL = `c5;	12'd291: toneL = `c5;
                12'd292: toneL = `c5;	12'd293: toneL = `c5;
                12'd294: toneL = `c5;	12'd295: toneL = `c5;
                12'd296: toneL = `c5;	12'd297: toneL = `c5;
                12'd298: toneL = `c5;	12'd299: toneL = `sil;
                12'd300: toneL = `c5;	12'd301: toneL = `c5;
                12'd302: toneL = `c5;	12'd303: toneL = `c5;

                12'd304: toneL = `e5;	12'd305: toneL = `e5; 
                12'd306: toneL = `e5;	12'd307: toneL = `e5;
                12'd308: toneL = `e5;	12'd309: toneL = `e5;
                12'd310: toneL = `e5;	12'd311: toneL = `e5;
                12'd312: toneL = `g5;	12'd313: toneL = `g5;
                12'd314: toneL = `g5;	12'd315: toneL = `g5;
                12'd316: toneL = `g5;	12'd317: toneL = `g5;
                12'd318: toneL = `g5;	12'd319: toneL = `g5;

                default : toneL = `sil;
            endcase
        end
        else begin
            toneL = `sil;
        end
    end
endmodule