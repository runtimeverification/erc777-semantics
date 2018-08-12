require "erc777.k"

module ERC777-TEST-SYNTAX

  imports ERC777-SYNTAX
  imports DOMAINS-SYNTAX

  // Sorts

  syntax Number ::= Int

  syntax Address ::= Int

  syntax Data ::= String

  //

  syntax Exp ::= Function | Event
               | Int | Bool | String

  syntax Exp ::= #print ( Exp ) [strict]

  syntax Exps ::= Exp ";" Exps | ";;"

endmodule

module ERC777-TEST

  imports ERC777-TEST-SYNTAX
  imports ERC777
  imports DOMAINS

  // Parameters

  rule #name => "RVToken"

  rule #symbol => "RVT"

  rule #granularity => 1

  // Test Setup

  rule #addresses => 0 1 2 3 4 5 6 7 8 9 .Addresses

  rule #defaultOperators => SetItem(8) SetItem(9)

  rule #senderHook ( _ ) => 6

  rule #receiverHook ( _ ) => 7

  // Test Harness

  configuration
     <TEST>
       initERC777Cell(Init)
       <input stream="stdin"> .List </input>
       <output stream="stdout"> .List </output>
     </TEST>

  syntax KResult ::= Int | Bool | String

  rule E:Exp ; Es:Exps => E ~> Es

  rule <k> #print ( V ) => . ... </k>
       <output> ... .List => ListItem(V) ListItem("\n") </output>
       requires isInt(V) orBool isString(V)

  rule #print ( true )  => #print ( "true" )
  rule #print ( false ) => #print ( "false" )

  rule #sum ( ListItem(I:Int) S ) => I +Int #sum ( S )
  rule #sum ( .List ) => 0

  rule X  ==Address Y => X  ==Int Y
  rule X =/=Address Y => X =/=Int Y

endmodule
