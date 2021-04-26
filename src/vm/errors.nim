######################################################
# Arturo
# Programming Language + Bytecode VM compiler
# (c) 2019-2021 Yanis Zafirópulos
#
# @file: vm/errors.nim
######################################################

#=======================================
# Libraries
#=======================================

when not defined(WEB):
    import re
import sequtils
import strformat, strutils, sugar

import helpers/colors
import helpers/strings

#=======================================
# Types
#=======================================

type
    ReturnTriggered* = ref object of Defect
    BreakTriggered* = ref object of Defect
    ContinueTriggered* = ref object of Defect
    VMError* = ref object of Defect

#=======================================
# Constants
#=======================================

const
    RuntimeError*   = "Runtime"
    AssertionError* = "Assertion"
    SyntaxError*    = "Syntax"
    ProgramError*   = "Program"
    CompilerError*  = "Compiler"

    Alternative*  = "perhaps you meant"

#=======================================
# Main
#=======================================

proc panic*(context: string, error: string) =
    var errorMsg = error
    # if $(context) notin [AssertionError, SyntaxError, CompilerError]:
    #    errorMsg &= getOpStack()
    raise VMError(name: context, msg:move errorMsg)

#=======================================
# Helpers
#=======================================

proc showVMErrors*(e: ref Exception) =
    var header: string
    try:
        header = $(e.name)

        if $(header) notin [RuntimeError, AssertionError, SyntaxError, ProgramError, CompilerError]:
            header = RuntimeError
    except:
        header = "HEADER"

    let marker = ">>"
    let separator = "|"
    let indent = repeat(" ", header.len + marker.len + 2)

    when not defined(WEB):
        var message = e.msg.replacef(re"_([^_]+)_",fmt("{bold()}$1{resetColor}"))
    else:
        var message = "MESSAGE"

    let errMsgParts = message.split(";").map((x)=>(strutils.strip(x)).replace("~%"," ").replace("%&",";").replace("T@B","\t"))
    let alignedError = align("error", header.len)
    var errMsg = errMsgParts[0] & fmt("\n{bold(redColor)}{repeat(' ',marker.len)} {alignedError} {separator}{resetColor} ")
    if errMsgParts.len > 1:
        errMsg &= errMsgParts[1..^1].join(fmt("\n{indent}{bold(redColor)}{separator}{resetColor} "))
    echo fmt("{bold(redColor)}{marker} {header} {separator}{resetColor} {errMsg}")

#=======================================
# Methods
#=======================================

## Compiler errors

proc CompilerError_ScriptNotExists*(name: string) =
    panic CompilerError,
          "given script path doesn't exist:" & ";" &
          "_" & name & "_"

## Syntax errors

proc SyntaxError_MissingClosingBracket*(lineno: int, context: string) =
    panic SyntaxError,
          "missing closing bracket" & ";;" & 
          "line: " & $(lineno) & ";" &
          "near: " & context

proc SyntaxError_UnterminatedString*(strtype: string, lineno: int, context: string) =
    var strt = strtype
    if strt!="": strt &= " "
    panic SyntaxError,
          "unterminated " & strt & "string;;" & 
          "line: " & $(lineno) & ";" &
          "near: " & context

proc SyntaxError_NewlineInQuotedString*(lineno: int, context: string) =
    panic SyntaxError,
          "newline in quoted string;" & 
          "for multiline strings, you could use either:;" &
          "curly blocks _{..}_ or _triple \"-\"_ templates;;" &
          "line: " & $(lineno) & ";" &
          "near: " & context

proc SyntaxError_EmptyLiteral*(lineno: int, context: string) =
    panic SyntaxError,
          "empty literal value;;" & 
          "line: " & $(lineno) & ";" &
          "near: " & context

## Assertion errors

proc AssertionError_AssertionFailed*(context: string) =
    panic AssertionError,
          context

## Runtime errors

proc RuntimeError_IntegerParsingOverflow*(number: string) =
    panic RuntimeError,
          "number parsing overflow - up to " & $(sizeof(int) * 8) & "-bit integers supported" & ";" &
          "given: " & truncate(number, 20)

proc RuntimeError_IntegerOperationOverflow*(operation: string, argA, argB: string) =
    panic RuntimeError,
            "number operation overflow - up to " & $(sizeof(int) * 8) & "-bit integers supported" & ";" &
            "attempted: " & operation & ";" &
            "with: " & truncate(argA & " " & argB, 30)

proc RuntimeError_NumberOutOfPermittedRange*(operation: string, argA, argB: string) =
    panic RuntimeError,
            "number operator out of range - up to " & $(sizeof(int) * 8) & "-bit integers supported" & ";" &
            "attempted: " & operation & ";" &
            "with: " & truncate(argA & " " & argB, 30)

proc RuntimeError_OutOfBounds*(indx: int, maxRange: int) =
    panic RuntimeError,
          "array index out of bounds: " & $(indx) & ";" & 
          "valid range: 0.." & $(maxRange)

proc RuntimeError_SymbolNotFound*(sym: string, alter: seq[string]) =
    let sep = ";" & repeat("~%",Alternative.len - 2) & "or... "
    panic RuntimeError,
          "symbol not found: " & sym & ";" & 
          "perhaps you meant... " & alter.map((x) => "_" & x & "_ ?").join(sep)

proc RuntimeError_KeyNotFound*(sym: string, alter: seq[string]) =
    let sep = ";" & repeat("~%",Alternative.len - 2) & "or... "
    panic RuntimeError,
          "dictionary key not found: " & sym & ";" & 
          "perhaps you meant... " & alter.map((x) => "_" & x & "_ ?").join(sep)

proc RuntimeError_NotEnoughArguments*(functionName:string, functionArity: int) =
    panic RuntimeError,
          "cannot perform _" & (functionName) & "_;" & 
          "not enough parameters: " & $(functionArity) & " required"

template RuntimeError_WrongArgumentType*(functionName:string, argumentPos: int, expected: untyped): untyped =
    let expectedValues = toSeq((expected[argumentPos][1]).items)

    panic RuntimeError, 
          getWrongArgumentTypeErrorMsg(functionName, argumentPos, expectedValues)

proc RuntimeError_CannotConvert*(arg,fromType,toType: string) =
    panic RuntimeError,
          "cannot convert argument: " & truncate(arg,20) & ";" &
          "from :" & (fromType).toLowerAscii() & ";" &
          "to   :" & (toType).toLowerAscii()

proc RuntimeError_ConversionFailed*(arg,fromType,toType: string) =
    panic RuntimeError,
          "conversion failed: " & truncate(arg,20) & ";" &
          "from :" & (fromType).toLowerAscii() & ";" &
          "to   :" & (toType).toLowerAscii()

proc RuntimeError_LibraryNotLoaded*(path: string) =
    panic RuntimeError,
          "dynamic library could not be loaded:" & ";" &
          path

proc RuntimeError_LibrarySymbolNotFound*(path: string, sym: string) =
    panic RuntimeError,
          "symbol not found: " & sym & ";" & 
          "in library: " & path

proc RuntimeError_ErrorLoadingLibrarySymbol*(path: string, sym: string) =
    panic RuntimeError,
          "error loading symbol: " & sym & ";" & 
          "from library: " & path

proc RuntimeError_OperationNotPermitted*(operation: string) =
    panic RuntimeError,
          "unsafe operation: " & operation & ";" &
          "not permitted in online playground"

# TODO Re-establish stack trace debug reports

# var
#     OpStack*    : array[5,OpCode]
#     ConstStack* : ValueArray
# proc getOpStack*(): string =
#     try:
#         var ret = ";;"
#         ret &= (fg(grayColor)).replace(";","%&") & "\b------------------------------;" & resetColor
#         ret &= (fg(grayColor)).replace(";","%&") & "bytecode stack trace:;" & resetColor
#         ret &= (fg(grayColor)).replace(";","%&") & "\b------------------------------;" & resetColor
#         for i in countdown(4,0):
#             let op = (OpCode)(OpStack[i])
#             if op!=opNop :
#                 ret &= (fg(grayColor)).replace(";","%&") & "\b>T@B" & ($(op)).replace("op","").toUpperAscii()
#                 case op:
#                     of opConstI0..opConstI10:
#                         let indx = (int)(op)-(int)opConstI0
#                         if indx>=0 and indx<ConstStack.len:
#                             ret &= " (" & $(ConstStack[indx]) & ")"
#                     of opPush0..opPush30:
#                         let indx = (int)(op)-(int)opPush0
#                         if indx>=0 and indx<ConstStack.len:
#                             ret &= " (" & $(ConstStack[indx]) & ")"
#                     of opStore0..opStore30:
#                         let indx = (int)(op)-(int)opStore0
#                         if indx>=0 and indx<ConstStack.len:
#                             ret &= " (" & $(ConstStack[indx]) & ")"
#                     of opLoad0..opLoad30:
#                         let indx = (int)(op)-(int)opLoad0
#                         if indx>=0 and indx<ConstStack.len:
#                             ret &= " (" & $(ConstStack[indx]) & ")"
#                     of opCall0..opCall30: 
#                         let indx = (int)(op)-(int)opCall0
#                         if indx>=0 and indx<ConstStack.len:
#                             ret &= " (" & $(ConstStack[indx]) & ")"
#                     else:
#                         discard
                
#                 ret &= resetColor
                    
#             if i!=0:
#                 ret &= ";"

#         ret
#     except:
#         ""