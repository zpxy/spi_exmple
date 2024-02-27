module spi_example(
    input  logic pclk,
    input  logic prst_n,
    input  logic [11:0] paddr,
    input  logic psel,
    input  logic penable,
    input  logic pwrite,
    input  logic [31:0] pwdata,
    output logic [31:0] prdata,
    output logic pready,
    output logic pslverr,
    output logic spi_int,

    output logic pad_spi_sclk_out,
    output logic pad_spi_sclk_oen,
    output logic pad_spi_mosi_out,
    output logic pad_spi_mosi_oen,
    output logic pad_spi_cs0_out,
    output logic pad_spi_cs0_oen,
    output logic pad_spi_cs1_out,
    output logic pad_spi_cs1_oen,

    input  logic pad_spi_miso_in,
     
    output spi_sclk,
    output spi_csn0,
    output spi_mosi,
    input  spi_miso
);

logic clk_i = pclk;
logic rst_n_i = prst_n;
logic[2:0] adr_i = paddr[4:2]; 
logic we_i = psel & (~penable) & pwrite;
logic[7:0] dat_i = pwdata[7:0];
logic miso_i = pad_spi_miso_in;
logic[7:0] dat_o;
logic inta_o;
logic sclk_o;
logic mosi_o;
logic cs_sel;

// spi register
logic [7:0] spi_cr; // control reg 
logic [7:0] spi_dr; // read and  write
logic [7:0] spi_sr; // status reg
logic [7:0] spi_er; // extenal reg
logic [7:0] tx_reg, rx_reg; // shift reg 


// fifo signals
logic [7:0] rfdout;
logic wfre,rfwe;
logic rfre,rffull,rfempty;
logic [7:0] wfdout;
logic wfwe;wffull,wfempty;
logic [11:0] clkcnt;

// misc signals
logic tirq;
logic wfov;
logic [1:0] state;
logic [2:0] bcnt;
// clkcnt ena
logic ena = ~|clkcnt;// all zero would be True ;

logic wb_acc = we_i;
logic wb_wr  = we_i;

assign prdata = {24'{1'b0},dat_o};
assign pready = 1'b1;
assign pslverr = 1'b0;
assign spi_int = inta_o;

assign pad_spi_sclk_out = sclk_o;
assign pad_spi_sclk_oen = 1'b0;
assign pad_spi_mosi_out = mosi_o;
assign pad_spi_mosi_oen = 1'b0;
assign pad_spi_cs0_out  = (~cs_sel) & ena;
assign pad_spi_cs0_oen  = 1'b0;
assign pad_spi_cs1_out  = cs_sel & ena;
assign pad_spi_cs1_oen  = 1'b0;

always @(posedge clk_i or negedge rst_n_i) begin
    if( !rst_n_i ) begin
        spi_cr <= 8'h0;
        spi_er <= 8'h0;
        cs_sel <= '0;
    end
    else if (wb_wr) begin
        if(adr_i[1:0] == 2'b00) begin
            spi_cr <= dat_i | 8'h10; // always is master
        end
        else if (adr_i[1:0] == 2'b11) begin
            spi_er <= dat_i;
        end
        else if (adr_i[2] == 1'b0) begin
            cs_sel = '0;
        end
        else if (adr_i[2] == 2'b1) begin
            cs_sel = '1;
        end
    end
end

assign wfwe = wb_acc & (adr_i[1:0] == 2'b10) & we_i;
assign wfov = wb_acc & wffull;

always @(posedge clk_i) begin
    case (adr_i[1:0])
        2'b00:dat_o <= spi_cr;
        2'b01:dat_o <= spi_er;
        2'b10:dat_o <= rfdout;
        2'b11:dat_o <= spi_er; 
    endcase
end

assign rfre = wb_acc & (adr_i[1:0] == 2'b10) & ~we_i

//register decode 
logic spie = spi_cr[7];// interrupe en
logic spe  = spi_cr[6];// modue en
logic mstr = spi_cr[4];// master mode 
logic cpol = spi_cr[3];// cpol 
logic cpha = spi_cr[2];// cpha
logic spr  = spi_cr[1:0]; // div rate of clock

// logic spif = spi_sr[7];
// logic wcol = spi_sr[6];
// logic wffull  = spi_cr[3];
// logic wfempty = spi_cr[2];
// logic rffull  = spi_cr[1];
// logic rfempty = spi_cr[0];


// logic wffull ;
// logic wfempty;
// logic rffull ;
// logic rfempty;

assign spi_sr[7]= spif   ; 
assign spi_sr[6]= wcol   ;
assign spi_sr[5:4] = 2'b00;
assign spi_cr[3]= wffull ;
assign spi_cr[2]= wfempty;
assign spi_cr[1]= rffull ;
assign spi_cr[0]= rfempty;

logic [1:0] icnt = spi_er[7:6];
logic [1:0] espr = spi_er[1:0];

logic [3:0] spr_all = {espr,spr};// espr 
logic wr_spsr= wb_wr & (adr_i[1:0] == 2'b01);
logic spif   ;
logic wcol   ;

always @(posedge clk_i) begin
    if(~spe) spif <= 1'b0;
    else     spif <= (tirq | spif) & ~(wr_spsr & dat_i[7]) // write 1 as clear it
end

always @(posedge clk_i) begin
    if (~spe) begin
        wcol <= 1'b0;
    end else begin
        wcol <= (wfov | wcol) & ~(wr_spsr & dat_i[6]); 
    end
end

always @(posedge clk_i ) begin
    inta_o <= spif & spie;
end


// //titelink state
// logic wr_en;
// logic rd_en;
// logic [1:0] tilelink_state;
// logic [1:0] tilelink_state_next;

// assign a_ready = '1;
// assign wr_en = (a_valid) & (a_opcode == 3'd0);
// assign rd_en = (a_valid) & (a_opcode == 4'd4);

//fifo signal
logic fifo_clr;
assign fifo_clr = ~spe;

logic [7:0] wf_in;
logic [7:0] wf_out;
logic wf_wr_en;
logic wf_rd_en;

logic [7:0] rf_in;
logic [7:0] rf_out; 
logic rf_wr_en;
logic rf_rd_en;

spi_fifo4 write_buffer(
    .clk  (clk_i),
    .rst  (rst_n_i),
    .din  (dat_i),
    .wr_en(wfwe),
    .rd_en(wfre),
    .dout (wfdout),
    .clr  (fifo_clr),
    .full (wffull),
    .empty(wfempty)
);

spi_fifo4 read_buffer(
    .clk  (clk_i),
    .rst  (rst_n_i),
    .din  (tx_reg),
    .wr_en(rfwe),
    .rd_en(rfre),
    .dout (rfdout),
    .clr  (fifo_clr),
    .full (rffull),
    .empty(rfempty)
);

//SCLK  GEN 

always @(posedge clk_i ) begin
    if(spe & (|clkcnt & |state)) begin
        clkcnt <= clkcnt - 11'h1;
    end
    else  begin
        case (spr_all)
            4'b0000:clkcnt <= 12'h0 ;
            4'b0001:clkcnt <= 12'h1 ;
            4'b0010:clkcnt <= 12'h3 ;
            4'b0011:clkcnt <= 12'hf ;
            4'b0100:clkcnt <= 12'h1f ;
            4'b0101:clkcnt <= 12'h7 ;
            4'b0110:clkcnt <= 12'h3f ;
            4'b0111:clkcnt <= 12'h7f ;
            4'b1000:clkcnt <= 12'hff ;
            4'b1001:clkcnt <= 12'h1ff ;
            4'b1010:clkcnt <= 12'h3ff; 
            4'b1011:clkcnt <= 12'h7ff;
        endcase
    end
end

always @(posedge clk_i) begin
    if (~spe) begin
        state <= 2'b00; // idle;
        bcnt  <= 3'h0;
        tx_reg <= 8'h00;
        wfre <= 1'b0;
        rfwe <= 1'b0;
        sclk_o <= 1'b0;
    end    
    else begin
        wfre <= 1'b0;
        rfwe <= 1'b0;

        case (state)
            2'b00:begin
                bcnt   <= 3'h7;
                tx_reg <= wfdout;
                sclk_o <= cpol;
                if(~wfempty) begin 
                    wfre <= 1'b1;
                    state <= 2'b01;
                    if(cpha) begin
                        sclk_o <= ~sclk_o;
                    end
                end 
            end
            2'b01:begin
                if(ena) begin
                    sclk_o <= ~sclk_o;
                    state <= 2'b11;
                end
            end
            2'b11:begin
                if(ena) begin
                    tx_reg <= {tx_reg[6:0],miso_i};
                    bcnt   <= bcnt -3'h1;
                    if(~(|bcnt)) begin
                        state <= 2'b00;
                        sclk_o <= cpol;
                        rfwe <= 1'b1;
                    end else begin
                        state <= 2'b01;
                        sclk_o <= ~sclk_o;
                    end
                end
            end
            2'b10:begin
                state <= 2'b00;               
            end
        endcase
    end
end

logic [1:0] tcnt;
always @(posedge clk_i) begin
    if(~spe) begin
        tcnt <= icnt;
    end
    else if (rfwe) begin
        if(|tcnt) begin
            tcnt <= tcnt - 2'h1;
        end
        else begin
            tcnt <= icnt;
        end
    end
end

assign tirq = ~|tcnt & rfwe;




    
endmodule