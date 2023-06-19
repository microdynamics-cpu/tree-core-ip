interface apb_if #(
    parameter APB_ADDR_WIDTH = 32,
    parameter APB_DATA_WIDTH = 32
) (
    input logic pclk,
    input logic presetn
);

  logic [ APB_ADDR_WIDTH-1:0] paddr;
  logic [ APB_DATA_WIDTH-1:0] pwdata;
  logic                       pwrite;
  logic                       psel;
  logic                       penable;
  logic [ APB_DATA_WIDTH-1:0] prdata;
  logic                       pready;
  logic                       pslverr;

  modport slave(
      input paddr,
      input pwdata,
      input pwrite,
      input psel,
      input penable,
      output prdata,
      output pready,
      output pslverr
  );

  modport master(
      output paddr,
      output pwdata,
      output pwrite,
      output psel,
      output penable,
      input prdata,
      input pready,
      input pslverr
  );

endinterface
