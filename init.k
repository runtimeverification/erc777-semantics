module INIT

rule #initBalances ( Holder Holders ) => Holder |-> 0 #initBalances ( Holders )
rule #initBalances ( .Holders ) => .Map

rule #initOperators ( Holder Holders , DefaultOperators ) => Holder |-> { Holder } U DefaultOperators #initOperators ( Holders , DefaultOperators )
rule #initOperators ( .Holders ) => .Map

rule #initSenderHooks ( Holder Holders ) => Holder |-> #senderHook ( Holder ) #initSenderHooks ( Holders )
rule #initSenderHooks ( .Holders ) => .Map

rule #initReceiverHooks ( Holder Holders ) => Holder |-> #receiverHook ( Holder ) #initReceiverHooks ( Holders )
rule #initReceiverHooks ( .Holders ) => .Map

endmodule
