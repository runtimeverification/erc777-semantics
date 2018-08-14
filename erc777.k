require "erc777-syntax.k"

module ERC777

  imports ERC777-SYNTAX
  imports BOOL

  configuration
     <ERC777>
       <k> $PGM:K </k>
       <balances> .Map </balances> // holder -> balance
       <operators> .Map </operators> // holder -> 2^operator
       <senderHooks> .Map </senderHooks> // holder -> senderHook
       <receiverHooks> .Map </receiverHooks> // holder -> receiverHook
       <log> Events: </log> // event*
       <atomic> .K </atomic>
     </ERC777>

  ////

  rule <k> #init ( ) => . ... </k>
       <balances>      _ => #initBalances      ( #addresses )                     </balances>
       <operators>     _ => #initOperators     ( #addresses , #defaultOperators ) </operators>
       <senderHooks>   _ => #initSenderHooks   ( #addresses )                     </senderHooks>
       <receiverHooks> _ => #initReceiverHooks ( #addresses )                     </receiverHooks>

  rule #initBalances ( Holder Holders ) => Holder |-> 0  #initBalances ( Holders )
  rule #initBalances ( .Addresses ) => .Map

  rule #initOperators ( Holder Holders , DefaultOperators ) => Holder |-> SetItem(Holder) DefaultOperators  #initOperators ( Holders , DefaultOperators )
  rule #initOperators ( .Addresses , _ ) => .Map

  rule #initSenderHooks ( Holder Holders ) => Holder |-> #senderHook ( Holder )  #initSenderHooks ( Holders )
  rule #initSenderHooks ( .Addresses ) => .Map

  rule #initReceiverHooks ( Holder Holders ) => Holder |-> #receiverHook ( Holder )  #initReceiverHooks ( Holders )
  rule #initReceiverHooks ( .Addresses ) => .Map

  ////

  rule name ( ) => #name

  rule symbol ( ) => #symbol

  rule granularity ( ) => #granularity

  rule defaultOperators ( ) => #defaultOperators

  ////

  rule <k> totalSupply ( ) => #sum ( values(Balances) ) ... </k>
       <balances> Balances </balances>

  ////

  rule <k> balanceOf ( Holder ) => Balance ... </k>
       <balances> ... Holder |-> Balance ... </balances>

  ////

  rule <k> isOperatorFor ( Operator , Holder ) => Operator in Operators ... </k>
       <operators> ... Holder |-> Operators:Set ... </operators>

  ////

  rule <k> Holder : authorizeOperator ( Operator ) => . ... </k>
       <operators> ... Holder |-> ( Operators => Operators SetItem(Operator) ) ... </operators>
       <log> Log => Log AuthorizedOperator ( Operator , Holder ) </log>
       requires Holder =/=Address Operator

  /*
  // May reject when authorizing an already-authorized-address
  rule <k> Holder : authorizeOperator ( Operator ) => #revert ... </k>
       <operators> ... Holder |-> Operators ... </operators>
       requires Holder =/=Address Operator
        andBool Operator in Operators
  */

  rule <k> Holder : authorizeOperator ( Operator ) => #revert ... </k>
       requires Holder ==Address Operator

  ////

  rule <k> Holder : revokeOperator ( Operator ) => . ... </k>
       <operators> ... Holder |-> ( Operators => Operators -Set SetItem(Operator) ) ... </operators>
       <log> Log => Log RevokedOperator ( Operator , Holder ) </log>
       requires Holder =/=Address Operator

  /*
  // May reject when revoking a non-authorized-address
  rule <k> Holder : revokeOperator ( Operator ) => #revert ... </k>
       <operators> ... Holder |-> Operators ... </operators>
       requires Holder =/=Address Operator
        andBool Operator in Operators
  */

  rule <k> Holder : revokeOperator ( Operator ) => #revert ... </k>
       requires Holder ==Address Operator

  ////

  rule <k> Holder :         send (          To , Value , Data         )
        => Holder : operatorSend ( Holder , To , Value , Data , .Data ) ... </k>

  ////

  rule <k> Operator : operatorSend ( From     , To , Value , Data , OperatorData )
        => Operator : operatorSend ( Operator , To , Value , Data , OperatorData ) ... </k>
       requires From ==Address #zero

  rule <k> Operator : operatorSend ( From , To , Value , Data , OperatorData )
        => #atomicBegin
        ~> #ensure ( #check ( Operator , From , To , Value , Data ) )
//      ~> #hookFrom ( Operator , From , To , Value , Data , OperatorData )
//      ~> #update ( From , To , Value )
//      ~> #hookTo ( Operator , From , To , Value , Data , OperatorData )
//      ~> #log ( Operator , From , To , Value , Data , OperatorData )
        ~> #atomicEnd ... </k>
       requires From =/=Address #zero

  rule #check ( Operator , From , To , Value , Data ) =>
       #and ( isOperatorFor ( Operator , From )
            , To =/=Address #zero
            , #isMultipleOf ( Value , #granularity )
            )

/*
  rule <k> #hookFrom ( Operator , From , To , Value , Data , OperatorData )
        => Token . #call ( Hook , Operator , From , To , Value , Data , OperatorData ) ... </k>
       <senderHooks> ... From |-> Hook ... </senderHooks>
       requires Hook >Int 0

  rule <k> #hookFrom ( Operator , From , To , Value , Data , OperatorData )
        => #mayRevert ... </k>
       <senderHooks> ... From |-> Hook ... </senderHooks>
       requires Hook ==Int 0

  rule <k> #hookTo ( Operator , From , To , Value , Data , OperatorData )
        => Token . #call ( Hook , Operator , From , To , Value , Data , OperatorData ) ... </k>
       <receiverHooks> ... To |-> Hook ... </receiverHooks>
       requires Hook >Int 0

  rule <k> #hookTo ( Operator , From , To , Value , Data , OperatorData )
        => #ite ( #isContractAddress ( To ) , #revert , #mayRevert ) ... </k>
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
*/

  //
  // Utils
  //

//rule #isMultipleOf ( Value , Granularity ) => Value /Int Granularity *Int Granularity ==Int Value

  rule #ensure ( B:Bool ) => .        requires B
  rule #ensure ( B:Bool ) => #revert  requires notBool B

  rule #ite ( B:Bool , T , F ) => T  requires B
  rule #ite ( B:Bool , T , F ) => F  requires notBool B

  rule #and ( A:Bool , B:Bool          ) => A andBool B
  rule #and ( A:Bool , B:Bool , C:Bool ) => A andBool B andBool C

  rule #mayRevert => #revert
  rule #mayRevert => .

  rule <k> #revert ... </k>
       <balances> _ => Balances </balances>
       <operators> _ => Operators </operators>
       <senderHooks> _ => SenderHooks </senderHooks>
       <receiverHooks> _ => ReceiverHooks </receiverHooks>
       <log> _ => Log </log>
       <atomic> #snapshot ( Balances , Operators , SenderHooks , ReceiverHooks , Log ) => .K </atomic>

  rule <k> #atomicBegin => . ... </k>
       <balances> Balances </balances>
       <operators> Operators </operators>
       <senderHooks> SenderHooks </senderHooks>
       <receiverHooks> ReceiverHooks </receiverHooks>
       <log> Log </log>
       <atomic> .K => #snapshot ( Balances , Operators , SenderHooks , ReceiverHooks , Log ) </atomic>

  rule <k> #atomicEnd => . ... </k>
       <atomic> _ => .K </atomic>

endmodule
