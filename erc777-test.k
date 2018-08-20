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

  rule #this => 5

  rule #addresses => 0 1 2 3 4 5 6 7 8 9 .Addresses // NOTE: 0 1 2 ... 2^160 - 1

  rule #defaultOperators => SetItem(8) SetItem(9)

  rule #senderHook ( _ ) => 6

  rule #receiverHook ( _ ) => 7

  rule #maxNumber => 1024 // NOTE: 2^256 - 1

  rule #isContractAddress ( _ ) => true

endmodule
