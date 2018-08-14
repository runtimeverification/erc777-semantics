require "erc777-syntax.k"

module ERC777-UTILS

  imports ERC777-SYNTAX
  imports BOOL

  rule #require ( B:Bool ) => .        requires B
  rule #require ( B:Bool ) => #revert  requires notBool B

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
