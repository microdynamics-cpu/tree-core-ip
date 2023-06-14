`define REGS_MAX_ADR 2'd2

module apb_timer #(
    parameter APB_ADDR_WIDTH = 12,
    parameter TIM_NUM        = 2
) (
    input  logic                      pclk_i,
    input  logic                      presetn_i,
    input  logic [APB_ADDR_WIDTH-1:0] paddr_i,
    input  logic [              31:0] pwdata_i,
    input  logic                      pwrite_i,
    input  logic                      psel_i,
    input  logic                      penable_i,
    output logic [              31:0] prdata_o,
    output logic                      pready_o,
    output logic                      pslverr_o,

    output logic [(TIM_NUM * 2) - 1:0] irq_o
);

  logic [TIM_NUM-1:0] psel_int, pready, pslverr;
  logic [$clog2(TIM_NUM) - 1:0]       slave_address_int;
  logic [          TIM_NUM-1:0][31:0] prdata;

  assign slave_address_int = paddr_i[$clog2(TIM_NUM)+`REGS_MAX_ADR+1:`REGS_MAX_ADR+2];

  always_comb begin
    psel_int                    = '0;
    psel_int[slave_address_int] = psel_i;
  end

  always_comb begin
    if (psel_int != '0) begin
      prdata_o  = prdata[slave_address_int];
      pready_o  = pready[slave_address_int];
      pslverr_o = pslverr[slave_address_int];
    end else begin
      prdata_o  = '0;
      pready_o  = 1'b1;
      pslverr_o = 1'b0;
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
          .psel_i   (psel_int[i]),
          .penable_i(penable_i),
          .prdata_o (prdata[i]),
          .pready_o (pready[i]),
          .pslverr_o(pslverr[i]),
          .irq_o    (irq_o[2*i+1 : 2*i])
      );
    end
  endgenerate
endmodule

