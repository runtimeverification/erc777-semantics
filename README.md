ERC20-K: Formal Executable Specification of ERC20
=================================================

Author: [Daejun Park and Denis Bogdanas](https://runtimeverification.com/team/)

Date: 18 September 2018

## Abstract

The [ERC777 standard](https://github.com/ethereum/EIPs/blob/master/EIPS/eip-777.md)
provides basic functionality to transfer tokens and to be approved so
they can be spent by another on-chain third party.
It supersedes the very popular ERC20, by giving account holders more control
over token transactions.

ERC777-K is a complete formal specification of the ERC777 standard,
that, in a simplified way, supports all the behaviors from the standard.

Specifically, it is a *formal executable semantics* of a *refinement of the
ERC777 standard*, using the [K framework](http://kframework.org).

ERC777-K clarifies what data (accounts, token amounts, etc.) are handled by
the various ERC777 functions and the precise meaning of those functions on such
data.

ERC777 explicitly allows certain implementation-dependent behaviors.
For example, in certain conditions the contract can either
accept or reject a token transfer at its discretion.
ERC777-K is parametric, in a simplified way, with respect to such choices.
ERC777-K can be configured, for any choice-dependent operation, to either
accept or reject it. This is enough for testing purposes.

In addition ERC777 heavily relies on another standard, ERC820, for
allowing accounts to register "hooks", e.g. custom functions that are
triggered once certain operations happen.
We do not model this hook registration process, as it is orthogonal to ERC777,
and would require significant extra complexity. Instead, we provide
two builtin implementations for hooks, which are just enough
to test the standard.

ERC777 also allows the contract to be backwards compatible with the oder ERC20
standard, and provide both ERC777 and ERC20 interfaces at the same time.
In this case functionality of certain ERC20 functions is different from the
original ERC20. To capture this functionality, ERC777-K also models the updated
ERC20 functions.

During development, we discovered a number of ambiguities in the standard which
we documented and delivered to the authors of ERC777:
https://github.com/runtimeverification/erc777-semantics/wiki/Issues

Being executable, ERC777-K can also be tested for increased confidence.
Driven by the semantic rules that form ERC777-K, as well as by their side
conditions, we manually but systematically produced and provide a test-suite
consisting of several dozens of tests which we believe cover all the corner
cases.
We encourage you to analyze these tests and use them to test your
implementations.
Please contribute with more tests if you think that we left any interesting
behaviors uncovered.

## Motivation

[KEVM](https://github.com/kframework/evm-semantics) makes it possible to
rigorously verify smart contracts at the Ethereum Virtual Machine (EVM) level
against higher level specifications.
Such contracts will be the future ERC777 token implementations, 
written in languages like Solidity or Viper.
But what does "verify smart contracts" really mean?
When formal verification is sought, a property (or specification) that the
code must satisfy must be available.
To our knowledge, there was no such formal specification for ERC777, or
for ERC777 variants, available at the time of this writing (September 2018).

The existing ERC777 specifications are either too informal to serve as a formal
specification for verification purposes, or they are not executable.
For example, the
[standard](https://github.com/ethereum/EIPs/blob/master/EIPS/eip-777.md)
is rather informal and imprecise, in spite of being called
*formalized*.

## Structure

The main ERC20-K specification is defined and extensively commented in this
file:

* [erc777.md](erc777.md)

The following folder contains unit tests for the ERC777-K specification,
that is, small programs that exercise the various ERC20 functions in various
contexts.
For that, a programming language needs to be first defined on top of ERC20-K:

* [tests](tests)

## Contribute

We welcome contributions!
The easiest way to contribute is to add more tests to existing languages in the
folder [tests](tests).
A more involved way to contribute is to add new languages under [tests](tests),
together with their own unit tests.
It would be nice to cover a variety of language paradigms, such as more
imperative language, object-oriented, functional, and even logical programming
languages.
Finally, you can adopt ERC20-K as *the standard specification of ERC20* when
testing and verifying smart contracts and this way:
(1) we as a community converge on one
formal standard for token correctness, as opposed to each group having
different versions and opinions about what correctness means, most likely
missing some corner cases and thus allowing vulnerabilities; and
(2) we as a community improve the test suite, for the benefit of us all.

