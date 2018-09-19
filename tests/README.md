IMP and ERC777-K Tests in IMP
============================

Although the ERC777-K semantics was defined to be executable, it requires
an execution environment where its semantic rules can match and apply.
K allows definitions to extend other definitions, by means of importing
and automatically adapting their syntax, configuration and rules.
In particular, we can easily define almost *any programming language
on top of ERC777-K*.

Once you have a language that incorporates ERC777-K, you can at minimum
execute programs that exercise the ERC777 functions.  (You can also verify
such programs, and thus prove properties about ERC777-K, but we do not
elaborate on that here, yet.)  In particular, you can create test-suites that
thoroughly test the ERC777-K specification and thus the ERC777 standard.
Of course, you can do the same with other token specifications, by
modifying our ERC777-K spec accordingly, or replacing it completely.

## IMP

At the time of this writing (September 2018), we have done the above with
only one programming language, the simplest of them all, IMP, which is also
one of the languages that comes with the K distribution.
To learn IMP's semantics and a bit more K, we recommend 
[k-distribution/tutorial/1_k/2_imp/lesson_5/imp.k](https://github.com/kframework/k/blob/master/k-distribution/tutorial/1_k/2_imp/lesson_5/imp.k).
IMP is a paradigmatic imperative language, with variable
declarations only at the top, assignments, conditional statement, and
while statements.
For interactivity, we added to our IMP here basic I/O (taken over from
[IMP++](https://github.com/kframework/k/blob/master/k-distribution/tutorial/1_k/4_imp%2B%2B/lesson_8/imp.k)).

The IMP language definition is in
* [erc777-imp.k](erc777-imp.k)

## IMP tests

The subfolders contain more than 100 unit tests for ERC777-K.

Each test is an IMP program stored in a file with extension `imp`, and its
expected output is in a corresponding file with extension `.imp.out`.
For example:
* [operatorSend_AllDistinct-BalanceOk.imp](erc777/05_operatorSend/operatorSend_AllDistinct-BalanceOk.imp)
* [operatorSend_AllDistinct-BalanceOk.imp.out](erc777/05_operatorSend/operatorSend_AllDistinct-BalanceOk.imp.out)

Each test starts with a statement `test.preamble();`, which initializes
the ERC777-K with a particular configuration holding 10 accounts with balances
10, 20, ..., 100, respectively, and the current caller `7`.
Accounts 8 and 9 are default operators. Accounts 9 and 10 are contract accounts,
all others are regular accounts.
See [erc777-imp.k](erc777-imp.k) for the precise definition.
Then the test performs one or more ERC777-K transactions using primitives
suffixed with `test.`, such as `test.send`, `test.authorizeOperator`, etc.
See again [erc777-imp.k](erc777-imp.k) for the precise definitions of these primitives;
they essentially invoke the corresponding ERC777-K primitives and print some
info.

## Kompiling IMP and Executing Tests

Before you can execute tests, you need to compile the `imp.k` definition with
the this command:
* `make kompile`

Ignore the warning
(K likes us to put the syntax of a language in a separate module).
Then you can run tests with the `krun` command, using the `none` output mode
if you do not want to see the resulting configuration (type `krun --help` for
all options):
* `krun erc777/05_operatorSend/operatorSend_AllDistinct-BalanceOk.imp -o none`

This command will output:
```
Changing the caller to 9
9 is sending 23 from 7 to 5 (data:""),  (operatorData:"")
Balance of 7 is 47
Balance of 5 is 73
```
Finally, you can use this command with the provided to run all the tests:
* `make krun`

This may 1 hour or more depending on your computer.

Alternatively, you can run only the tests inside a specific folder.
For this, `cd` into the folder and run:
* `make krun`
