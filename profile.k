module PARAMETERS

rule #defaultOperators => ?_

endmodule


module UNDEF

rule #senderHook ( Holder ) => ?_

rule #receiverHook ( Holder ) => ?_

endmodule


module UTILS

rule #top => #rangeSet ( 0 .. #max )

rule #max => #pow256 -Int 1

rule #holders => ...

rule #require ( B ) => .        requires B
rule #require ( B ) => #revert  requires notBool B

rule #ite ( B , T , F ) => T  requires B
rule #ite ( B , T , F ) => F  requires notBool B

rule #mayRevert => #revert
rule #mayRevert => .

endmodule
