module AXIOMATIZATION

rule 0 <=Int #senderHook ( Holder )              => true
rule         #senderHook ( Holder ) <Int #pow256 => true

rule 0 <=Int #receiverHook ( Holder )              => true
rule         #receiverHook ( Holder ) <Int #pow256 => true

endmodule
