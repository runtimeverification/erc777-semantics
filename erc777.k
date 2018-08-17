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
       <caller> 0 </caller>
       <k> $PGM:K </k>
       <accounts>
         <account multiplicity="*">
           <id> 0 </id>
           <balance> 0 </balance>
           <operators> .Set </operators> // holder -> 2^operator
           <senderHook> 0 </senderHook> // holder -> senderHook
           <receiverHook> 0 </receiverHook> // holder -> receiverHook
           <allowances>
             <allow multiplicity="*">
               <spender> 0 </spender>
               <amount> 0 </amount>
             </allow>
           </allowances>
         </account>
       </accounts>
       <supply> 0 </supply>
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

  rule <k> totalSupply ( ) => TotalSupply ... </k>
       <supply> TotalSupply </supply>

  rule <k> balanceOf ( Holder ) => Balance ... </k>
       <id> Holder </id>
       <balance> Balance </balance>

  rule <k> isOperatorFor ( Operator , Holder ) => Operator in Operators ... </k>
       <id> Holder </id>
       <operators> Operators:Set </operators>

  //
  // authorizeOperator / revokeOperator
  //

  // Non-deterministically allow to authorize an already-authorized-operator
  rule <k> authorizeOperator ( Operator ) => . ... </k>
       <caller> Holder </caller>
       <id> Holder </id>
       <operators> Operators => Operators SetItem(Operator) </operators>
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
  rule <k> authorizeOperator ( Operator ) => #revert ... </k>
       <caller> Holder </caller>
       requires Holder ==Int Operator

  ////

  // Non-deterministically allow to revoke a non-authorized-operator
  rule <k> revokeOperator ( Operator ) => . ... </k>
       <caller> Holder </caller>
       <id> Holder </id>
       <operators> Operators => Operators -Set SetItem(Operator) </operators>
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
  rule <k> revokeOperator ( Operator ) => #revert ... </k>
       <caller> Holder </caller>
       requires Holder ==Int Operator

  //
  // send / operatorSend
  //

  rule <k>         send (          To , Value , Data      )
        => operatorSend ( Holder , To , Value , Data , "" ) ... </k>
       <caller> Holder </caller>

  ////

  // 'From == 0' implies 'From == Operator' -- TODO: what's the intuition? may be vulnerable
  rule <k> operatorSend ( From     , To , Value , Data , OperatorData )
        => operatorSend ( Operator , To , Value , Data , OperatorData ) ... </k>
       <caller> Operator </caller>
       requires From ==Int 0

  rule <k> operatorSend ( From , To , Value , Data , OperatorData )
        => #atomicBegin
        ~> #ensure ( #check ( Operator , From , To , Value , Data ) )
//      ~> #hookFrom ( Operator , From , To , Value , Data , OperatorData )
        ~> #update ( From , To , Value )
//      ~> #hookTo ( Operator , From , To , Value , Data , OperatorData )
        ~> #log ( Operator , From , To , Value , Data , OperatorData )
        ~> #atomicEnd ... </k>
       <caller> Operator </caller>
       requires From =/=Int 0

  syntax Exp ::= #check ( Address , Address , Address , Number , Data )

  rule #check ( Operator , From , To , Value , Data )
    => #and ( isOperatorFor ( Operator , From )
            , To =/=Int 0
            , #isMultipleOf ( Value , #granularity )
            )

  syntax Stmt ::= #hookFrom ( Address , Address , Address , Number , Data , Data )

  rule <k> #hookFrom ( Operator , From , To , Value , Data , OperatorData )
        => #call ( #this , Hook , Operator , From , To , Value , Data , OperatorData ) ... </k>
       <id> From </id>
       <senderHook> Hook </senderHook>
       requires Hook =/=Int 0

  rule <k> #hookFrom ( Operator , From , To , Value , Data , OperatorData )
        => #mayRevert ... </k>
       <id> From </id>
       <senderHook> Hook </senderHook>
       requires Hook ==Int 0

  syntax Stmt ::= #hookTo ( Address , Address , Address , Number , Data , Data )

  rule <k> #hookTo ( Operator , From , To , Value , Data , OperatorData )
        => #call ( #this , Hook , Operator , From , To , Value , Data , OperatorData ) ... </k>
       <id> To </id>
       <receiverHook> Hook </receiverHook>
       requires Hook =/=Int 0

  rule <k> #hookTo ( Operator , From , To , Value , Data , OperatorData )
        => #ite ( #isContractAddress ( To ) , #revert , #mayRevert ) ... </k>
       <id> To </id>
       <receiverHook> Hook </receiverHook>
       requires Hook ==Int 0

  syntax Stmt ::= #update ( Address , Address , Number )

  rule <k> #update ( From , To , Value ) => . ... </k>
       <account>
         <id> From </id>
         <balance> ValueFrom => ValueFrom -Int Value </balance>
         ...
       </account>
       <account>
         <id> To </id>
         <balance> ValueTo => ValueTo +Int Value </balance>
         ...
       </account>
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

  syntax Stmt ::= #call ( Address , Address , Address , Address , Address , Number , Data , Data )

  // TODO: more fine-grained input
  rule #call ( _ , _ , _ , _ , _ , _ , _ , _ ) => #mayRevert


  //
  // ERC20 compatibility
  //

  // TODO; hooks
  // TODO; Check compatibility?

  rule <k> allowance(Owner, Spender) => Allowance ...</k>
       <id> Owner </id>
       <spender> Spender </spender>
       <amount> Allowance </amount>

  rule <k> decimals() => 18 </k>

  rule <k> approve(Spender, Allowance) => true ...</k>
       <caller> Owner </caller>
       <id> Owner </id>
       <spender> Spender </spender>
       <amount> _ => Allowance </amount>
       <log> Log => Log Approval(Owner, Spender, Allowance) </log>
    requires Allowance >=Int 0

  rule <k> approve(_, Allowance) => #revert ...</k>
    requires Allowance <Int 0

  rule <k> transfer(To, Value) => true ...</k>
       <caller> From </caller>
       <account>
         <id> From </id>
         <balance> BalanceFrom => BalanceFrom -Int Value </balance>
         ...
       </account>
       <account>
         <id> To </id>
         <balance> BalanceTo => BalanceTo +Int Value </balance>
         ...
       </account>
       <log> Log => Log Transfer(From, To, Value) </log>
    requires To =/=Int From    // sanity check
     andBool Value >=Int 0
     andBool Value <=Int BalanceFrom
     andBool BalanceTo +Int Value <=Int #maxNumber

  rule <k> transfer(From, Value) => true ...</k>
       <caller> From </caller>
       <id> From </id>
       <balance> BalanceFrom </balance>
       <log> Log => Log Transfer(From, From, Value) </log>
    requires Value >=Int 0
     andBool Value <=Int BalanceFrom

  rule <k> transfer(To, Value) => #revert ...</k>
       <caller> From </caller>
       <account>
         <id> From </id>
         <balance> BalanceFrom </balance>
         ...
       </account>
       <account>
         <id> To </id>
         <balance> BalanceTo </balance>
         ...
       </account>
    requires To =/=Int From   // sanity check
     andBool (Value <Int 0
      orBool Value >Int BalanceFrom
      orBool BalanceTo +Int Value >Int #maxNumber)

  rule <k> transfer(From, Value) => #revert ...</k>
       <caller> From </caller>
       <id> From </id>
       <balance> BalanceFrom </balance>
    requires Value <Int 0
      orBool Value >Int BalanceFrom

  rule <k> transferFrom(From, To, Value) => true ...</k>
       <caller> Caller </caller>
       <account>
         <id> From </id>
         <balance> BalanceFrom => BalanceFrom -Int Value </balance>
         <spender> Caller </spender>
         <amount> Allowance => Allowance -Int Value </amount>
         ...
       </account>
       <account>
         <id> To </id>
         <balance> BalanceTo => BalanceTo +Int Value </balance>
         ...
       </account>
       <log> Log => Log Transfer(From, To, Value) </log>
    requires To =/=Int From    // sanity check
     andBool Value >=Int 0
     andBool Value <=Int BalanceFrom
     andBool Value <=Int Allowance   // `transfer` does not check allowance
     andBool BalanceTo +Int Value <=Int #maxNumber

  rule <k> transferFrom(From, From, Value) => true ...</k>
       <caller> Caller </caller>
       <id> From </id>
       <balance> BalanceFrom </balance>
       <spender> Caller </spender>
       <amount> Allowance => Allowance -Int Value </amount>
       <log> Log => Log Transfer(From, From, Value) </log>
    requires Value >=Int 0
     andBool Value <=Int BalanceFrom
     andBool Value <=Int Allowance   // `transfer` does not check allowance

  rule <k> transferFrom(From, To, Value) => #revert ...</k>
       <caller> Caller </caller>
       <account>
         <id> From </id>
         <balance> BalanceFrom </balance>
         <spender> Caller </spender>
         <amount> Allowance </amount>
         ...
       </account>
       <account>
         <id> To </id>
         <balance> BalanceTo </balance>
         ...
       </account>
    requires To =/=Int From    // sanity check
     andBool (Value <Int 0
      orBool Value >Int BalanceFrom
      orBool Value >Int Allowance
      orBool BalanceTo +Int Value >Int #maxNumber)

  rule <k> transferFrom(From, From, Value) => #revert ...</k>
       <caller> Caller </caller>
       <id> From </id>
       <balance> BalanceFrom </balance>
       <spender> Caller </spender>
       <amount> Allowance </amount>
    requires Value <Int 0
      orBool Value >Int BalanceFrom
      orBool Value >Int Allowance   // `transfer` does not check allowance


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
       <accounts> _ => Accounts </accounts>
       <log> _ => Log </log>
       <atomic> #snapshot ( Accounts , Log ) => .K </atomic>

  syntax KItem ::= "#atomicBegin"
                 | "#atomicEnd"
                 | #snapshot ( K , EventLog )

  rule <k> #atomicBegin => . ... </k>
       <accounts> Accounts </accounts>
       <log> Log </log>
       <atomic> .K => #snapshot ( Accounts , Log ) </atomic>

  rule <k> #atomicEnd => . ... </k>
       <atomic> _ => .K </atomic>

endmodule
