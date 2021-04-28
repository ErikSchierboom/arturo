
######################################################
# Arturo
# Programming Language + Bytecode VM compiler
# (c) 2019-2021 Yanis Zafirópulos
#
# @file: helpers/js.nim
######################################################

#=======================================
# Libraries
#=======================================

import jsre

#=======================================
# Methods
#=======================================

func newRegExp(pattern: string, flags: string): RegExp =
    newRegExp(pattern.cstring, flags.cstring)

func replace*(pattern: cstring, self: RegExp, replacement: cstring): cstring {.importjs: "#.replace(#,#)".}
  ## Returns a new string with some or all matches of a pattern replaced by given replacement

func replace*(pattern: string, self: RegExp, replacement: string): cstring =
    replace(pattern.cstring, self, replacement.cstring)

func replaceAll*(pattern: cstring, self: RegExp, replacement: cstring): cstring {.importjs: "#.replaceAll(#,#)".}
  ## Returns a new string with all matches of a pattern replaced by given replacement

func split*(pattern: cstring, self: RegExp): seq[cstring] {.importjs: "#.split(#)".}
  ## Divides a string into an ordered list of substrings and returns the array

func match*(pattern: cstring, self: RegExp): seq[cstring] {.importjs: "#.match(#)".}
  ## Returns an array of matches of a RegExp against given string

func startsWith*(pattern: cstring; self: RegExp): bool =
  ## Tests if string starts with given RegExp
  test(newRegExp(("^" & $(self.source)).cstring, self.flags), pattern)

func endsWith*(pattern: cstring; self: RegExp): bool =
  ## Tests if string ends with given RegExp
  test(newRegExp(($(self.source) & "$").cstring, self.flags), pattern)