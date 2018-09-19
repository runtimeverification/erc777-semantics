/* Author: Denis Bogdanas, Daejun Park, Grigore Rosu
   Date: 18 September 2018

   The IMP language defined below is mostly imported from the K Tutorial,
   specifically from its IMP and IMP++ languages:
   https://github.com/kframework/k/blob/master/k-distribution/tutorial/1_k/2_imp/lesson_5/imp.k
   https://github.com/kframework/k/blob/master/k-distribution/tutorial/1_k/4_imp%2B%2B/lesson_8/imp.k

   The goal of this language here is to test the ERC777-K specification.
   It therefore adds language extensions to create, initialize, and modify
   the configuration of ERC777-K.  See inlined comments below, where needed.
   We assume the reader familiar with K and the K tutorial definitions
   of IMP and IMP++. */

require "../erc777.k"

module ERC777-IMP-SYNTAX
  imports ERC777-SYNTAX
  imports DOMAINS-SYNTAX

  syntax AExp  ::= String | Id
                 | "read" "(" ")"
                 > AExp "*" AExp              [left, strict]
                 > AExp "+" AExp              [left, strict]
                 | "(" AExp ")"               [bracket]
  syntax BExp  ::= AExp "<=" AExp             [seqstrict]
                 | AExp "==" AExp             [seqstrict]
                 | "!" BExp                   [strict]
                 > BExp "&&" BExp             [left, strict(1)]
                 > BExp "||" BExp             [left, strict(1)]
                 | "(" BExp ")"               [bracket]
  syntax Block ::= "{" "}"
                 | "{" Stmt "}"
  syntax Stmt  ::= Block
                 | Id "=" AExp ";"            [strict(2)]
                 | "if" "(" BExp ")"
                   Block "else" Block         [strict(1), prefer]
                 | "if" "(" BExp ")" Block
                 | "while" "(" BExp ")" Block
                 | "int" Ids   // use only at the top of the program
                 | "print" "(" Exp ")"       [strict]
                 | "println" "(" Exp ")"
                 | "printLog" "(" EventLog ")"
                 | "printLog" "(" Event ")"
                 | Stmt ";"
                 > Stmt Stmt                  [left]
  syntax Ids   ::= List{Id,","}

  syntax Stmt ::= Exp ";"                                [strict]
/* The "make" statements below allow us to programmatically interfere
   with the ERC20-K configuration.  Such statements would not be
   possible/allowed in a normal programming language for smart contracts. */
                | "makeDefaultOperator" "(" AExp ")"     [strict]
                | "makeAccount" "(" AExp //account
                                ")"                      [strict]
                | "makeAllowance" "(" AExp "," AExp ")"  [strict]
                | "makeCaller" "(" AExp ")"              [strict]
                | "makeContractAccount" "(" AExp ")"     [strict]
                | "makeNameAndSymbol" "(" String "," String ")"
                | "makeERC20Compatible" "(" Bool ")"
                | "makeRevertAsPrintTrue"
                | "makeRevertAsPrintFalse"
                | "makeAcceptingHookHost" "(" Address ")" //register this address as a host of accepting hook.
                                                          //can be used by multiple token holders.
                | "registerTokensToSendHook" "(" Address //token holder
                                             "," Address //Hook address (Host)
                                             ")"
                | "registerTokensReceivedHook" "(" Address //token holder
                                               "," Address //Hook address (Host)
                                               ")"
                | "test.setAcceptRegularNoReceiverHook" "(" Bool ")"
                | "test.setBurnAllowed" "(" Bool ")"
                | "printLogs"

endmodule

module ERC777-IMP
  imports DOMAINS
  imports ERC777-IMP-SYNTAX
  imports ERC777

/* The IMP configuration embeds the ERC20 configuration *unchanged*.
   It adds several new cells to keep track of IMP program's state, I/O, UI. */
  configuration <IMP>
                  initERC777Cell(Init)  // including the ERC20-K configuration.
                  <state> .Map </state>
                  <input color="magenta" stream="stdin"> .List </input>
                  <output color="Orchid" stream="stdout"> .List </output>
                  <revertAsPrint> false </revertAsPrint>  // to print REVERT
                  <acceptingHooks> .Set </acceptingHooks> // Set of addresses that implement an accepting hook.
                                                          // all other addresses are reverting.
                </IMP>

  syntax KResult ::= Int | Bool | String | Set | Void

// AExp
  rule <k> X:Id => Rho[X] ...</k> <state> Rho </state>
  rule <k> read() => I ...</k>
       <input> ListItem(I:Int) => .List ...</input>  [read]
  rule I1 * I2 => I1 *Int I2
  rule I1 + I2 => I1 +Int I2
// BExp
  rule I1 <= I2 => I1 <=Int I2
  rule I1 == I2 => I1 ==Int I2
  rule ! T => notBool T
  rule true && B => B
  rule false && _ => false
  rule true || _ => true
  rule false || B => B
// Block
  rule {} => .   [structural]
  rule {S} => S  [structural]
// Stmt
  rule <k> X = I:Int; => . ...</k> <state>... X |-> (_ => I) ...</state>
  rule S1:Stmt S2:Stmt => S1 ~> S2  [structural]
  rule if (true)  S else _ => S
  rule if (false) _ else S => S
  rule if (B) S => if (B) S else {}
  rule while (B) S => if (B) {S while (B) S} else {}  [structural]
// Pgm
  rule <k> int (X,Xs => Xs) ...</k> <state> Rho:Map (.Map => X|->0) </state>
    requires notBool (X in keys(Rho))
  rule int .Ids => .  [structural]

/* We slightly modify the semantics of print to allow a flag "printNewLine".
   When the flag is true, all strings are printed and integers are printed
   normally.  When the flag is false, the strings are not printed and the
   integers are printed one per line. */

  syntax String ::= Bool2String   ( Bool ) [function]
  rule Bool2String(true) => "true"
  rule Bool2String(false) => "false"

  rule <k> print(I:Int) => . ...</k>
       <output>... .List => ListItem(I) </output>
  rule <k> print(Str:String) => . ...</k>
       <output>... .List => ListItem(Str) </output>
  rule <k> print(B:Bool) => . ...</k>
       <output>... .List => ListItem(Bool2String(B)) </output>

  rule println(E) => print(E) ~> print("\n")

  //print logs at the end of execution
  rule <k> printLogs => printLog(Log) ...</k>
       <log> Log </log>

  rule printLog(ELog Ev:Event) => printLog(ELog) ~> printLog(Ev)
  rule <k> printLog(Events:) => . ...</k>
       <output>... .List => ListItem("\nEvents:\n") </output>

  rule <k> printLog(Sent(Operator , From , To , Value , Data , OperatorData)) => . ...</k>
       <output>... .List => ListItem("Sent(" +String Int2String(Operator) +String ", "
            +String Int2String(From) +String ", " +String Int2String(To) +String ", "
            +String Int2String(Value) +String ", " +String Data +String ", " +String OperatorData
            +String ")\n") </output>

  rule <k> printLog(Minted(Operator, Holder, Amount, Data, OperatorData)) => . ...</k>
       <output>... .List => ListItem("Minted(" +String Int2String(Operator) +String ", "
            +String Int2String(Holder) +String ", " +String Int2String(Amount) +String ", "
            +String Data +String ", " +String OperatorData
            +String ")\n") </output>

  rule <k> printLog(Burned(Operator, Holder, Amount, OperatorData)) => . ...</k>
       <output>... .List => ListItem("Burned(" +String Int2String(Operator) +String ", "
            +String Int2String(Holder) +String ", " +String Int2String(Amount) +String ", "
            +String OperatorData
            +String ")\n") </output>

  rule <k> printLog(AuthorizedOperator ( Operator , Holder )) => . ...</k>
       <output>... .List => ListItem("AuthorizedOperator(" +String Int2String(Operator) +String ", "
            +String Int2String(Holder)
            +String ")\n") </output>

  rule <k> printLog(RevokedOperator ( Operator , Holder )) => . ...</k>
       <output>... .List => ListItem("RevokedOperator(" +String Int2String(Operator) +String ", "
            +String Int2String(Holder)
            +String ")\n") </output>

  rule <k> printLog(Transfer(From , To , Value)) => . ...</k>
       <output>... .List => ListItem("Transfer(" +String Int2String(From) +String ", "
            +String Int2String(To) +String ", " +String Int2String(Value)
            +String ")\n") </output>

  rule <k> printLog(Approval(Owner, Spender, Allowance)) => . ...</k>
       <output>... .List => ListItem("Approval(" +String Int2String(Owner) +String ", "
            +String Int2String(Spender) +String ", " +String Int2String(Allowance)
            +String ")\n") </output>

/* We also add the following 3 rules which we do not have in the K Tutorial
   IMP.  The reason we add them is to allow us to put semicolon ";" after
   any syntactic construct, in particular after ERC20-K functions.  */

  rule _:Bool; => .
  rule _:Int; => .
  rule _:Void; => .
  rule S:Stmt; => S

/* Hook implementations  */
  rule <k> Hook:Int . tokensToSend ( Operator , From , To , Value , Data , OperatorData ) =>
            print("tokensToSend: Hook address = ");
            print(Hook);
            print(", Operator = ");
            print(Operator);
            print(", From = ");
            print(From);
            print(", To = ");
            print(To);
            print(", Value = ");
            print(Value);
            print(", Data = ");
            print(Data);
            print(", OperatorData = ");
            print(OperatorData);
            print("\ntokensToSend: sender balance: ");
            print(balanceOf(From));
            print("\ntokensToSend: receiver balance: ");
            print(balanceOf(To));
            print("\n");
            ...
       </k>
       <acceptingHooks>... SetItem(Hook) ...</acceptingHooks>

  rule <k> Hook:Int . tokensToSend ( Operator , From , To , Value , Data , OperatorData ) =>
            print("tokensToSend: Hook address = ");
            print(Hook);
            print(", Operator = ");
            print(Operator);
            print(", From = ");
            print(From);
            print(", To = ");
            print(To);
            print(", Value = ");
            print(Value);
            print(", Data = ");
            print(Data);
            print(", OperatorData = ");
            print(OperatorData);
            print("\ntokensToSend: sender balance: ");
            print(balanceOf(From));
            print("\ntokensToSend: receiver balance: ");
            print(balanceOf(To));
            print("\n");
            print("Reverting...\n");
            ~> revert
            ...
       </k>
       <acceptingHooks> AcceptingHooks </acceptingHooks>
     requires notBool Hook in AcceptingHooks

  rule <k> Hook:Int . tokensReceived (Operator , From , To , Value , Data , OperatorData ) =>
            print("tokensReceived: Hook address = ");
            print(Hook);
            print(", Operator = ");
            print(Operator);
            print(", From = ");
            print(From);
            print(", To = ");
            print(To);
            print(", Value = ");
            print(Value);
            print(", Data = ");
            print(Data);
            print(", OperatorData = ");
            print(OperatorData);
            print("\ntokensReceived: sender balance: ");
            print(balanceOf(From));
            print("\ntokensReceived: receiver balance: ");
            print(balanceOf(To));
            print("\n");
            ...
       </k>
       <acceptingHooks>... SetItem(Hook) ...</acceptingHooks>

  rule <k> Hook:Int . tokensReceived (Operator , From , To , Value , Data , OperatorData ) =>
            print("tokensReceived: Hook address = ");
            print(Hook);
            print(", Operator = ");
            print(Operator);
            print(", From = ");
            print(From);
            print(", To = ");
            print(To);
            print(", Value = ");
            print(Value);
            print(", Data = ");
            print(Data);
            print(", OperatorData = ");
            print(OperatorData);
            print("\ntokensReceived: sender balance: ");
            print(balanceOf(From));
            print("\ntokensReceived: receiver balance: ");
            print(balanceOf(To));
            print("\n");
            print("Reverting...\n");
            ~> revert
            ...
       </k>
       <acceptingHooks> AcceptingHooks </acceptingHooks>
     requires notBool Hook in AcceptingHooks

/* Next we define the special "make" constructs which create and modify the
   ERC20-K state.  One should be careful with these constructs, because any
   mistake can make ERC20-K behave unexpectedly.  Such operations should not
   exist in normal implementations of languages for smart contracts.  */

  rule <k> makeDefaultOperator(DOP:Int) => . ...</k>
       <defaultOperatorsC>... .Set => SetItem(DOP) ...</defaultOperatorsC>

  rule <k> makeContractAccount(Addr:Address) => . ...</k>
       <id> Addr </id>
       <isContract> _ => true </isContract>

  rule <k> makeAccount(Addr:Address) => . ...</k>
       <accounts> (.Bag =>
         <account>
           <id> Addr </id>
           <balance> 0 </balance>
           <isContract> false </isContract>
           <operators> SetItem(Addr) DefOps </operators>
           <senderHook> 0 </senderHook>
           <receiverHook> 0 </receiverHook>
           <allowances> .Bag </allowances>
         </account>)
         ...
       </accounts>
       <defaultOperatorsC> DefOps </defaultOperatorsC>

  rule <k> makeAllowance(Holder:Address, Spender:Address) => . ...</k>
       <id> Holder </id>
       <allowances> (.Bag =>
         <allow>
           <spender> Spender </spender>
           <amount> 0 </amount>
         </allow>)
         ...
       </allowances>


  rule <k> makeCaller(I:Int) => . ...</k> <caller> _ => I </caller>

  rule <k> makeNameAndSymbol(NAME:String, SYMBOL:String) => . ...</k>
       <nameC> _ => NAME </nameC>
       <symbolC> _ => SYMBOL </symbolC>

  rule <k> makeERC20Compatible(COMPAT) => . ... </k>
       <ERC20CompatibleC> _ => COMPAT </ERC20CompatibleC>

  rule <k> makeRevertAsPrintTrue  => . ...</k> <revertAsPrint> _ => true </revertAsPrint>
  rule <k> makeRevertAsPrintFalse => . ...</k> <revertAsPrint> _ => false </revertAsPrint>

  rule <k> makeAcceptingHookHost(Host) => . ...</k>
       <acceptingHooks>... .Set => SetItem(Host) ...</acceptingHooks>

  rule <k> registerTokensToSendHook(Holder, Host) => . ...</k>
       <id> Holder </id>
       <senderHook> _ => Host </senderHook>

  rule <k> registerTokensReceivedHook(Receiver, Host) => . ...</k>
       <id> Receiver </id>
       <receiverHook> _ => Host </receiverHook>

  rule <k> test.setAcceptRegularNoReceiverHook(B) => . ...</k>
       <acceptRegularNoReceiverHook> _ => B </acceptRegularNoReceiverHook>

  rule <k> test.setBurnAllowed(B) => print("Burning allowed: "); println(B); ...</k>
       <burnAllowed> _ => B </burnAllowed>

  rule <k> revert => #void ...</k>
       <revertAsPrint> true </revertAsPrint>
       <atomic> .K </atomic>
       <output>... .List => ListItem("REVERT\n") </output>

/* The next definitions have nothing to do with the IMP semantics.
   They are macros allowing us to write some IMP programs more compactly.
   Note that the objective of this folder is to test the ERC20-K and not
   to define production languages on top of ERC20-K.  Thus we do not pay
   any attention to the viability of the language itself here, but simply
   focus on creating the testing infrastructure that we need.  That being
   said, I think developing a uniform and modular framework to plug-and-play
   ERC20-K in a language that has a K semantics is a very valuable research
   initiative in itself.  In short, I am not proud of the rest of this module
   but the objective was *not* to define something to be proud of.  :)  */

  syntax Id ::= "accounts"  [token]
              | "x"         [token]
              | "y"         [token]
              | "a"         [token]
              | "b"         [token]
              | "c"         [token]
              | "caller"    [token]
              | "v"         [token]
              | "senderHook"    [token]
              | "receiverHook"  [token]
              | "continueLoop"  [token] //for interactive.imp

/* ---PREAMBLE----------
   This preamble creates some initial configuration:
     accounts, allowances, supply, caller.
   Recall that this ERC20 semantics assumes that the total supply, all the
   accounts and all their allowances (including those which are 0), as well
   as the caller given.  Then the code is executed on the caller's behalf. */

  syntax Stmt ::= "test.preamble" "(" ")"  [macro]
  rule test.preamble() =>
int accounts, x, y, a, b, c, caller, v;
accounts = 10;
makeNameAndSymbol("RVToken", "RVT")

makeDefaultOperator(8) //accounts 8 and 9 are default operators
makeDefaultOperator(9)
x = accounts;
while(!(x <= 0)) { //e.g. while x > 0, but we cannot use ">" because it throws kompilation error
  makeAccount(x);
  x = x + -1;
}

makeCaller(8); //operator to call operatorMint()
x = accounts;
while(!(x <= 0)) {
  operatorMint(x, x*10, "", "init"); //init account x with 10*x balance through minting operation.
  y = accounts;
  while(!(y <= 0)) {
    makeAllowance(x,y);
	y = y + -1;
  }
  x = x + -1;
}

//setting them as contracts now, to avoid incompatibility with operatorMint().
makeContractAccount(9); //accounts 9 and 10 are contracts
makeContractAccount(10);

caller = 7;
makeCaller(caller);
makeAcceptingHookHost(1); //accounts 1 and 2 are hosts of accepting hooks. All the rest - rejecting hooks.
makeAcceptingHookHost(2);
makeRevertAsPrintTrue;
// ---END-OF-PREAMBLE---

  syntax Stmt ::= "test.makeCaller" "(" AExp ")"   [macro]
  rule test.makeCaller(Id) =>
    caller = Id;
    print("Changing the caller to ");
    print(caller);
    print("\n");
    makeCaller(caller);

  syntax Stmt ::= "test.registerTokensToSendHook" "(" AExp "," AExp ")"   [macro]
  rule test.registerTokensToSendHook(Holder, Hook) =>
    print("Registering holder ");
    print(Holder);
    print(" with hook ");
    print(Hook);
    print("\n");
    registerTokensToSendHook(Holder, Hook);

  syntax Stmt ::= "test.registerTokensReceivedHook" "(" AExp "," AExp ")"   [macro]
  rule test.registerTokensReceivedHook(Receiver, Hook) =>
    print("Registering receiver ");
    print(Receiver);
    print(" with hook ");
    print(Hook);
    print("\n");
    registerTokensReceivedHook(Receiver, Hook);

  syntax Stmt ::= "test.setGranularity" "(" AExp ")" [strict]
  rule <k> test.setGranularity(G)  => print("granularity: ") ~> println(G) ... </k>
       <granularityC> _ => G </granularityC>

  syntax Stmt ::= "test.name" "(" ")" [macro]
  rule test.name() =>
    print("name() => ");
    println(name());

  syntax Stmt ::= "test.symbol" "(" ")" [macro]
  rule test.symbol() =>
    print("symbol() => ");
    println(symbol());

  syntax Stmt ::= "test.granularity" "(" ")" [macro]
  rule test.granularity() =>
    print("granularity() => ");
    println(granularity());

  syntax Stmt ::= "test.defaultOperators" "(" ")" [macro]
  rule test.defaultOperators() =>
    print("defaultOperators() => ");
    printSet(defaultOperators());
    print("\n");

  syntax Stmt ::= printSet(SetExp) [strict]
  rule printSet(SetItem(E:Exp) Rest:Set) => print(E) ~> print(" ") ~> printSet(Rest)
  rule printSet(.Set) => .

  syntax Stmt ::= "test.totalSupply" "(" ")"   [macro]
  rule test.totalSupply() =>
    print("Total supply is ");
    println(totalSupply());

  syntax Stmt ::= "test.balanceOf" "(" AExp ")"     [macro]
  rule test.balanceOf(Id) =>
    a = Id;
    print("Balance of ");
    print(a);
    print(" is ");
    print(balanceOf(a));
    print("\n");

  syntax Stmt ::= "test.isOperatorFor" "(" AExp "," AExp ")" [macro]
  rule test.isOperatorFor(Operator, Holder) =>
    a = Operator;
    b = Holder;
    print(a);
    if (isOperatorFor(a, b)) {
      print(" is operator for ");
    } else {
      print(" is not operator for ");
    }
    println(b);

  syntax Stmt ::= "test.authorizeOperator" "(" AExp ")" [macro]
  rule test.authorizeOperator(Operator) =>
    a = Operator;
    print(#getCaller);
    print(" is authorizing ");
    print(a);
    println(" as an operator");
    authorizeOperator(Operator);

  syntax AExp ::= "#getCaller"
  rule <k> #getCaller => Caller ... </k>
       <caller> Caller </caller>

  syntax Stmt ::= "test.revokeOperator" "(" AExp ")" [macro]
  rule test.revokeOperator(Operator) =>
    a = Operator;
    print(#getCaller);
    print(" is revoking operator ");
    println(a);
    revokeOperator(Operator);

  syntax Stmt ::= "test.send" "(" AExp "," AExp "," Data ")" [macro]
  rule test.send(To, Value, Data) =>
    b = To;
    v = Value;
    print(#getCaller);
    print(" is sending ");
    print(v);
    print(" to ");
    print(b);
    print(" (data:");
    print(Data);
    print(")\n");
    send(b, v, Data);
    print("Balance of ");
    print(#getCaller);
    print(" is ");
    print(balanceOf(#getCaller));
    print("\n");
    print("Balance of ");
    print(b);
    print(" is ");
    print(balanceOf(b));
    print("\n");

  syntax Stmt ::= "test.operatorSend" "(" AExp "," AExp "," AExp "," Data "," Data ")" [macro]
  rule test.operatorSend(From, To, Value, Data, OperatorData) =>
    a = From;
    b = To;
    v = Value;
    print(#getCaller);
    print(" is sending ");
    print(v);
    print(" from ");
    print(a);
    print(" to ");
    print(b);
    print(" (data:\"");
    print(Data);
    print("\"), ");
    print(" (operatorData:\"");
    print(OperatorData);
    print("\")\n");
    operatorSend(a, b, v, Data, OperatorData);
    print("Balance of ");
    print(a);
    print(" is ");
    print(balanceOf(a));
    print("\n");
    print("Balance of ");
    print(b);
    print(" is ");
    print(balanceOf(b));
    print("\n");

  syntax Stmt ::= "test.burn" "(" AExp ")" [macro]
  rule test.burn(Value) =>
    v = Value;
    print("Burning ");
    print(v);
    print(" units from ");
    println(#getCaller);
    burn(v);
    print("Balance of ");
    print(#getCaller);
    print(" is ");
    println(balanceOf(#getCaller));
    test.totalSupply();

  syntax Stmt ::= "test.operatorBurn" "(" AExp "," AExp "," Data ")" [macro]
  rule test.operatorBurn(From, Value, OperatorData) =>
    a = From;
    v = Value;
    print(#getCaller);
    print(" is burning ");
    print(v);
    print(" units from ");
    print(a);
    print(" (operatorData:\"");
    print(OperatorData);
    print("\")\n");
    operatorBurn(a, v, OperatorData);
    print("Balance of ");
    print(a);
    print(" is ");
    println(balanceOf(a));
    test.totalSupply();

  syntax Stmt ::= "test.operatorMint" "(" AExp "," AExp "," Data "," Data ")" [macro]
  rule test.operatorMint(To, Value, Data, OperatorData) =>
    b = To;
    v = Value;
    print(#getCaller);
    print(" is minting ");
    print(v);
    print(" for ");
    print(b);
    print(" (data:\"");
    print(Data);
    print("\"), ");
    print(" (operatorData:\"");
    print(OperatorData);
    print("\")\n");
    operatorMint(b, v, Data, OperatorData);
    print("Balance of ");
    print(b);
    print(" is ");
    println(balanceOf(b));
    test.totalSupply();

  syntax Stmt ::= "test.allowance" "(" AExp "," AExp ")"   [macro]
  rule test.allowance(Owner, Spender) =>
    a = Owner;
    b = Spender;
    print("Allowance of ");
    print(a);
    print(" for ");
    print(b);
    print(" is ");
    print(allowance(a,b));
    print("\n");

  syntax Stmt ::= "test.approve" "(" AExp "," AExp ")"   [macro]
  rule test.approve(Spender, Allowance) =>
    b = Spender;
    v = Allowance;
    print(caller);
    print(" is approving allowance ");
    print(v);
    print(" for ");
    print(b);
    print("\n");
    approve(b, v);

  syntax Stmt ::= "test.transfer" "(" AExp "," AExp ")"  [macro]
  rule test.transfer(To, Value) =>
    b = To;
    v = Value;
    print(caller);
    print(" is transferring ");
    print(v);
    print(" to ");
    print(b);
    print("\n");
    transfer(b,v);
    print("Balance of ");
    print(caller);
    print(" is ");
    print(balanceOf(caller));
    print("\n");
    print("Balance of ");
    print(b);
    print(" is ");
    print(balanceOf(b));
    print("\n");
    print("Allowance of ");
    print(caller);
    print(" for ");
    print(b);
    print(" is ");
    print(allowance(caller,b));
    print("\n");

  syntax Stmt ::= "test.transferFrom" "(" AExp "," AExp "," AExp ")"  [macro]
  rule test.transferFrom(From, To, Value) =>
    a = From;
    b = To;
    v = Value;
    print(caller);
    print(" is transferring ");
    print(v);
    print(" from ");
    print(a);
    print(" to ");
    print(b);
    print("\n");
    transferFrom(a,b,v);
    print("Balance of ");
    print(a);
    print(" is ");
    print(balanceOf(a));
    print("\n");
    print("Balance of ");
    print(b);
    print(" is ");
    print(balanceOf(b));
    print("\n");
    print("Allowance of ");
    print(a);
    print(" for ");
    print(caller);
    print(" is ");
    print(allowance(a,caller));
    print("\n");

endmodule
