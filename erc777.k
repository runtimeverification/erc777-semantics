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

           //ERC777 operators
           <operators> .Set </operators> // Set of approved operators for this account.
           <senderHook> 0:Address </senderHook> // Address of sender hook, or 0 if not registered.
           <receiverHook> 0:Address </receiverHook> // Address of receiver hook, or 0 if not registered.
           <isContract> .K </isContract>
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
       // ERC777TokensRecipient not registered + regular address + receiving tokens: whether to accept (true) or reject
       <acceptRegularNoReceiverHook> true </acceptRegularNoReceiverHook>
       <burnAllowed> true </burnAllowed>
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

  rule <k> balanceOf ( Holder:Int  ) => Balance ... </k>
       <id> Holder </id>
       <balance> Balance </balance>
    requires Holder =/=Int 0

  //Required for send/operatorSend revert cases.
  rule balanceOf(0) => 0

  rule <k> isOperatorFor ( Operator:Int , Holder:Int )
        => Operator in Operators ... </k>
       <id> Holder </id>
       <operators> Operators:Set </operators>
    requires Holder =/=Int 0

  //aux case for operatorSend
  rule isOperatorFor(_, 0) => false

  //
  // authorizeOperator / revokeOperator
  //

  // Non-deterministically allow to authorize an already-authorized-operator
  rule <k> authorizeOperator ( Operator:Int ) => #void ... </k>
       <caller> Holder </caller>
       <id> Holder </id>
       <operators> Operators => Operators SetItem(Operator) </operators>
       <log> Log => Log AuthorizedOperator ( Operator , Holder ) </log>
       requires Holder =/=Int Operator andBool Operator =/=Int 0

  // Reject to authorize itself
  rule <k> authorizeOperator ( Operator:Int ) => revert ... </k>
       <caller> Holder </caller>
       requires Holder ==Int Operator orBool Operator ==Int 0

  ////

  // Non-deterministically allow to revoke a non-authorized-operator
  rule <k> revokeOperator ( Operator:Int ) => #void ... </k>
       <caller> Holder </caller>
       <id> Holder </id>
       <operators> Operators => Operators -Set SetItem(Operator) </operators>
       <log> Log => Log RevokedOperator ( Operator , Holder ) </log>
       requires Holder =/=Int Operator andBool Operator =/=Int 0

  // Reject to revoke itself -- an address must be an operator for itself
  rule <k> revokeOperator ( Operator:Int ) => revert ... </k>
       <caller> Holder </caller>
       requires Holder ==Int Operator orBool Operator ==Int 0

  //
  // send / operatorSend
  // TODO: ERC20 compatibility

  rule <k>         send (          To:Int , Value:Int , Data      )
        => operatorSend ( Holder , To     , Value     , Data , "" ) ... </k>
       <caller> Holder </caller>

  rule <k> operatorSend ( 0 => Caller , _,_,_,_ ) ... </k>
       <caller> Caller </caller>
    requires Caller =/=Int 0 //just for safety

  rule operatorSend ( From , To , Value , Data , OperatorData )
       => #operatorSendAux ( From , To , Value , Data , OperatorData , balanceOf(From), balanceOf(To) )
    requires From =/=Int 0 //just for safety

  syntax K ::= "#operatorSendAux" "(" Address "," Address "," Number "," Data "," Data "," AExp "," AExp ")" [seqstrict(6,7)]

  rule <k> #operatorSendAux ( From , To , Value , Data , OperatorData , BalanceFrom:Int, BalanceTo:Int )
        => #atomicBegin
        ~> #ensure( #and(
              From =/=Int 0,
              To =/=Int 0,
              isOperatorFor ( Operator , From ),
              Value >=Int 0,
              BalanceFrom >=Int Value,
              #or(From ==Int To, BalanceTo +Int Value <=Int #MAXVALUE),
              #isMultipleOf ( Value , granularity() ) ))
        ~> #callSender ( Operator , From , To , Value , Data , OperatorData )
        ~> #transfer ( From , To , Value )
        ~> #callRecipient ( Operator , From , To , Value , Data , OperatorData , false )
        ~> #log( Sent(Operator , From , To , Value , Data , OperatorData) )
        ~> #logERC20( Transfer(From , To , Value) )
        ~> #atomicEnd(#void) ... </k>
       <caller> Operator </caller>

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

  // no hook registered
  rule <k> #callSender ( Operator , From , To , Value , Data , OperatorData ) => . ... </k>
       <id> From </id>
       <senderHook> 0 </senderHook>

  syntax Stmt ::= #callRecipient ( Address , // operator
                                   Address , // from
                                   Address , // to
                                   Number ,  // amount
                                   Data ,    // userData
                                   Data ,    // operatorData
                                   Bool      // fromERC20: called by ERC20 functions
                                 )

  // If the recipient is a contract, which has not registered an ERC777TokensRecipient implementation; the token contract:
  // * MUST revert if the tokensReceived hook is called from a mint or send call.
  // * SHOULD accept if the tokensReceived hook is called from an ERC20 transfer or transferFrom call.
  rule <k> #callRecipient ( Operator , From , To , Value , Data , OperatorData , _ )
        => Hook . tokensReceived ( Operator , From , To , Value , Data , OperatorData ) ... </k>
       <id> To </id>
       <receiverHook> Hook </receiverHook>
       requires Hook =/=Int 0

  rule <k> #callRecipient ( Operator , From , To , Value , Data , OperatorData , FromERC20 )
        => #ite( #or(FromERC20, #and(AcceptRegular, notBool ISCONTRACT) ) , . , revert ) ... </k>
       <id> To </id>
       <receiverHook> 0 </receiverHook>
       <isContract> ISCONTRACT </isContract>
       <acceptRegularNoReceiverHook> AcceptRegular </acceptRegularNoReceiverHook>

  syntax Stmt ::= #transfer ( Address , Address , Number )

  rule <k> #transfer ( From , To , Value ) => . ... </k>
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
     // andBool ValueFrom -Int Value >=Int 0
     // andBool ValueTo   +Int Value  <=Int #MAXVALUE
     // already checked

  rule <k> #transfer ( From , To , Value ) => . ... </k>
       requires From ==Int To

  syntax BExp ::= #isMultipleOf ( AExp , AExp ) [seqstrict]

  rule #isMultipleOf ( Value:Int , Granularity:Int ) => Value /Int Granularity *Int Granularity ==Int Value

  //
  // burn / operatorBurn
  // TODO: inconsistencies in the standards and reference implementation

  // NOTE: contract MAY prevent some/all holders from burning for any reason
  // vs Tokens MAY be burned from any holder address

  rule <k>         burn(        Amount:Int   )
        => operatorBurn(Caller, Amount,    "") ... </k>
       <caller> Caller </caller>

  rule <k> operatorBurn(0 => Caller, _,_) ... </k>
       <caller> Caller </caller>
    requires Caller =/=Int 0 //just for safety

  rule <k> operatorBurn(Holder:Int, Amount:Int, OperatorData)
        => #atomicBegin
        ~> #ensure(#and(isOperatorFor(Operator, Holder),
                        #isMultipleOf(Amount, granularity()),
                        Amount >=Int 0,
                        Balance >=Int Amount,
                        Holder =/=Int 0,
                        BurnAllowed))
        ~> #callSender(Operator, Holder, 0, Amount, "", OperatorData)
        ~> #burn(Holder, Amount)
        ~> #log(Burned(Operator, Holder, Amount, OperatorData))
        ~> #logERC20(Transfer(Holder, 0, Amount)) // ERC20
        ~> #atomicEnd(#void) ... </k>
       <caller> Operator </caller>
       <id> Holder </id>
       <balance> Balance </balance>
       <burnAllowed> BurnAllowed </burnAllowed>
    requires Holder =/=Int 0

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
  // Minting: ERC777 does not define specific functions to mint tokens. Instead,
  // it specifies several rules that MUST be respected when minting tokens.
  // The definition of `mint` below is a minimal example of minting function
  // that conforms to those rules.
  // TODO: * `event Minted` signature inconsistency in standard
  //       *  balance of 0x0 MUST NOT be decreased

  rule operatorMint(0, _,_,_) => revert

  rule <k> operatorMint(Holder, Amount, Data, OperatorData)
        => #atomicBegin
        ~> #ensure(#and(Amount >=Int 0,
                        Supply +Int Amount <=Int #MAXVALUE,
                        #isMultipleOf(Amount, granularity()),
                        Holder =/=Int 0,
                        isOperatorFor( Operator , Holder )))
        ~> #mint(Holder, Amount)
        ~> #callRecipient(Operator, 0, Holder, Amount, Data,  OperatorData, false)
        ~> #log(Minted(Operator, Holder, Amount, Data, OperatorData))
        ~> #logERC20(Transfer(0, Holder, Amount))
        ~> #atomicEnd(#void) ... </k>
       <caller> Operator </caller>
       <id> Holder </id>
       <supply> Supply </supply>
    requires Holder =/=Int 0

  syntax Stmt ::= #mint ( Address , Number )

  rule <k> #mint(Holder, Amount) => . ... </k>
       <account>
         <id> Holder </id>
         <balance> Balance => Balance +Int Amount </balance>
         ...
       </account>
       <supply> Supply => Supply +Int Amount </supply>


  //
  // ERC20 compatibility
  // TODO: Check compatibility on/off?
  //

  rule <k> allowance(Owner:Int, Spender:Int) => Allowance ...</k>
       <id> Owner </id>
       <spender> Spender </spender>
       <amount> Allowance </amount>

  // TODO: MUST be implemented? MAY implement?
  rule <k> decimals() => 18 </k>

  rule <k> approve(Spender:Int, Allowance:Int) => true ...</k>
       <caller> Owner </caller>
       <id> Owner </id>
       <spender> Spender </spender>
       <amount> _ => Allowance </amount>
       <log> Log => Log Approval(Owner, Spender, Allowance) </log>
       requires Allowance >=Int 0

  rule <k> approve(Spender:Int, Allowance:Int) => revert ...</k>
       <caller> Owner </caller>
       <id> Owner </id>
       <spender> Spender </spender>
       <amount> _ => Allowance </amount>
       requires Allowance <Int 0

  rule <k> transfer(To:Int, Value:Int) => #transferAux(To, Value, balanceOf(From), balanceOf(To)) ...</k>
       <caller> From </caller>

  syntax K ::= "#transferAux" "(" Address "," Number "," AExp "," AExp ")" [seqstrict(3,4)]
  rule <k> #transferAux(To:Int, Value:Int, BalanceFrom:Int, BalanceTo:Int)
        => #atomicBegin
        ~> #ensure(#and(Value >=Int 0,
                        BalanceFrom >=Int Value,
                        #isMultipleOf(Value, granularity()),
                        #or(From ==Int To, BalanceTo +Int Value <=Int #MAXVALUE)))
        ~> #callSender(From, From, To, Value, "", "")
        ~> #transfer(From, To, Value)
        ~> #callRecipient(From, From, To, Value, "", "", true) // should accept even if To isn't registered and To is contract )
        ~> #log(Transfer(From, To, Value))
        ~> #log(Sent(From, From, To, Value, "", ""))
        ~> #atomicEnd(true) ... </k>
       <caller> From </caller>

  rule transferFrom(From:Int, To:Int, Value:Int)
       => #transferFromAux(From, To, Value, balanceOf(From), balanceOf(To))

  syntax K ::= "#transferFromAux" "(" Address "," Address "," Number "," AExp "," AExp ")" [seqstrict(4,5)]
  rule <k> #transferFromAux(From, To, Value, BalanceFrom:Int, BalanceTo:Int)
        => #atomicBegin
        ~> #ensure(#and(Value >=Int 0,
                        BalanceFrom >=Int Value,
                        #isMultipleOf(Value, granularity()),
                        #or(From ==Int To, BalanceTo +Int Value <=Int #MAXVALUE),
                        Allowed >=Int Value))
        ~> #callSender(Operator, From, To, Value, "", "")
        ~> #transferWithAllowance(Operator, From, To, Value)
        ~> #callRecipient(Operator, From, To, Value, "", "", true)
        ~> #log(Transfer(From, To, Value))
        ~> #log(Sent(From, From, To, Value, "", ""))
        ~> #atomicEnd(true) ... </k>
       <caller> Operator </caller>
       <id> From </id>
       <spender> Operator </spender>
       <amount> Allowed </amount>

  syntax Stmt ::= #transferWithAllowance ( Address , Address , Address , Number )

  rule <k> #transferWithAllowance(Operator, From, To, Value) => . ... </k>
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
     // andBool BalanceFrom -Int Value >=Int 0
     // andBool BalanceTo   +Int Value  <=Int #MAXVALUE
     // andBool Allowed >=Int Value
     // already checked

  rule <k> #transferWithAllowance(Operator, From, To, Value) => . ... </k>
       <account>
         <id> From </id>
         <balance> Balance </balance>
         <spender> Operator </spender>
         <amount> Allowed => Allowed -Int Value </amount>
         ...
       </account>
       requires From ==Int To
     // andBool Allowed >=Int Value
     // already checked

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

  syntax BExp ::= "#and" "(" BExp "," BExp ")"                                     [strict]
                | "#and" "(" BExp "," BExp "," BExp ")"                            [strict]
                | "#and" "(" BExp "," BExp "," BExp "," BExp ")"                   [strict]
                | "#and" "(" BExp "," BExp "," BExp "," BExp "," BExp ")"          [strict]
                | "#and" "(" BExp "," BExp "," BExp "," BExp "," BExp "," BExp ")" [strict]
                | "#and" "(" BExp "," BExp "," BExp "," BExp "," BExp "," BExp "," BExp ")" [strict]
                | "#or"  "(" BExp "," BExp ")"                                     [strict]

  rule #and ( A:Bool , B:Bool )                                     => A andBool B
  rule #and ( A:Bool , B:Bool , C:Bool )                            => A andBool B andBool C
  rule #and ( A:Bool , B:Bool , C:Bool , D:Bool )                   => A andBool B andBool C andBool D
  rule #and ( A:Bool , B:Bool , C:Bool , D:Bool , E:Bool )          => A andBool B andBool C andBool D andBool E
  rule #and ( A:Bool , B:Bool , C:Bool , D:Bool , E:Bool , F:Bool ) => A andBool B andBool C andBool D andBool E andBool F
  rule #and ( A:Bool , B:Bool , C:Bool , D:Bool , E:Bool , F:Bool , G:Bool )
       => A andBool B andBool C andBool D andBool E andBool F andBool G
  rule #or  ( A:Bool , B:Bool )                                     => A orBool B

  rule <k> revert ~> (KI:KItem => .K) ... </k>
       <atomic> #snapshot ( _ , _ , _ ) </atomic>
  requires (KI =/=K #atomicEnd(#void)) andBool (KI =/=K #atomicEnd(true))

  rule <k> revert ~> (#atomicEnd(_) => .K) ... </k>
       <accounts> _ => Accounts </accounts>
       <log> _ => Log </log>
       <supply> _ => Supply </supply>
       <atomic> #snapshot ( Accounts , Log , Supply ) => .K </atomic>

  syntax KItem ::= "#atomicBegin"
                 | "#atomicEnd" "(" K /*output*/ ")"
                 | #snapshot ( K , EventLog , Number )

  rule <k> #atomicBegin => . ... </k>
       <accounts> Accounts </accounts>
       <log> Log </log>
       <supply> Supply </supply>
       <atomic> .K => #snapshot ( Accounts , Log , Supply ) </atomic>

  rule <k> #atomicEnd(OUT:K) => OUT ... </k>
       <atomic> _ => .K </atomic>

  syntax AExp ::= "#getCaller"
  rule <k> #getCaller => Caller ... </k>
       <caller> Caller </caller>

  syntax EventLog ::= "#getLogs"
  rule <k> #getLogs => Logs ... </k>
       <log> Logs </log>

  syntax Void ::= "#void"
  syntax Exp ::= Void

endmodule
