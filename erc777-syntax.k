require "erc777-sorts.k"

module ERC777-SYNTAX

  imports ERC777-SORTS
  imports BOOL-SYNTAX

  //
  // Token API
  //

  syntax Exp ::= name ( )                              // String
               | symbol ( )                            // String
               | totalSupply ( )                       // Number
               | balanceOf ( Address )                 // Number
               | granularity ( )                       // Number
               | defaultOperators ( )                  // Addresses
               | isOperatorFor ( Address , Address )   // Bool

  syntax Cmd ::= authorizeOperator ( Address )
               | revokeOperator ( Address )
               | send ( Address , Number , Data )
               | operatorSend ( Address , Address , Number , Data , Data )
               | burn ( Number , Data )
               | operatorBurn ( Address , Number , Data , Data )

  syntax Event ::= Sent ( Address , Address , Address , Number , Data , Data )
                 | Minted ( Address , Address , Number , Data )
                 | Burned ( Address , Address , Number , Data , Data )
                 | AuthorizedOperator ( Address , Address )
                 | RevokedOperator ( Address , Address )

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

  syntax Stmt ::= #init ( )

endmodule
