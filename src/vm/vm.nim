######################################################
# Arturo
# Programming Language + Bytecode VM compiler
# (c) 2019-2021 Yanis Zafirópulos
#
# @file: vm/vm.nim
######################################################

#=======================================
# Libraries
#=======================================

import os, random, strutils, tables

import vm/[
    env, 
    errors, 
    eval, 
    exec, 
    globals, 
    parse, 
    stack, 
    values/value, 
    version
]

import library/Arithmetic   as ArithmeticLib
import library/Binary       as BinaryLib
import library/Collections  as CollectionsLib
import library/Comparison   as ComparisonLib
import library/Converters   as ConvertersLib
import library/Core         as CoreLib
import library/Crypto       as CryptoLib
import library/Databases    as DatabasesLib
import library/Dates        as DatesLib
import library/Files        as FilesLib
import library/Io           as IoLib
import library/Iterators    as IteratorsLib
import library/Logic        as LogicLib
import library/Net          as NetLib
import library/Numbers      as NumbersLib
import library/Paths        as PathsLib
import library/Reflection   as ReflectionLib
import library/Sets         as SetsLib
import library/Strings      as StringsLib
import library/System       as SystemLib
import library/Ui           as UiLib

#=======================================
# Variables
#=======================================

var
    initialized     : bool = false

#=======================================
# Helpers
#=======================================

proc setupLibrary*() =
    for i,importLibrary in Libraries:
        importLibrary()

template initialize*(args: seq[string], filename: string, isFile:bool, scriptInfo:ValueDict = initOrderedTable[string,Value](), mutedColors: bool = false) =
    # function arity
    Arities = initTable[string,int]()
    # stack
    createMainStack()

    # attributes
    createAttrsStack()

    # # opstack
    # if DoDebug:
    #     OpStack[0] = opNop
    #     OpStack[1] = opNop
    #     OpStack[2] = opNop
    #     OpStack[3] = opNop
    #     OpStack[4] = opNop
    
    # random number generator
    randomize()

    # environment
    initEnv(
        arguments = args, 
        version = ArturoVersion,
        build = ArturoBuild,
        script = scriptInfo,
        muted = mutedColors
    )

    when not defined(WEB):
        # paths
        if isFile: env.addPath(filename)
        else: env.addPath(getCurrentDir())

    Syms = initOrderedTable[string,Value]()

    # library
    setupLibrary()

    # set VM as initialized
    initialized = true

template handleVMErrors*(blk: untyped): untyped =
    try:
        blk
    except:
        let e = getCurrentException()
        showVMErrors(e)
        quit(1)

#=======================================
# Methods
#=======================================

proc runBytecode*(code: Translation, filename: string, args: seq[string]) =
    handleVMErrors:
        initialize(args, filename, isFile=true)

        discard doExec(code)

proc run*(code: var string, args: seq[string], isFile: bool, doExecute: bool = true, muted: bool = false): Translation {.exportc:"run".} =
    handleVMErrors:
        
        let (mainCode, scriptInfo) = doParseAll(code, isFile)

        if not initialized:
            initialize(
                args, 
                code, 
                isFile=isFile, 
                parseData(doParse(scriptInfo, false)).d,
                muted
            )

        let evaled = mainCode.doEval()

        if doExecute:
            discard doExec(evaled)

        return evaled
    