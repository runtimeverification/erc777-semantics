require "erc777-syntax.k"

module ERC777

  imports ERC777-SYNTAX
  imports INT
  imports BOOL
  imports STRING
  imports MAP
  imports SET
  imports LIST
  imports KCELLS

  configuration
     <ERC777>
       <caller> 0:Address </caller>
       <k> $PGM:K </k>
       <accounts>
         <account multiplicity="*">
           <id> 0:Address </id>
           <balance> 0:Number </balance>
           <isContract> .K </isContract>
           <hookFail> false </hookFail>

           //ERC777 operators
           //fixme something is missing here - how a set can hold "holder -> 2^operator"?
           <operators> .Set </operators> // holder -> 2^operator
           <senderHook> 0:Address </senderHook> // holder -> senderHook
           <receiverHook> 0:Address </receiverHook> // holder -> receiverHook
           //ERC20 allowances. Contains one entry for any known address. For ERC777 operators see <operators>
           <allowances>
             <allow multiplicity="*">
               <spender> 0:Address </spender>
               <amount> 0:Number </amount>
             </allow>
           </allowances>
         </account>
       </accounts>
       <supply> 0:Number </supply>
       <nameC> "" </nameC>
       <symbolC> "" </symbolC>
       <granularityC> 1 </granularityC>
       <defaultOperatorsC> .Set </defaultOperatorsC>
       <ERC20CompatibleC> true </ERC20CompatibleC>
       <log> Events: </log> // event*
       <atomic> .K </atomic>
     </ERC777>

  //
  // Constant functions
  // - name, symbol, granularity, defaultOperators
  //

  rule #MAXVALUE => 2 ^Int 256 -Int 1

  rule <k> name ( ) => NAME ...</k>
       <nameC> NAME </nameC>

  rule <k> symbol ( ) => SYMBOL ...</k>
       <symbolC> SYMBOL </symbolC>

  rule <k> granularity ( ) => G ...</k>
       <granularityC> G </granularityC>

  rule <k> defaultOperators ( ) => DefOps ...</k>
       <defaultOperatorsC> DefOps </defaultOperatorsC>

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
  rule <k> Holder : authorizeOperator ( Operator ) => revert ... </k>
       <operators> ... Holder |-> Operators:Set ... </operators>
       requires Holder =/=Int Operator
        andBool Operator in Operators
*/

  // Reject to authorize itself -- TODO: too strong??
  rule <k> authorizeOperator ( Operator ) => revert ... </k>
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
  rule <k> Holder : revokeOperator ( Operator ) => revert ... </k>
       <operators> ... Holder |-> Operators:Set ... </operators>
       requires Holder =/=Int Operator
        andBool Operator in Operators
*/

  // Reject to revoke itself -- an address must be an operator for itself
  rule <k> revokeOperator ( Operator ) => revert ... </k>
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
        ~> #callSender ( Operator , From , To , Value , Data , OperatorData )
        ~> #update ( From , To , Value )
        ~> #callRecipent ( Operator , From , To , Value , Data , OperatorData , true )
        ~> #log( Sent(Operator , From , To , Value , Data , OperatorData) )
        ~> #logERC20( Transfer(From , To , Value) )
        ~> #atomicEnd(.K) ... </k>
       <caller> Operator </caller>
       requires From =/=Int 0

  syntax BExp ::= #check ( Address , Address , Address , Number , Data )

  rule #check ( Operator , From , To , Value , Data )
    => #and ( isOperatorFor ( Operator , From ),
              To =/=Int 0,
              Value >=Int 0,
              #isMultipleOf ( Value , granularity() )
            )

  syntax Stmt ::= #callSender ( Address , // operator
                                Address , // from
                                Address , // to
                                Number ,  // amount
                                Data ,    // userData
                                Data      // operatorData
                              )

  rule <k> #callSender ( Operator , From , To , Value , Data , OperatorData )
        => Hook . tokensToSend ( Operator , From , To , Value , Data , OperatorData ) ... </k>
       <id> From </id>
       <senderHook> Hook </senderHook>
       requires Hook =/=Int 0

  rule <k> #callSender ( Operator , From , To , Value , Data , OperatorData ) => . ... </k>
       <id> From </id>
       <senderHook> Hook </senderHook>
       requires Hook ==Int 0

  syntax Stmt ::= #callRecipent ( Address , // operator
                                  Address , // from
                                  Address , // to
                                  Number ,  // amount
                                  Data ,    // userData
                                  Data ,    // operatorData
                                  Bool      // preventLocking
                                )

  // If the recipient is a contract, which has not registered an ERC777TokensRecipient implementation; the token contract:
  // * MUST revert if the tokensReceived hook is called from a mint or send call.
  // * SHOULD accept if the tokensReceived hook is called from an ERC20 transfer or transferFrom call.
  rule <k> #callRecipent ( Operator , From , To , Value , Data , OperatorData , _ )
        => Hook . tokensReceived ( Operator , From , To , Value , Data , OperatorData ) ... </k>
       <id> To </id>
       <receiverHook> Hook </receiverHook>
       requires Hook =/=Int 0

  rule <k> #callRecipent ( Operator , From , To , Value , Data , OperatorData , PreventLocking )
        => #ite ( ISCONTRACT , revert , . ) ... </k>
       <id> To </id>
       <isContract> ISCONTRACT </isContract>
       <receiverHook> Hook </receiverHook>
       requires Hook ==Int 0 andBool PreventLocking

  rule <k> #callRecipent ( Operator , From , To , Value , Data , OperatorData , PreventLocking )
        => . ... </k>
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
        andBool ValueTo   +Int Value  <=Int #MAXVALUE

  rule <k> #update ( From , To , Value ) => . ... </k>
       requires From ==Int To

  syntax BExp ::= #isMultipleOf ( AExp , AExp ) [seqstrict]

  rule #isMultipleOf ( Value , Granularity ) => Value /Int Granularity *Int Granularity ==Int Value

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
                        #isMultipleOf(Balance -Int Amount, granularity()),
                        #and(Amount >=Int 0, Balance >=Int Amount),
                        Holder =/=Int 0))
        ~> #burn(Holder, Amount)
        ~> #callRecipent(Operator, Holder, 0, Amount, "", OperatorData, true)
        ~> #log(Burned(Operator, Holder, Amount, OperatorData))
        ~> #logERC20(Transfer(Holder, 0, Amount)) // ERC20
        ~> #atomicEnd(.K) ... </k>
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
  syntax Stmt ::= #log ( Event )
                | #logERC20 ( Event )

  rule <k> #log(Log) => . ... </k>
       <log> Logs => Logs Log </log>

  rule <k> #logERC20(Log) => . ... </k>
       <log> Logs => Logs Log </log>
       <ERC20CompatibleC> ERC20Compatible </ERC20CompatibleC>
       requires ERC20Compatible

  rule <k> #logERC20(Log) => . ... </k>
       <ERC20CompatibleC> ERC20Compatible </ERC20CompatibleC>
       requires notBool ERC20Compatible


  //
  // mint -> no function spec, but rules
  // TODO: `event Minted` signature inconsistency in standard

  syntax Stmt ::= #mint ( Address , Number , Data , Data )
                | #mintAux ( Address , Number )

  rule <k> #mint(Holder, Amount, Data, OperatorData)
        => #atomicBegin
        ~> #ensure(#and(Amount >=Int 0, #isMultipleOf(Balance +Int Amount, granularity()),
                        Holder =/=Int 0))
        ~> #mintAux(Holder, Amount)
        ~> #callRecipent(Operator, 0, Holder, Amount, Data,  OperatorData, true)
        ~> #log(Minted(Operator, Holder, Amount, Data, OperatorData))
        ~> #logERC20(Transfer(0, Holder, Amount))
        ~> #atomicEnd(.K) ... </k>
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
       requires Balance +Int Amount <=Int #MAXVALUE

  // Hooks
  // TODO: 
  // * check if registered via ERC820?
  // * check if hook call can alter token contract state

  rule <k> Hook . tokensToSend ( _ , _ , _ , _ , _ , _ ) => . ... </k>
       <id> Hook </id>
       <hookFail> HookFail </hookFail>
       requires notBool HookFail

  rule <k> Hook . tokensToSend ( _ , _ , _ , _ , _ , _ ) => revert ... </k>
       <id> Hook </id>
       <hookFail> HookFail </hookFail>
       requires HookFail

  rule <k> Hook . tokensReceived ( _ , _ , _ , _ , _ , _ ) => . ... </k>
       <id> Hook </id>
       <hookFail> HookFail </hookFail>
       requires notBool HookFail

  rule <k> Hook . tokensReceived ( _ , _ , _ , _ , _ , _ ) => revert ... </k>
       <id> Hook </id>
       <hookFail> HookFail </hookFail>
       requires HookFail

  //
  // ERC20 compatibility
  // TODO: Check compatibility on/off?
  // FIXME: revert on overflow/negative input is not the part of standards

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
       requires Allowance >=Int 0

  rule <k> approve(Spender, Allowance) => revert ...</k>
       <caller> Owner </caller>
       <id> Owner </id>
       <spender> Spender </spender>
       <amount> _ => Allowance </amount>
       requires Allowance <Int 0

  rule <k> transfer(To, Value) => #transferAux(To, Value, #getBalance(From), #getBalance(To)) ...</k>
       <caller> From </caller>

  syntax K ::= "#transferAux" "(" Address "," Number "," AExp "," AExp ")" [seqstrict(3,4)]
  rule <k> #transferAux(To, Value, BalanceFrom, BalanceTo)
        => #atomicBegin
        ~> #ensure(#and(Value >=Int 0,
                        BalanceFrom >=Int Value,
                        BalanceTo +Int Value <=Int #MAXVALUE))
        ~> #callSender(From, From, To, Value, "", "")
        ~> #update(From, To, Value)
        ~> #callRecipent(From, From, To, Value, "", "", false) // should accept even if To isn't registered and To is contract )
        ~> #log(Transfer(From, To, Value))
        ~> #log(Sent(From, From, To, Value, "", ""))
        ~> #atomicEnd(true) ... </k>
       <caller> From </caller>
       requires From =/=Int To

  rule <k> #transferAux(To, Value, BalanceFrom, BalanceTo)
        => #atomicBegin
        ~> #ensure(#and(Value >=Int 0, BalanceFrom >=Int Value))
        ~> #callSender(From, From, To, Value, "", "")
        ~> #update(From, To, Value)
        ~> #callRecipent(From, From, To, Value, "", "", false) // should accept even if To isn't registered and To is contract )
        ~> #log(Transfer(From, To, Value))
        ~> #log(Sent(From, From, To, Value, "", ""))
        ~> #atomicEnd(true) ... </k>
       <caller> From </caller>
       requires From ==Int To

  rule transferFrom(From, To, Value) => #transferFromAux(From, To, Value, #getBalance(From), #getBalance(To))

  //fixme - <operators> not used
  syntax K ::= "#transferFromAux" "(" Address "," Address "," Number "," AExp "," AExp ")" [seqstrict(4,5)]
  rule <k> #transferFromAux(From, To, Value, BalanceFrom, BalanceTo)
        => #atomicBegin
        ~> #ensure(#and(Value >=Int 0,
                        BalanceFrom >=Int Value,
                        BalanceTo +Int Value <=Int #MAXVALUE,
                        Allowed >=Int Value))
        ~> #callSender(Operator, From, To, Value, "", "")
        ~> #updateWithAllowance(Operator, From, To, Value)
        ~> #callRecipent(Operator, From, To, Value, "", "", false)
        ~> #log(Transfer(From, To, Value))
        ~> #log(Sent(From, From, To, Value, "", ""))
        ~> #atomicEnd(true) ... </k>
       <caller> Operator </caller>
       <id> From </id>
       <spender> Operator </spender>
       <amount> Allowed </amount>
       requires From =/=Int To

  rule <k> #transferFromAux(From, To, Value, BalanceFrom, BalanceTo)
        => #atomicBegin
        ~> #ensure(#and(Value >=Int 0,
                        BalanceFrom >=Int Value,
                        Allowed >=Int Value))
        ~> #callSender(Operator, From, To, Value, "", "")
        ~> #updateWithAllowance(Operator, From, To, Value)
        ~> #callRecipent(Operator, From, To, Value, "", "", false)
        ~> #log(Transfer(From, To, Value))
        ~> #log(Sent(From, From, To, Value, "", ""))
        ~> #atomicEnd(true) ... </k>
       <caller> Operator </caller>
       <id> From </id>
       <spender> Operator </spender>
       <amount> Allowed </amount>
       requires From ==Int To

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
        andBool BalanceTo   +Int Value  <=Int #MAXVALUE
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

  syntax Stmt ::= #ensure ( BExp ) [strict]

  rule #ensure ( B:Bool ) => .       requires B
  rule #ensure ( B:Bool ) => revert  requires notBool B

  syntax K ::= #ite ( BExp , K , K ) [strict(1)]

  rule #ite ( B:Bool , T , F ) => T  requires B
  rule #ite ( B:Bool , T , F ) => F  requires notBool B

  syntax BExp ::= "#and" "(" BExp "," BExp ")"                   [strict]
                | "#and" "(" BExp "," BExp "," BExp ")"          [strict]
                | "#and" "(" BExp "," BExp "," BExp "," BExp ")" [strict]

  rule #and ( A:Bool , B:Bool          ) => A andBool B
  rule #and ( A:Bool , B:Bool , C:Bool ) => A andBool B andBool C
  rule #and ( A:Bool , B:Bool , C:Bool , D:Bool ) => A andBool B andBool C andBool D

  syntax Stmt ::= "#mayRevert"

  rule #mayRevert => revert [transition]
  rule #mayRevert => .      [transition]

  rule <k> revert ~> (KI:KItem => .K) ... </k>
       <atomic> #snapshot ( _ , _ ) </atomic>
  requires notBool (KI ==K #atomicEnd(.K) orBool KI ==K #atomicEnd(true) )

  rule <k> revert ~> (#atomicEnd(_) => .K) ... </k>
       <accounts> _ => Accounts </accounts>
       <log> _ => Log </log>
       <atomic> #snapshot ( Accounts , Log ) => .K </atomic>

  syntax KItem ::= "#atomicBegin"
                 | "#atomicEnd" "(" K /*output*/ ")"
                 | #snapshot ( K , EventLog )

  rule <k> #atomicBegin => . ... </k>
       <accounts> Accounts </accounts>
       <log> Log </log>
       <atomic> .K => #snapshot ( Accounts , Log ) </atomic>

  rule <k> #atomicEnd(OUT:K) => OUT ... </k>
       <atomic> _ => .K </atomic>

  //Required instead of direct cell matching because might be called multiple times in a rule for same address.
  syntax AExp ::= "#getBalance" "(" Int ")"
  rule <k> #getBalance(Addr) => Bal ...</k>
       <id> Addr </id>
       <balance> Bal </balance>

  syntax AExp ::= "#getCaller"
  rule <k> #getCaller => Caller ... </k>
       <caller> Caller </caller>


endmodule
