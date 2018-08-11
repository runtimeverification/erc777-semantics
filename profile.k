module UNDEF

rule #senderHook ( Holder ) => ?_

rule #receiverHook ( Holder ) => ?_

endmodule


module UTILS

rule #top => #rangeSet ( 0 .. #max )

rule #max => #pow256 -Int 1

endmodule
