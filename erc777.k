require "erc777-syntax.k"

module ERC777

  imports ERC777-SYNTAX
  imports INT
  imports BOOL
  imports STRING
  imports MAP
  imports SET
  imports LIST

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

  //
  // Configuration initialization -- all addresses should be initialized
  // - parameterized by: #addresses, #defaultOperators, #senderHook, #receiverHook
  //

  rule <k> #init ( ) => . ... </k>
       <balances>      _ => #initBalances      ( #addresses )                     </balances>
       <operators>     _ => #initOperators     ( #addresses , #defaultOperators ) </operators>
       <senderHooks>   _ => #initSenderHooks   ( #addresses )                     </senderHooks>
       <receiverHooks> _ => #initReceiverHooks ( #addresses )                     </receiverHooks>

  syntax Map ::= #initBalances ( Addresses ) [function]
               | #initOperators ( Addresses , Set ) [function]
               | #initSenderHooks ( Addresses ) [function]
               | #initReceiverHooks ( Addresses ) [function]

  rule #initBalances ( Holder Holders ) => Holder |-> 0  #initBalances ( Holders )
  rule #initBalances ( .Addresses ) => .Map

  rule #initOperators ( Holder Holders , DefaultOperators ) => Holder |-> SetItem(Holder) DefaultOperators  #initOperators ( Holders , DefaultOperators )
  rule #initOperators ( .Addresses , _ ) => .Map

  rule #initSenderHooks ( Holder Holders ) => Holder |-> #senderHook ( Holder )  #initSenderHooks ( Holders )
  rule #initSenderHooks ( .Addresses ) => .Map

  rule #initReceiverHooks ( Holder Holders ) => Holder |-> #receiverHook ( Holder )  #initReceiverHooks ( Holders )
  rule #initReceiverHooks ( .Addresses ) => .Map

  //
  // Constant functions
  // - name, symbol, granularity, defaultOperators
  //

  rule name ( ) => #name

  rule symbol ( ) => #symbol

  rule granularity ( ) => #granularity

  rule defaultOperators ( ) => #defaultOperators

  //
  // View functions
  // - totalSupply, balanceOf, isOperatorFor
  //
  // Simplely defined, but non-trivial properties to be ensured by token implementations
  //

  rule <k> totalSupply ( ) => #sum ( values(Balances) ) ... </k>
       <balances> Balances </balances>

  rule <k> balanceOf ( Holder ) => Balance ... </k>
       <balances> ... Holder |-> Balance ... </balances>

  rule <k> isOperatorFor ( Operator , Holder ) => Operator in Operators ... </k>
       <operators> ... Holder |-> Operators:Set ... </operators>

  //
  // authorizeOperator / revokeOperator
  //

  // Non-deterministically allow to authorize an already-authorized-operator
  rule <k> Holder : authorizeOperator ( Operator ) => . ... </k>
       <operators> ... Holder |-> ( Operators => Operators SetItem(Operator) ) ... </operators>
       <log> Log => Log AuthorizedOperator ( Operator , Holder ) </log>
       requires Holder =/=Int Operator

/* FIXME: temporarily disable for quick testing
  // Non-deterministically reject to authorize an already-authorized-operator
  rule <k> Holder : authorizeOperator ( Operator ) => #revert ... </k>
       <operators> ... Holder |-> Operators:Set ... </operators>
       requires Holder =/=Int Operator
        andBool Operator in Operators
*/

  // Reject to authorize itself -- TODO: too strong??
  rule <k> Holder : authorizeOperator ( Operator ) => #revert ... </k>
       requires Holder ==Int Operator

  ////

  // Non-deterministically allow to revoke a non-authorized-operator
  rule <k> Holder : revokeOperator ( Operator ) => . ... </k>
       <operators> ... Holder |-> ( Operators => Operators -Set SetItem(Operator) ) ... </operators>
       <log> Log => Log RevokedOperator ( Operator , Holder ) </log>
       requires Holder =/=Int Operator

/* FIXME: temporarily disable for quick testing
  // Non-deterministically reject to revoke a non-authorized-operator
  rule <k> Holder : revokeOperator ( Operator ) => #revert ... </k>
       <operators> ... Holder |-> Operators:Set ... </operators>
       requires Holder =/=Int Operator
        andBool Operator in Operators
*/

  // Reject to revoke itself -- an address must be an operator for itself
  rule <k> Holder : revokeOperator ( Operator ) => #revert ... </k>
       requires Holder ==Int Operator

  //
  // send / operatorSend
  //

  rule <k> Holder :         send (          To , Value , Data      )
        => Holder : operatorSend ( Holder , To , Value , Data , "" ) ... </k>

  ////

  // 'From == 0' implies 'From == Operator' -- TODO: what's the intuition? may be vulnerable
  rule <k> Operator : operatorSend ( From     , To , Value , Data , OperatorData )
        => Operator : operatorSend ( Operator , To , Value , Data , OperatorData ) ... </k>
       requires From ==Int 0

  rule <k> Operator : operatorSend ( From , To , Value , Data , OperatorData )
        => #atomicBegin
        ~> #ensure ( #check ( Operator , From , To , Value , Data ) )
//      ~> #hookFrom ( Operator , From , To , Value , Data , OperatorData )
        ~> #update ( From , To , Value )
//      ~> #hookTo ( Operator , From , To , Value , Data , OperatorData )
        ~> #log ( Operator , From , To , Value , Data , OperatorData )
        ~> #atomicEnd ... </k>
       requires From =/=Int 0

  syntax Exp ::= #check ( Address , Address , Address , Number , Data )
  rule #check ( Operator , From , To , Value , Data )
    => #and ( isOperatorFor ( Operator , From )
            , To =/=Int 0
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
*/

  syntax Stmt ::= #update ( Address , Address , Number )

  rule <k> #update ( From , To , Value ) => . ... </k>
       <balances> ...
         From |-> ValueFrom -Int Value
         To   |-> ValueTo   +Int Value
       ... </balances>
       requires From =/=Int To
        andBool ValueFrom -Int Value >=Int 0
        andBool ValueTo   +Int Value  <Int #maxNumber

  rule <k> #update ( From , To , Value ) => . ... </k>
       requires From ==Int To

  syntax Stmt ::= #log ( Address , Address , Address , Number , Data , Data )

  rule <k> #log ( Operator , From , To , Value , Data , OperatorData ) => . ... </k>
       <log> Log => Log Sent ( Operator , From , To , Value , Data , OperatorData ) </log>

  syntax Exp ::= #isMultipleOf ( Number , Number )

  rule #isMultipleOf ( Value , Granularity ) => Value /Int Granularity *Int Granularity ==Int Value

  //
  // Utils
  //

  syntax Int ::= #sum ( List ) [function]

  rule #sum ( ListItem(I:Int) S ) => I +Int #sum ( S )
  rule #sum ( .List ) => 0

  syntax Stmt ::= #ensure ( Exp ) [strict]

  rule #ensure ( B:Bool ) => .        requires B
  rule #ensure ( B:Bool ) => #revert  requires notBool B

  syntax Stmt ::= #ite ( Exp , Stmt , Stmt ) [strict(1)]

  rule #ite ( B:Bool , T , F ) => T  requires B
  rule #ite ( B:Bool , T , F ) => F  requires notBool B

  syntax Exp ::= "#and" "(" Exp "," Exp ")"         [strict]
               | "#and" "(" Exp "," Exp "," Exp ")" [strict]

  rule #and ( A:Bool , B:Bool          ) => A andBool B
  rule #and ( A:Bool , B:Bool , C:Bool ) => A andBool B andBool C

  syntax Stmt ::= "#mayRevert"

  rule #mayRevert => #revert
  rule #mayRevert => .

  syntax Stmt ::= "#revert"

  rule <k> #revert ... </k>
       <balances> _ => Balances </balances>
       <operators> _ => Operators </operators>
       <senderHooks> _ => SenderHooks </senderHooks>
       <receiverHooks> _ => ReceiverHooks </receiverHooks>
       <log> _ => Log </log>
       <atomic> #snapshot ( Balances , Operators , SenderHooks , ReceiverHooks , Log ) => .K </atomic>

  syntax KItem ::= "#atomicBegin"
                 | "#atomicEnd"
                 | #snapshot ( Map , Map , Map , Map , EventLog )

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
