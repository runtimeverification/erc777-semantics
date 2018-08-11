module ERC777

configuration
<erc777>
  <k> $PGM:K </k>
  <balances> .Map </balances> // holder -> balance
  <operators> .Map </operators> // operator -> 2^holder
  <hooks> .Map </hooks> // holder -> (hookSender, hookReceiver)
  <log> .List </log> // event*
</erc777>

////

rule <k> init ( DefaultOperators )
      => initBalances ( #max )
      ~> initOperators ( #max )
      ~> initHooks ( #max )
      ~> initDefaultOperators ( DefaultOperators )
     ... </k>
     <defaultOperators> .Set => DefaultOperators </defaultOperators>

rule <k> initBalances ( Holder => Holder -Int 1 ) ... </k>
     <balances> Balances => Balances [ Holder <- 0 ] </balances>
     requires Holder >Int 0

rule <k> initBalances ( Holder ) => . ... </k>
     <balances> Balances => Balances [ Holder <- 0 ] </balances>
     requires Holder ==Int 0

rule <k> initOperators ( Holder => Holder -Int 1 ) ... </k>
     <operators> Operators => Operators [ Holder <- { Holder } ] </hooks>
     requires Holder >Int 0

rule <k> initOperators ( Holder ) => . ... </k>
     <operators> Operators => Operators [ Holder <- { Holder } ] </hooks>
     requires Holder ==Int 0

rule <k> initHooks ( Holder => Holder -Int 1 ) ... </k>
     <hooks> Hooks => Hooks [ Holder <- ( None , None ) ] </hooks>
     requires Holder >Int 0

rule <k> initHooks ( Holder ) => . ... </k>
     <hooks> Hooks => Hooks [ Holder <- ( None , None ) ] </hooks>
     requires Holder ==Int 0

rule <k> initDefaultOperators ( DefaultOperator DefaultOperators ) => initDefaultOperators ( DefaultOperators ) ... </k>
     <operators> ... DefaultOperator |-> ( _ => #top ) ... </operators>

rule <k> initDefaultOperators ( .DefaultOperators ) => . ... </k>

rule #top => #rangeSet ( 0 .. #max )

rule #max => #pow256 -Int 1

////

rule <k> totalSupply ( ) => #sum ( values(Balances) ) ... </k>
     <balances> Balances </balances>

////

rule <k> isOperatorFor ( Operator , Holder ) => Holder in Holders ... </k>
     <operators> ... Operator |-> Holders ... </operators>

////

rule <k> Holder . authorizeOperator ( Operator ) => . ... </k>
     <operators> ... Operator |-> ( Holders => Holders U { Holder } ) ... </operators>
     <log> Log => Log AuthorizedOperator ( Operator , Holder ) </log>

////

rule <k> Holder . revokeOperator ( Operator ) => . ... </k>
     <operators> ... Operator |-> ( Holders => Holders \ { Holder } ) ... </operators>
     <log> Log => Log RevokedOperator ( Operator , Holder ) </log>

////

rule <k> Holder .         send (          To , Value , Data      )
      => Holder . operatorSend ( Holder , To , Value , Data , "" ) ... </k>

////

rule <k> Operator . operatorSend ( From     , To , Value , Data , OperatorData )
      => Operator . operatorSend ( Operator , To , Value , Data , OperatorData )
     requires From ==Int 0

rule <k> Operator . operatorSend ( From , To , Value , Data , OperatorData )
      => #check ( Operator , From , To , Value , Data )
      ~> #hookFrom ( Operator , From , To , Value , Data , OperatorData )
      ~> #update ( From , To , Value )
      ~> #hookTo ( Operator , From , To , Value , Data , OperatorData )
      ~> #log ( Operator , From , To , Value , Data , OperatorData ) ... </k>
     requires From =/=Int 0

rule #check ( Operator , From , To , Value , Data ) => .
     #if       isOperatorFor ( Operator , From )
       andBool To =/=Int 0
       andBool #isMultipleOf ( Value , Granularity )
     #then .
     #else #revert
     #fi

rule <k> #hookFrom ( Operator , From , To , Value , Data , OperatorData )
      => Token . #call ( Hook , Operator , From , To , Value , Data , OperatorData ) ... </k>
     <hooks> ... From |-> ( Some(Hook) , _ ) ... </hooks>

rule <k> #hookFrom ( Operator , From , To , Value , Data , OperatorData ) => . ... </k>
     <hooks> ... From |-> ( None , _ ) ... </hooks>

rule <k> #hookTo ( Operator , From , To , Value , Data , OperatorData )
      => Token . #call ( Hook , Operator , From , To , Value , Data , OperatorData ) ... </k>
     <hooks> ... To |-> ( _ , Some(Hook) ) ... </hooks>

rule <k> #hookTo ( Operator , From , To , Value , Data , OperatorData )
      => #if #isContractAddress ( To )
         #then #revert
         #else .
         #fi ... </k>
     <hooks> ... To |-> ( _ , None ) ... </hooks>

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
