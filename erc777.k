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
       <caller> 0:Address </caller>
       <k> $PGM:K </k>
       <accounts>
         <account multiplicity="*">
           <id> 0:Address </id>
           <balance> 0:Number </balance>
           <operators> .Set </operators> // holder -> 2^operator
           <senderHook> 0:Address </senderHook> // holder -> senderHook
           <receiverHook> 0:Address </receiverHook> // holder -> receiverHook
           <allowances>
             <allow multiplicity="*">
               <spender> 0:Address </spender>
               <amount> 0:Number </amount>
             </allow>
           </allowances>
         </account>
       </accounts>
       <supply> 0:Number </supply>
       <log> Events: </log> // event*
       <atomic> .K </atomic>
     </ERC777>

  //
  // Configuration initialization -- all addresses should be initialized
  // - parameterized by: #addresses, #defaultOperators, #senderHook, #receiverHook

  rule <k> #init() => #initAccounts(#addresses, #addresses) ... </k>

  rule <k> #initAccounts(Holder Rest, Accounts)
        => #initAllowances(Holder, Accounts) ~> #initAccounts(Rest, Accounts) ... </k>
       <accounts> (.Bag =>
         <account>
           <id> Holder </id>
           <balance> 0 </balance>
           <operators> SetItem(Holder) #defaultOperators </operators>
           <senderHook> #senderHook(Holder) </senderHook>
           <receiverHook> #receiverHook(Holder) </receiverHook>
           <allowances> .Bag </allowances>
         </account>)
         ...
       </accounts>

  rule <k> #initAccounts(.Addresses, _) => . ... </k>

  rule <k> #initAllowances(Holder, Spender Rest)
        => #initAllowances(Holder, Rest) ... </k>
       <id> Holder </id>
       <allowances> (.Bag =>
         <allow>
           <spender> Spender </spender>
           <amount> 0 </amount>
         </allow>)
         ...
       </allowances>

  rule <k> #initAllowances(_, .Addresses) => . ... </k>

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

  rule <k> isOperatorFor ( Operator , Holder )
        => Operator in Operators ... </k>
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
  // TODO: ERC20 compatibility

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
//      ~> #hookTo ( Operator , From , To , Value , Data , OperatorData , true )
        ~> #log( Sent(Operator , From , To , Value , Data , OperatorData) )
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

  syntax Stmt ::= #hookTo ( Address , Address , Address , Number , Data , Data , Bool )

  rule <k> #hookTo ( Operator , From , To , Value , Data , OperatorData , _ )
        => #call ( #this , Hook , Operator , From , To , Value , Data , OperatorData ) ... </k>
       <id> To </id>
       <receiverHook> Hook </receiverHook>
       requires Hook =/=Int 0

  // TODO: why #mayRevert?
  rule <k> #hookTo ( Operator , From , To , Value , Data , OperatorData , PreventLocking )
        => #ite ( #isContractAddress ( To ) , #revert , #mayRevert ) ... </k>
       <id> To </id>
       <receiverHook> Hook </receiverHook>
       requires Hook ==Int 0 andBool PreventLocking

  rule <k> #hookTo ( Operator , From , To , Value , Data , OperatorData , PreventLocking )
        => #mayRevert  ... </k>
       <id> To </id>
       <receiverHook> Hook </receiverHook>
       requires Hook ==Int 0 andBool notBool PreventLocking

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

  syntax Exp ::= #isMultipleOf ( Number , Number )

  rule #isMultipleOf ( Value , Granularity ) => Value /Int Granularity *Int Granularity ==Int Value

  syntax Stmt ::= #call ( Address , Address , Address , Address , Address , Number , Data , Data )

  // TODO: more fine-grained input
  rule #call ( _ , _ , _ , _ , _ , _ , _ , _ ) => #mayRevert

  //
  // burn / operatorBurn
  // TODO: inconsistencies in the standards and reference implementation

  // NOTE: contract MAY prevent some/all holders from burning for any reason
  // vs Tokens MAY be burned from any holder address

  rule <k>         burn(        Amount)
        => operatorBurn(Holder, Amount, "") ... </k>
       <caller> Holder </caller>

  rule <k> operatorBurn(Holder, Amount, OperatorData)
        => #atomicBegin
        ~> #ensure(#and(isOperatorFor(Operator, Holder),
                        #isMultipleOf(Balance -Int Amount, #granularity),
                        Balance >=Int Amount,
                        Holder =/=Int 0))
        ~> #burn(Holder, Amount)
        ~> #hookTo(Operator, Holder, 0, Amount, "", OperatorData, true)
        ~> #log(Burned(Operator, Holder, Amount, OperatorData))
        ~> #log(Transfer(Holder, 0, Amount)) // ERC20
        ~> #atomicEnd ... </k>
       <caller> Operator </caller>
       <id> Holder </id>
       <balance> Balance </balance>

  syntax Stmt ::= #burn ( Address , Number )

  rule <k> #burn(Holder, Amount) => . ... </k>
       <account>
         <id> Holder </id>
         <balance> Balance => Balance -Int Amount </balance>
         ...
       </account>
       <supply> Supply => Supply -Int Amount </supply>
       requires Balance >=Int Amount andBool Supply >=Int Amount

  // general version
  syntax Stmt ::= #log(Event)

  rule <k> #log(Log) => . ... </k>
       <log> Logs => Logs Log </log>


  //
  // mint -> no function spec, but rules
  // TODO: `event Minted` signature inconsistency in standard

  syntax Stmt ::= #mint ( Address , Number , Data , Data )
                | #mintAux ( Address , Number )

  rule <k> #mint(Holder, Amount, Data, OperatorData)
        => #atomicBegin
        ~> #ensure(#and(#isMultipleOf(Balance +Int Amount, #granularity),
                        Holder =/=Int 0))
        ~> #mintAux(Holder, Amount)
        ~> #hookTo(Operator, 0, Holder, Amount, Data,  OperatorData, true)
        ~> #log(Minted(Operator, Holder, Amount, Data, OperatorData))
        ~> #log(Transfer(0, Holder, Amount))
        ~> #atomicEnd ... </k>
       <caller> Operator </caller>
       <id> Holder </id>
       <balance> Balance </balance>

  rule <k> #mintAux(Holder, Amount) => . ... </k>
       <account>
         <id> Holder </id>
         <balance> Balance => Balance +Int Amount </balance>
         ...
       </account>
       <supply> Supply => Supply +Int Amount </supply>
       requires Balance +Int Amount <=Int #maxNumber

  //
  // TODO: Hooks: check if registered via ERC820?
  //

  //
  // ERC20 compatibility
  // TODO: hooks for ERC20 functions
  // TODO: Check compatibility on/off?

  rule <k> allowance(Owner, Spender) => Allowance ...</k>
       <id> Owner </id>
       <spender> Spender </spender>
       <amount> Allowance </amount>

  // TODO: MUST be implemented? MAY implement?
  rule <k> decimals() => 18 </k>

  rule <k> approve(Spender, Allowance) => true ...</k>
       <caller> Owner </caller>
       <id> Owner </id>
       <spender> Spender </spender>
       <amount> _ => Allowance </amount>
       <log> Log => Log Approval(Owner, Spender, Allowance) </log>

  rule <k> transfer(To, Value)
        => #atomicBegin
        ~> #ensure(BalanceFrom >=Int Value)
        ~> #hookFrom(From, From, To, Value, "", "")
        ~> #update(From, To, Value)
        ~> #hookTo(From, From, To, Value, "", "", false) // should accept even if To isn't registered and To is contract )
        ~> #log(Transfer(From, To, Value))
        ~> #log(Sent(From, From, To, Value, "", ""))
        ~> #atomicEnd
        ~> true ... </k>
       <caller> From </caller>
       <id> From </id>
       <balance> BalanceFrom </balance>

  rule <k> transferFrom(From, To, Value)
        => #atomicBegin
        ~> #ensure(#and(BalanceFrom >=Int Value, Allowed >=Int Value))
        ~> #hookFrom(Operator, From, To, Value, "", "")
        ~> #updateWithAllowance(Operator, From, To, Value)
        ~> #hookTo(Operator, From, To, Value, "", "", false)
        ~> #atomicEnd
        ~> true ... </k>
       <caller> Operator </caller>
       <id> From </id>
       <balance> BalanceFrom </balance>
       <spender> Operator </spender>
       <amount> Allowed </amount>

  syntax Stmt ::= #updateWithAllowance ( Address , Address , Address , Number )

  rule <k> #updateWithAllowance(Operator, From, To, Value) => . ... </k>
       <account>
         <id> From </id>
         <balance> BalanceFrom => BalanceFrom -Int Value </balance>
         <spender> Operator </spender>
         <amount> Allowed => Allowed -Int Value </amount>
         ...
       </account>
       <account>
         <id> To </id>
         <balance> BalanceTo => BalanceTo +Int Value </balance>
         ...
       </account>
       requires From =/=Int To
        andBool BalanceFrom -Int Value >=Int 0
        andBool BalanceTo   +Int Value  <Int #maxNumber
        andBool Allowed >=Int Value

  rule <k> #updateWithAllowance(Operator, From, To, Value) => . ... </k>
       <account>
         <id> From </id>
         <balance> Balance </balance>
         <spender> Operator </spender>
         <amount> Allowed => Allowed -Int Value </amount>
         ...
       </account>
       requires From ==Int To
        andBool Allowed >=Int Value

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

  syntax Exp ::= "#and" "(" Exp "," Exp ")"                 [strict]
               | "#and" "(" Exp "," Exp "," Exp ")"         [strict]
               | "#and" "(" Exp "," Exp "," Exp "," Exp ")" [strict]

  rule #and ( A:Bool , B:Bool          ) => A andBool B
  rule #and ( A:Bool , B:Bool , C:Bool ) => A andBool B andBool C
  rule #and ( A:Bool , B:Bool , C:Bool , D:Bool ) => A andBool B andBool C andBool D

  syntax Stmt ::= "#mayRevert"

  rule #mayRevert => #revert
  rule #mayRevert => .

  syntax Stmt ::= "#revert"

  // TODO: #revert ~> ... ~> #atomicEnd
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
