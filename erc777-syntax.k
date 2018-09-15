module ERC777-SYNTAX
  imports DOMAINS

  //
  // ERC777Token
  //

  syntax Address ::= Int
  syntax ValueType ::= Int

  syntax Data ::= String

  syntax AExp  ::= ValueType | Address
  syntax BExp  ::= Bool

  syntax Void ::= "#void"

  syntax Exp ::= AExp | BExp | SetExp | Data | Void

  syntax Exp ::= name ( )
               | symbol ( )

  syntax AExp ::= totalSupply ( )
                | balanceOf ( AExp ) [strict]
                | granularity ( )

  syntax SetExp ::= defaultOperators ( )
                  | Set

  syntax BExp ::= isOperatorFor ( AExp , AExp ) [strict]

  syntax Exp ::=  authorizeOperator ( AExp )                        [strict]
                | revokeOperator ( AExp )                           [strict]
                | send ( AExp , AExp , Data )                       [strict]
                | operatorSend ( AExp , AExp , AExp , Data , Data ) [strict]
                | burn ( AExp )                                     [strict]
                | operatorBurn ( AExp , AExp , Data )               [strict]
  // Minting: ERC777 does not define specific functions to mint tokens. Instead,
  // it specifies several rules that MUST be respected when minting tokens.
  // The definition of `mint` below is a minimal example of minting function
  // that conforms to those rules.
                | operatorMint ( AExp , //from
                                 AExp , //amount
                                 Data , //data
                                 Data   //operatorData.
                               ) [strict]

  syntax Event ::= Sent ( Address , Address , Address , ValueType , Data , Data )
                 | Minted ( Address , Address , ValueType , Data , Data )
                 | Burned ( Address , Address , ValueType , Data )
                 | AuthorizedOperator ( Address , Address )
                 | RevokedOperator ( Address , Address )

  syntax EventLog ::= "Events:" | EventLog Event

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

  syntax Event ::= Transfer ( Address , Address , ValueType)
                 | Approval ( Address , Address , ValueType)

endmodule
