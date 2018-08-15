module ERC777-SORTS-SIGNATURE

  syntax Number

  syntax Address

  syntax Addresses ::= Address Addresses | ".Addresses"

  syntax Data

  syntax Function

  syntax Event

  syntax EventLog ::= "Events:" | EventLog Event

endmodule

/*
 * An instantiation of sort signature -- this can be changed
 */
module ERC777-SORTS

  imports ERC777-SORTS-SIGNATURE
  imports INT-SYNTAX
  imports STRING-SYNTAX

  syntax Number ::= Int

  syntax Address ::= Int

  syntax Data ::= String

endmodule
