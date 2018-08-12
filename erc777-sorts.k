module ERC777-SORTS

  syntax Number

  syntax Address

  syntax Addresses ::= Address Addresses | ".Addresses"

  syntax Data

  syntax Event

  syntax EventLog ::= "Events:" | EventLog Event

endmodule
