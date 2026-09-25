#!/bin/bash
nagelfar.sh \
    | grep -v Unknown.command \
    | grep -v Unknown.variable \
    | grep -v No.info.on.package.*found \
    | grep -v Variable.*is.never.read \
    | grep -v Wrong.number.of.arguments.*to.*self \
    | grep -v Wrong.number.of.arguments.*to..string.match \
    | grep -v Unknown.subcommand..home..to..file \
    | grep -v Found.constant.*which.is.also.a.variable \
    | grep -v Non.static.subcommand.to..my.
du -sh .git
ls -sh .*.str
clc -s -l tcl
str s
git st
