module ERC777

configuration
<erc777>
  <k> $PGM:K </k>
  <balances> #initBalances ( #holders ) </balances> // holder -> balance
  <operators> #initOperators ( #holders ,  #defaultOperators ) </operators> // holder -> 2^operator
  <senderHooks> #initSenderHooks ( #holders ) </senderHooks> // holder -> senderHook
  <receiverHooks> #initReceiverHooks ( #holders ) </receiverHooks> // holder -> receiverHook
  <log> .List </log> // event*
</erc777>

////

rule <k> totalSupply ( ) => #sum ( values(Balances) ) ... </k>
     <balances> Balances </balances>

////

rule <k> isOperatorFor ( Operator , Holder ) => Operator in Operators ... </k>
     <operators> ... Holder |-> Operators ... </operators>

////

rule <k> Holder . authorizeOperator ( Operator ) => . ... </k>
     <operators> ... Holder |-> ( Operators => Operators U { Operator } ) ... </operators>
     <log> Log => Log AuthorizedOperator ( Operator , Holder ) </log>
     requires Holder =/=Int Operator

rule <k> Holder . authorizeOperator ( Operator ) => #revert ... </k>
     requires Holder ==Int Operator

////

rule <k> Holder . revokeOperator ( Operator ) => . ... </k>
     <operators> ... Holder |-> ( Operators => Operators \ { Operator } ) ... </operators>
     <log> Log => Log RevokedOperator ( Operator , Holder ) </log>
     requires Holder =/=Int Operator

rule <k> Holder . revokeOperator ( Operator ) => #revert ... </k>
     requires Holder ==Int Operator

////

rule <k> Holder .         send (          To , Value , Data      )
      => Holder . operatorSend ( Holder , To , Value , Data , "" ) ... </k>

////

rule <k> Operator . operatorSend ( From     , To , Value , Data , OperatorData )
      => Operator . operatorSend ( Operator , To , Value , Data , OperatorData )
     requires From ==Int 0

rule <k> Operator . operatorSend ( From , To , Value , Data , OperatorData )
      => #require ( #check ( Operator , From , To , Value , Data ) )
      ~> #hookFrom ( Operator , From , To , Value , Data , OperatorData )
      ~> #update ( From , To , Value )
      ~> #hookTo ( Operator , From , To , Value , Data , OperatorData )
      ~> #log ( Operator , From , To , Value , Data , OperatorData ) ... </k>
     requires From =/=Int 0

rule #check ( Operator , From , To , Value , Data ) =>
     isOperatorFor ( Operator , From )
     andBool To =/=Int 0
     andBool #isMultipleOf ( Value , Granularity )

rule #require ( B ) => .        requires B
rule #require ( B ) => #revert  requires notBool B

rule <k> #hookFrom ( Operator , From , To , Value , Data , OperatorData )
      => Token . #call ( Hook , Operator , From , To , Value , Data , OperatorData ) ... </k>
     <senderHooks> ... From |-> Hook ... </senderHooks>
     requires Hook >Int 0

rule <k> #hookFrom ( Operator , From , To , Value , Data , OperatorData ) => . ... </k>
     <senderHooks> ... From |-> Hook ... </senderHooks>
     requires Hook ==Int 0

rule <k> #hookTo ( Operator , From , To , Value , Data , OperatorData )
      => Token . #call ( Hook , Operator , From , To , Value , Data , OperatorData ) ... </k>
     <receiverHooks> ... To |-> Hook ... </receiverHooks>
     requires Hook >Int 0

rule <k> #hookTo ( Operator , From , To , Value , Data , OperatorData )
      => #if #isContractAddress ( To )
         #then #revert
         #else .
         #fi ... </k>
     <receiverHooks> ... To |-> Hook ... </receiverHooks>
     requires Hook ==Int 0

rule <k> #update ( From , To , Value ) => . ... </k>
     <balances> ...
       From |-> ValueFrom -Int Value
       To   |-> ValueTo   +Int Value
     ... </balances>
     requires From =/=Int To
      andBool ValueFrom -Int Value >=Int 0
      andBool ValueTo   +Int Value  <Int #pow256

rule <k> #update ( From , To , Value ) => . ... </k>
     requires From ==Int To

rule <k> #log ( Operator , From , To , Value , Data , OperatorData ) => . ... </k>
     <log> Log => Log Sent ( Operator , From , To , Value , Data , OperatorData ) </log>

rule #isMultipleOf ( Value , Granularity ) => Value /Int Granularity *Int Granularity ==Int Value

endmodule
