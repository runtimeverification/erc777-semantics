require "erc777-sorts.k"

module ERC777-SYNTAX

  imports ERC777-SORTS
  imports BOOL-SYNTAX

  //
  // ERC777Token
  //

  syntax Exp ::= AExp | BExp | Set

  syntax Exp ::= name ( )
               | symbol ( )

  syntax AExp ::= totalSupply ( )
                | balanceOf ( AExp ) [strict]
                | granularity ( )

  syntax Exp ::= defaultOperators ( )

  syntax BExp ::= isOperatorFor ( AExp , AExp ) [strict]

  syntax Stmt ::= authorizeOperator ( AExp )                        [strict]
                | revokeOperator ( AExp )                           [strict]
                | send ( AExp , AExp , Data )                       [strict]
                | operatorSend ( AExp , AExp , AExp , Data , Data ) [strict]
                | burn ( AExp )                                     [strict]
                | operatorBurn ( AExp , AExp , Data )               [strict]

  syntax Event ::= Sent ( Address , Address , Address , Number , Data , Data )
                 | Minted ( Address , Address , Number , Data , Data )
                 | Burned ( Address , Address , Number , Data )
                 | AuthorizedOperator ( Address , Address )
                 | RevokedOperator ( Address , Address )

  //
  // ERC777TokensSender
  //

  syntax Stmt ::= AExp "." "tokensToSend" "(" AExp "," AExp "," AExp "," AExp "," Data "," Data ")" [strict]

  //
  // ERC777TokensRecipent
  //

  syntax Stmt ::= AExp "." "tokensReceived" "(" AExp "," AExp "," AExp "," AExp "," Data "," Data ")" [strict]

  //
  // ERC20 compatibility
  //

  // uint256
  syntax AExp ::= allowance ( AExp , AExp ) [strict]
                | decimals ( )

  // bool
  syntax BExp ::= approve ( AExp , AExp )             [strict]
                | transfer ( AExp , AExp )            [strict]
                | transferFrom ( AExp , AExp , AExp ) [strict]
                | "revert"

  syntax Event ::= Transfer ( Address , Address , Number)
                 | Approval ( Address , Address , Number)

  //
  // Semantics Internal
  //

  syntax Exp ::= Event
               | Number | Address | Data
               | Bool | String

  syntax Int ::= "#MAXVALUE"  [function]

  /* Arguments: accounts
  */
  syntax Stmt ::= #init ( Addresses )

  /* Arguments: accounts, accounts again. An auxiliary function for #init
  */
  syntax Stmt ::= #initAccounts ( Addresses , Addresses )

  /* Initialzies the content of <allowances> for the given address. Related to ERC20 only.
  */
  syntax Stmt ::= #initAllowances ( Address     //the address to initialzie
                                  , Addresses   //all the other known addresses.
                                  )

endmodule
