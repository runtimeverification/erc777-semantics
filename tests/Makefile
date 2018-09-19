# to enable the expansion of ** into an arbitrary number of directories.
SHELL=/bin/bash -O extglob -c

DEF=erc777-imp
EXT=imp
TESTDIR=**
KOMPILE_FLAGS=--backend java --syntax-module ERC777-IMP
KRUN_FLAGS+=--output none --smt none

include $(K_HOME)/k-distribution/include/ktest.mak
