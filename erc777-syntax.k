require "erc777-sorts.k"

module ERC777-SYNTAX

  imports BOOL
  imports STRING
  imports MAP
  imports SET
  imports ERC777-SORTS

  //
  // Token API
  //

  syntax Function ::= name ( )                              // String
                    | symbol ( )                            // String
                    | totalSupply ( )                       // Number
                    | balanceOf ( Address )                 // Number
                    | granularity ( )                       // Number
                    | defaultOperators ( )                  // Addresses
                    | isOperatorFor ( Address , Address )   // Bool
                    | authorizeOperator ( Address )
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

  syntax Exp ::= Address ":" Function

  syntax Exp ::= #init ( )

  syntax Map ::= #initBalances ( Addresses ) [function]
               | #initOperators ( Addresses , Set ) [function]
               | #initSenderHooks ( Addresses ) [function]
               | #initReceiverHooks ( Addresses ) [function]

  syntax Address ::= #senderHook ( Address ) [function]
                   | #receiverHook ( Address ) [function]

  syntax Addresses ::= "#addresses" [function]

  syntax Int ::= #sum ( List ) [function]

  syntax Bool ::= Address  "==Address" Address [function]
                | Address "=/=Address" Address [function]

  syntax KItem ::= "#revert"

endmodule
