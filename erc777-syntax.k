require "erc777-sorts.k"

module ERC777-SYNTAX

  imports ERC777-SORTS
  imports BOOL-SYNTAX

  //
  // Token API
  //

  // String
  syntax Exp ::= name ( )
               | symbol ( )

  // Number
  syntax Exp ::= totalSupply ( )
               | balanceOf ( Address )
               | granularity ( )

  // Addresses
  syntax Exp ::= defaultOperators ( )

  // Bool
  syntax Exp ::= isOperatorFor ( Address , Address )

  syntax Stmt ::= authorizeOperator ( Address )
                | revokeOperator ( Address )
                | send ( Address , Number , Data )
                | operatorSend ( Address , Address , Number , Data , Data )
                | burn ( Number )
                | operatorBurn ( Address , Number , Data )

  syntax Event ::= Sent ( Address , Address , Address , Number , Data , Data )
                 | Minted ( Address , Address , Number , Data , Data )
                 | Burned ( Address , Address , Number , Data )
                 | AuthorizedOperator ( Address , Address )
                 | RevokedOperator ( Address , Address )

  //
  // ERC20 compatibility
  //

  // Number
  syntax Exp ::= allowance ( Address , Address )
               | decimals ( )

  // Bool
  syntax Exp ::= approve ( Address , Number )
               | transfer ( Address , Number )
               | transferFrom ( Address , Address , Number )

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
