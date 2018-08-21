require "erc777.k"
require "imp.k"

module ERC777-TEST-SYNTAX

  imports IMP
  imports ERC777-SYNTAX
  imports DOMAINS-SYNTAX

endmodule

module ERC777-TEST

  imports ERC777-TEST-SYNTAX
  imports ERC777
  imports DOMAINS

  // Parameters

  rule #name => "RVToken"

  rule #symbol => "RVT"

  rule #granularity => 1

  // Test Setup

  rule #this => 7 //todo replace with caller from imp.k

  rule #defaultOperators => SetItem(8) SetItem(9)

  rule #maxNumber => 1024 // NOTE: 2^256 - 1

  rule #isContractAddress ( _ ) => true

endmodule
