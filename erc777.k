module ERC777

configuration
<erc777>
  <k> $PGM:K </k>
  <balances> .Map </balances> // holder -> balance
  <operators> .Map </operators> // operator -> 2^holder
  <hooks> .Map </hooks> // holder -> (hookSender, hookReceiver)
  <log> .List </log> // event*
</erc777>

rule <k> isOperatorFor ( Operator , Holder ) => Holder in Holders ... </k>
     <operators> ... Operator |-> Holders ... </operators>

rule <k> Holder . authorizeOperator ( Operator ) => . ... </k>
     <operators> ... Operator |-> ( Holders => Holders U { Holder } ) ... </operators>
     <log> Log => Log AuthorizedOperator ( Operator , Holder ) </log>

rule <k> Holder . revokeOperator ( Operator ) => . ... </k>
     <operators> ... Operator |-> ( Holders => Holders \ { Holder } ) ... </operators>
     <log> Log => Log RevokedOperator ( Operator , Holder ) </log>

rule <k> Holder .         send (          To , Value , Data      )
      => Holder . operatorSend ( Holder , To , Value , Data , "" ) ... </k>

rule <k> Operator . operatorSend ( From , To , Value , Data , OperatorData )
      => #check ( Operator , From , To , Value , Data )
      ~> #hookFrom ( Operator , From , To , Value , Data , OperatorData )
      ~> #update ( From , To , Value )
      ~> #hookTo ( Operator , From , To , Value , Data , OperatorData )
      ~> #log ( Operator , From , To , Value , Data , OperatorData ) ... </k>

rule #check ( Operator , From , To , Value , Data ) => .
     requires isOperatorFor ( Operator , From )
      andBool To =/=Int 0
      andBool #isMultipleOf ( Value , Granularity )

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
