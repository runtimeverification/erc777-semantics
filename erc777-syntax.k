require "erc777-sorts.k"

module ERC777-SYNTAX

  imports ERC777-SORTS
  imports BOOL-SYNTAX

  //
  // Token API
  //

  // String
  syntax Exp ::= AExp | BExp

  syntax Exp ::= name ( )
               | symbol ( )

  // Number
  syntax AExp ::= totalSupply ( )
               | balanceOf ( AExp )
               | granularity ( )

  // Addresses
  syntax Exp ::= defaultOperators ( )

  // Bool
  syntax BExp ::= isOperatorFor ( AExp , AExp )

  syntax Stmt ::= authorizeOperator ( AExp )
                | revokeOperator ( AExp )
                | send ( AExp , AExp , Data )
                | operatorSend ( AExp , AExp , AExp , Data , Data )
                | burn ( AExp )
                | operatorBurn ( AExp , AExp , Data )

  syntax Event ::= Sent ( Address , Address , Address , Number , Data , Data )
                 | Minted ( Address , Address , Number , Data , Data )
                 | Burned ( Address , Address , Number , Data )
                 | AuthorizedOperator ( Address , Address )
                 | RevokedOperator ( Address , Address )

  //
  // ERC20 compatibility
  //

  // Number
  syntax AExp ::= allowance ( AExp , AExp )
               | decimals ( )

  // Bool
  syntax BExp ::= approve ( AExp , AExp )
               | transfer ( AExp , AExp )
               | transferFrom ( AExp , AExp , AExp )
               | "throw"

  syntax Event ::= Transfer ( Address , Address , Number)
                 | Approval ( Address , Address , Number)


  //
  // Token Parameters
  //

  syntax String ::= "#name"   [function]
                  | "#symbol" [function]

  syntax Number ::= "#granularity" [function]

  syntax Set ::= "#defaultOperators" [function]

  //
  // Semantics Internal
  //

  syntax Exp ::= Event
               | Number | Address | Data
               | Bool | String

  syntax Addresses ::= "#addresses" [function]

  syntax Address ::= #senderHook ( Address ) [function]
                   | #receiverHook ( Address ) [function]

  syntax Int ::= "#maxNumber" [function]

  syntax Address ::= "#this" [function]

  syntax Bool ::= #isContractAddress ( Address ) [function]

  syntax Stmt ::= #init ( )
                | #initAccounts ( Addresses , Addresses )
                | #initAllowances ( Address , Addresses )

endmodule
