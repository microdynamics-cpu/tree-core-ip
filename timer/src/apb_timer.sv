`define REGS_MAX_ADR 2'd2

// fix 32b timer
module apb_timer #(
    parameter APB_ADDR_WIDTH = 32,
    parameter APB_DATA_WIDTH = 32,
    parameter TIM_NUM        = 2
) (
    input  logic                      pclk_i,
    input  logic                      presetn_i,
    input  logic [APB_ADDR_WIDTH-1:0] paddr_i,
    input  logic [APB_DATA_WIDTH-1:0] pwdata_i,
    input  logic                      pwrite_i,
    input  logic                      psel_i,
    input  logic                      penable_i,
    output logic [APB_DATA_WIDTH-1:0] prdata_o,
    output logic                      pready_o,
    output logic                      pslverr_o,

    output logic [(TIM_NUM * 2) - 1:0] irq_o
);

  logic [          TIM_NUM-1:0]       psel;
  logic [          TIM_NUM-1:0]       pready;
  logic [          TIM_NUM-1:0]       pslverr;
  logic [          TIM_NUM-1:0][31:0] prdata;
  logic [$clog2(TIM_NUM) - 1:0]       addr;

  assign addr = paddr_i[$clog2(TIM_NUM)+`REGS_MAX_ADR+1:`REGS_MAX_ADR+2];

  always_comb begin
    psel       = '0;
    psel[addr] = psel_i;
  end

  always_comb begin
    if (psel != '0) begin
      prdata_o  = prdata[addr];
      pready_o  = pready[addr];
      pslverr_o = pslverr[addr];
    end else begin
      prdata_o  = '0;
      pready_o  = 1'd1;
      pslverr_o = 1'd0;
    end
  end


  genvar i;
  generate
    for (i = 0; i < TIM_NUM; i++) begin : TIMER_GEN
      timer #(
          .APB_ADDR_WIDTH(APB_ADDR_WIDTH)
      ) u_timer (
          .pclk_i   (pclk_i),
          .presetn_i(presetn_i),
          .paddr_i  (paddr_i),
          .pwdata_i (pwdata_i),
          .pwrite_i (pwrite_i),
          .psel_i   (psel[i]),
          .penable_i(penable_i),
          .prdata_o (prdata[i]),
          .pready_o (pready[i]),
          .pslverr_o(pslverr[i]),
          .irq_o    (irq_o[2*i+1 : 2*i])
      );
    end
  endgenerate
endmodule

`define REGS_MAX_IDX 'd2
`define REG_TIMER 2'b00
`define REG_TIMER_CTRL 2'b01
`define REG_CMP 2'b10
`define PRESCALER_STARTBIT 'd3
`define PRESCALER_STOPBIT 'd5
`define ENABLE_BIT 'd0

module timer #(
    parameter APB_ADDR_WIDTH = 32,
    parameter APB_DATA_WIDTH = 32
) (
    input  logic                      pclk_i,
    input  logic                      presetn_i,
    input  logic [APB_ADDR_WIDTH-1:0] paddr_i,
    input  logic [APB_DATA_WIDTH-1:0] pwdata_i,
    input  logic                      pwrite_i,
    input  logic                      psel_i,
    input  logic                      penable_i,
    output logic [APB_DATA_WIDTH-1:0] prdata_o,
    output logic                      pready_o,
    output logic                      pslverr_o,
    output logic [               1:0] irq_o
);

  // APB register interface
  logic [`REGS_MAX_IDX-1:0] reg_addr;
  assign reg_addr  = paddr_i[`REGS_MAX_IDX+2:2];
  // APB logic: we are always ready to capture the data into our regs
  // not supporting transfare failure
  assign pready_o  = 1'b1;
  assign pslverr_o = 1'b0;
  // registers
  logic [0:`REGS_MAX_IDX][31:0] regs_q;
  logic [0:`REGS_MAX_IDX][31:0] regs_n;
  logic [           31:0]       cycle_counter_n;
  logic [           31:0]       cycle_counter_q;
  logic [            2:0]       prescaler_int;

  //irq
  always_comb begin
    irq_o = 2'b00;
    // overlow irq
    if (regs_q[`REG_TIMER] == 32'hFFFF_FFFF) irq_o[0] = 1'b1;
    // compare match irq if compare reg ist set
    if (regs_q[`REG_CMP] != 'b0 && regs_q[`REG_TIMER] == regs_q[`REG_CMP]) irq_o[1] = 1'b1;

  end

  assign prescaler_int = regs_q[`REG_TIMER_CTRL][`PRESCALER_STOPBIT:`PRESCALER_STARTBIT];
  // register write logic
  always_comb begin
    regs_n          = regs_q;
    cycle_counter_n = cycle_counter_q + 1;

    // reset timer after cmp or overflow
    if (irq_o[0] == 1'b1 || irq_o[1] == 1'b1) regs_n[`REG_TIMER] = 'b0;
    else if(regs_q[`REG_TIMER_CTRL][`ENABLE_BIT] && prescaler_int != 'b0 && prescaler_int == cycle_counter_q) // prescaler
      regs_n[`REG_TIMER] = regs_q[`REG_TIMER] + 1;  //prescaler mode
    else if (regs_q[`REG_TIMER_CTRL][`ENABLE_BIT] && prescaler_int == 'b0) // normal count mode
      regs_n[`REG_TIMER] = regs_q[`REG_TIMER] + 1;

    // reset prescaler cycle counter
    if (cycle_counter_q >= regs_q[`REG_TIMER_CTRL]) cycle_counter_n = 32'b0;

    // written from APB bus - gets priority
    if (psel_i && penable_i && pwrite_i) begin
      case (reg_addr)
        `REG_TIMER:      regs_n[`REG_TIMER] = pwdata_i;
        `REG_TIMER_CTRL: regs_n[`REG_TIMER_CTRL] = pwdata_i;
        `REG_CMP: begin
          regs_n[`REG_CMP]   = pwdata_i;
          regs_n[`REG_TIMER] = 32'b0;  // reset timer if compare register is written
        end
      endcase
    end
  end

  // APB register read logic
  always_comb begin
    prdata_o = 'd0;
    if (psel_i && penable_i && !pwrite_i) begin
      case (reg_addr)
        `REG_TIMER:      prdata_o = regs_q[`REG_TIMER];
        `REG_TIMER_CTRL: prdata_o = regs_q[`REG_TIMER_CTRL];
        `REG_CMP:        prdata_o = regs_q[`REG_CMP];
      endcase
    end
  end

  always_ff @(posedge pclk_i, negedge presetn_i) begin
    if (~presetn_i) begin
      regs_q          <= '{default: 32'd0};
      cycle_counter_q <= 32'd0;
    end else begin
      regs_q          <= regs_n;
      cycle_counter_q <= cycle_counter_n;
    end
  end
endmodule

