######################################################
# Arturo
# Programming Language + Bytecode VM compiler
# (c) 2019-2021 Yanis Zafirópulos
#
# @file: library/Io.nim
######################################################

#=======================================
# Pragmas
#=======================================

{.used.}

#=======================================
# Libraries
#=======================================

when not defined(WEB):
    import terminal

import algorithm, rdstdin, sequtils
import tables

when not defined(windows):
    import linenoise

import helpers/repl

import vm/lib
import vm/[eval, exec]
import vm/values/printable

#=======================================
# Methods
#=======================================

proc defineSymbols*() =

    when defined(VERBOSE):
        echo "- Importing: Io"

    builtin "clear",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "clear terminal",
        args        = NoArgs,
        attrs       = NoAttrs,
        returns     = {Nothing},
        example     = """
            clear             ; (clears the screen)
        """:
            ##########################################################
            when not defined(windows) and not defined(WEB):
                clearScreen()
            else:
                discard
    
    when not defined(WEB):
        builtin "cursor",
            alias       = unaliased, 
            rule        = PrefixPrecedence,
            description = "turn cursor visibility on/off",
            args        = {
                "visible"   : {Boolean}
            },
            attrs       = NoAttrs,
            returns     = {Nothing},
            example     = """
                cursor false    ; (hides the cursor)
                cursor true     ; (shows the cursor)
            """:
                ##########################################################
                if x.b:
                    stdout.showCursor()
                else:
                    stdout.hideCursor()

        builtin "goto",
            alias       = unaliased, 
            rule        = PrefixPrecedence,
            description = "move cursor to given coordinates",
            args        = {
                "x"     : {Null,Integer},
                "y"     : {Null,Integer}
            },
            attrs       = NoAttrs,
            returns     = {Nothing},
            example     = """
                goto 10 15      ; (move cursor to column 10, line 15)
                goto 10 ø       ; (move cursor to column 10, same line)
            """:
                ##########################################################
                if x.kind==Null:
                    if y.kind==Null:
                        discard
                    else:
                        when defined(windows):
                            stdout.setCursorYPos(y.i)
                        else:
                            discard
                else:
                    if y.kind==Null:
                        stdout.setCursorXPos(x.i)
                    else:
                        stdout.setCursorPos(x.i, y.i)

        builtin "input",
            alias       = unaliased, 
            rule        = PrefixPrecedence,
            description = "print prompt and get user input",
            args        = {
                "prompt": {String}
            },
            attrs       = {
                "repl"      : ({Boolean},"get input as if in a REPL"),
                "history"   : ({String},"set path for saving history"),
                "complete"  : ({Block},"use given array for auto-completions"),
                "hint"      : ({Dictionary},"use given dictionary for typing hints")
            },
            returns     = {String},
            example     = """
                name: input "What is your name? "
                ; (user enters his name: Bob)
                
                print ["Hello" name "!"]
                ; Hello Bob!
            """:
                ##########################################################
                if (popAttr("repl")!=VNULL):
                    when defined(windows):
                        push(newString(readLineFromStdin(x.s)))
                    else:
                        var historyPath: string = ""
                        var completionsArray: ValueArray = @[]
                        var hintsTable: ValueDict = initOrderedTable[string,Value]()

                        if (let aHistory = popAttr("history"); aHistory != VNULL):
                            historyPath = aHistory.s

                        if (let aComplete = popAttr("complete"); aComplete != VNULL):
                            completionsArray = aComplete.a

                        if (let aHint = popAttr("hint"); aHint != VNULL):
                            hintsTable = aHint.d

                        push(newString(replInput(x.s, historyPath, completionsArray, hintsTable)))
                else:
                    push(newString(readLineFromStdin(x.s)))


    builtin "print",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "print given value to screen with newline",
        args        = {
            "value" : {Any}
        },
        attrs       = NoAttrs,
        returns     = {Nothing},
        example     = """
            print "Hello world!"          ; Hello world!
        """:
            ##########################################################
            if x.kind==Block:
                when not defined(WEB):
                    let xblock = doEval(x)
                    let stop = SP
                    discard doExec(xblock)

                    var res: ValueArray = @[]
                    while SP>stop:
                        res.add(pop())

                    for r in res.reversed:
                        stdout.write($(r))
                        stdout.write(" ")

                    stdout.write("\n")
                    stdout.flushFile()
            else:
                echo $(x)

    when not defined(WEB):
        builtin "prints",
            alias       = unaliased, 
            rule        = PrefixPrecedence,
            description = "print given value to screen",
            args        = {
                "value" : {Any}
            },
            attrs       = NoAttrs,
            returns     = {Nothing},
            example     = """
                prints "Hello "
                prints "world"
                print "!"             
                
                ; Hello world!
            """:
                ##########################################################
                if x.kind==Block:
                    let xblock = doEval(x)
                    let stop = SP
                    discard doExec(xblock)#, depth+1)

                    var res: ValueArray = @[]
                    while SP>stop:
                        res.add(pop())

                    for r in res.reversed:
                        stdout.write($(r))
                        stdout.write(" ")

                    stdout.flushFile()
                else:
                    stdout.write($(x))
                    stdout.flushFile()

        builtin "terminal",
            alias       = unaliased, 
            rule        = PrefixPrecedence,
            description = "get info about terminal",
            args        = NoArgs,
            attrs       = NoAttrs,
            returns     = {Dictionary},
            example     = """
                print terminal      ; [width:107 height:34]
                terminal\width      ; => 107
            """:
                ##########################################################
                let size = terminalSize()
                var ret = {
                    "width": newInteger(size[0]),
                    "height": newInteger(size[1])
                }.toOrderedTable()

                push(newDictionary(ret))

#=======================================
# Add Library
#=======================================

Libraries.add(defineSymbols)