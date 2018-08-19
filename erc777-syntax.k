require "erc777-sorts.k"

module ERC777-SYNTAX

  imports ERC777-SORTS
  imports BOOL-SYNTAX

  //
  // Token API
  //

  syntax String ::= name ( )
                  | symbol ( )

  syntax Number ::= totalSupply ( )
                  | balanceOf ( Address )
                  | granularity ( )

  syntax Addresses ::= defaultOperators ( )

  syntax Bool ::= isOperatorFor ( Address , Address )

  syntax Cmd ::= authorizeOperator ( Address )
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

  syntax Number ::= allowance ( Address , Address )
                  | decimals ( )

  syntax Bool ::= approve ( Address , Number )
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

  syntax Stmt ::= Address ":" Cmd

  syntax Addresses ::= "#addresses" [function]

  syntax Address ::= #senderHook ( Address ) [function]
                   | #receiverHook ( Address ) [function]

  syntax Int ::= "#maxNumber" [function]

  syntax Address ::= "#this" [function]

  syntax Bool ::= #isContractAddress ( Address ) [function]

  syntax Stmt ::= #init ( )

endmodule
