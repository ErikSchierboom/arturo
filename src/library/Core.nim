######################################################
# Arturo
# Programming Language + Bytecode VM compiler
# (c) 2019-2021 Yanis Zafirópulos
#
# @file: library/Core.nim
######################################################

#=======================================
# Pragmas
#=======================================

{.used.}

#=======================================
# Libraries
#=======================================

import algorithm, sequtils

import helpers/datasource
import helpers/ffi

import vm/lib
import vm/[env, errors, eval, exec, parse]

#=======================================
# Methods
#=======================================

proc defineSymbols*() =

    when defined(VERBOSE):
        echo "- Importing: Core"

    builtin "break",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "break out of current block or loop",
        args        = NoArgs,
        attrs       = NoAttrs,
        returns     = {Block},
        example     = """
            loop 1..5 'x [
                print ["x:" x]
                if x=3 -> break
                print "after check"
            ]
            print "after loop"

            ; x: 1
            ; after check
            ; x: 2
            ; after check
            ; x: 3
            ; after loop
        """:
            ##########################################################
            raise BreakTriggered()

    # TODO(Core\call) Needs fix
    #  The function seems to be working fine with function 'literals but not with function values passed directly
    #  labels: library,bug,critical
    builtin "call",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "call function with given list of parameters",
        args        = {
            "function"  : {String,Literal,Function},
            "params"    : {Block}
        },
        attrs       = {
            "external"  : ({String},"path to external library"),
            "expect"    : ({Type},"expect given return type")
        },
        returns     = {Any},
        example     = """
            multiply: function [x y][
                x * y
            ]
            
            call 'multiply [3 5]          ; => 15
            
            call $[x][x+2] [5]            ; 7
        """:
            ##########################################################
            if (let aExternal = popAttr("external"); aExternal != VNULL):
                when not defined(WEB):
                    let externalLibrary = aExternal.s

                    var expected = Nothing
                    if (let aExpect = popAttr("expect"); aExpect != VNULL):
                        expected = aExpect.t

                    push(execForeignMethod(externalLibrary, x.s, y.a, expected))
            else:
                var fun: Value

                if x.kind==Literal or x.kind==String:
                    fun = InPlace
                else:
                    fun = x

                for v in y.a.reversed:
                    push(v)

                if fun.fnKind==UserFunction:
                    discard execBlock(fun.main, args=fun.params.a, isFuncBlock=true, imports=fun.imports, exports=fun.exports)
                else:
                    fun.action()
        
    builtin "case",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "initiate a case block to check for different cases",
        args        = {
            "predicate" : {Block}
        },
        attrs       = NoAttrs,
        returns     = {Nothing},
        example     = """
            a: 2
            case [a]
                when? [<2] -> print "a is less than 2"
                when? [=2] -> print "a is 2"
                else       -> print "a is greater than 2"
        """:
            ##########################################################
            push(x)
            push(newBoolean(false))

    builtin "continue",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "immediately continue with next iteration",
        args        = NoArgs,
        attrs       = NoAttrs,
        returns     = {Block},
        example     = """
            loop 1..5 'x [
                print ["x:" x]
                if x=3 -> continue
                print "after check"
            ]
            print "after loop"

            ; x: 1 
            ; after check
            ; x: 2 
            ; after check
            ; x: 3 
            ; x: 4 
            ; after check
            ; x: 5 
            ; after check
            ; after loop
        """:
            ##########################################################
            raise ContinueTriggered()

    builtin "do",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "evaluate and execute given code",
        args        = {
            "code"  : {String,Block,Bytecode}
        },
        attrs       = {
            "import": ({Boolean},"execute at root level")
        },
        returns     = {Any,Nothing},
        example     = """
            do "print 123"                ; 123
            
            do [
                x: 3
                print ["x =>" x]          ; x => 3
            ]
            
            do.import [
                x: 3
            ]
            print ["x =>" x]              ; x => 3
            
            print do "https://raw.githubusercontent.com/arturo-lang/arturo/master/examples/projecteuler/euler1.art"
            ; 233168
        """:
            ##########################################################
            var execInParent = (popAttr("import") != VNULL)

            if x.kind==Block:
                # discard executeBlock(x)
                if execInParent:
                    discard execBlock(x, execInParent=true)
                else:
                    discard execBlock(x)
            elif x.kind==Bytecode:
                if execInParent:
                    discard execBlock(x, evaluated=(x.consts, x.instrs), execInParent=true)
                else:
                    discard execBlock(x, evaluated=(x.consts, x.instrs))
                
            else: # string
                let (src, tp) = getSource(x.s)

                if tp==FileData:
                    addPath(x.s)

                if execInParent:
                    let parsed = doParse(src, isFile=false)

                    if not isNil(parsed):
                        discard execBlock(parsed, execInParent=true)
                else:
                    let parsed = doParse(src, isFile=false)
                    if not isNil(parsed):
                        discard execBlock(parsed)

                if tp==FileData:
                    discard popPath()

    builtin "dup",
        alias       = thickarrowleft, 
        rule        = PrefixPrecedence,
        description = "duplicate the top of the stack and convert non-returning call to a do-return call",
        args        = {
            "value" : {Any}
        },
        attrs       = NoAttrs,
        returns     = {Nothing},
        example     = """
            ; a label normally consumes its inputs
            ; and returns nothing

            ; using dup before a call, the non-returning function
            ; becomes a returning one

            a: b: <= 3

            print a         ; 3
            print b         ; 3
        """:
            ##########################################################
            push(x)
            push(x)

    builtin "else",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "perform action, if last condition was not true",
        args        = {
            "otherwise" : {Block}
        },
        attrs       = NoAttrs,
        returns     = {Nothing},
        example     = """
            x: 2
            z: 3
            
            if? x>z [
                print "x was greater than z"
            ]
            else [
                print "nope, x was not greater than z"
            ]
        """:
            ##########################################################
            let y = pop() # pop the value of the previous operation (hopefully an 'if?' or 'when?')
            if not y.b: discard execBlock(x)
            
    builtin "ensure",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "assert given condition is true, or exit",
        args        = {
            "condition"     : {Block}
        },
        attrs       = NoAttrs,
        returns     = {Nothing},
        example     = """
            num: input "give me a positive number"

            ensure [num > 0]

            print "good, the number is positive indeed. let's continue..."
        """:
            ##########################################################
            discard execBlock(x)
            if not pop().b:
                AssertionError_AssertionFailed(x.codify())

    builtin "if",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "perform action, if given condition is not false or null",
        args        = {
            "condition" : {Any},
            "action"    : {Block}
        },
        attrs       = NoAttrs,
        returns     = {Nothing},
        example     = """
            x: 2
            
            if x=2 -> print "yes, that's right!"
            ; yes, that's right!
        """:
            ##########################################################
            let condition = not (x.kind==Null or (x.kind==Boolean and x.b==false))
            if condition: 
                discard execBlock(y)

    builtin "if?",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "perform action, if given condition is not false or null and return condition result",
        args        = {
            "condition" : {Any},
            "action"    : {Block}
        },
        attrs       = NoAttrs,
        returns     = {Boolean},
        example     = """
            x: 2
            
            result: if? x=2 -> print "yes, that's right!"
            ; yes, that's right!
            
            print result
            ; true
            
            z: 3
            
            if? x>z [
                print "x was greater than z"
            ]
            else [
                print "nope, x was not greater than z"
            ]
        """:
            ##########################################################
            let condition = not (x.kind==Null or (x.kind==Boolean and x.b==false))
            if condition: 
                discard execBlock(y)
                # if vmReturn:
                #     return ReturnResult
            push(newBoolean(condition))

    builtin "let",
        alias       = colon, 
        rule        = InfixPrecedence,
        description = "set symbol to given value",
        args        = {
            "symbol"    : {String,Literal},
            "value"     : {Any}
        },
        attrs       = NoAttrs,
        returns     = {Nothing},
        example     = """
            let 'x 10         ; x: 10
            print x           ; 10
        """:
            ##########################################################
            SetInPlace(y)

    builtin "new",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "create new value by cloning given one",
        args        = {
            "value"     : {Any}
        },
        attrs       = NoAttrs,
        returns     = {Any},
        example     = """
            c: "Hello"
            d: new c        ; make a copy of the older string

            ; changing one string in-place
            ; will change only the string in question

            'd ++ "World"
            print d                 ; HelloWorld
            print c                 ; Hello
        """:
            ##########################################################
            push(copyValue(x))

    constant "null",
        alias       = slashedzero,
        description = "the NULL constant":
            VNULL

    # TODO(Core\pop) verify functionality
    #  labels: library, unit-test,easy
    builtin "pop",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "pop top <number> values from stack",
        args        = {
            "number"    : {Integer}
        },
        attrs       = {
            "discard"   : ({Boolean},"do not return anything")
        },
        returns     = {Any},
        example     = """
            1 2 3
            a: pop 1        ; a: 3

            1 2 3
            b: pop 2        ; b: [3 2]

            1 2 3
            pop.discard 1   ; popped 3 from the stack
        """:
            ##########################################################
            let doDiscard = (popAttr("discard") != VNULL)

            if x.i==1:
                if doDiscard: discard pop()
                else: discard
            else:
                if doDiscard: 
                    var i = 0
                    while i<x.i:
                        discard pop()
                        i+=1
                else:
                    var res: ValueArray = @[]
                    var i = 0
                    while i<x.i:
                        res.add pop()
                        i+=1
                    push(newBlock(res))

    # TODO(Core\return): Verify return works right
    #  seems to have been disrupted after changed to error handling & breaks
    #  labels: bug, library, language, critical, unit-test
    builtin "return",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "return given value from current function",
        args        = {
            "value" : {Any}
        },
        attrs       = NoAttrs,
        returns     = {Nothing},
        example     = """
            f: function [x][ 
                loop 1..x 'y [ 
                    if y=5 [ return y*2 ] 
                ] 
                return x*2
            ]
            
            print f 3         ; 6
            print f 6         ; 10
        """:
            ##########################################################
            push(x)
            #echo "emitting: ReturnTriggered"
            raise ReturnTriggered()
            # vmReturn = true
            # # return ReturnResult
            # #return Syms

    builtin "switch",
        alias       = question, 
        rule        = InfixPrecedence,
        description = "if condition is not false or null perform given action, otherwise perform alternative action",
        args        = {
            "condition"     : {Any},
            "action"        : {Block},
            "alternative"   : {Block}
        },
        attrs       = NoAttrs,
        returns     = {Nothing},
        example     = """
            x: 2
            
            switch x=2 -> print "yes, that's right!"
                       -> print "nope, that's not right!
            ; yes, that's right!
        """:
            ##########################################################
            let condition = not (x.kind==Null or (x.kind==Boolean and x.b==false))
            if condition: 
                discard execBlock(y)
            else:
                discard execBlock(z)

    builtin "try",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "perform action and catch possible errors",
        args        = {
            "action": {Block}
        },
        attrs       = {
            "import"    : ({Boolean},"execute at root level"),
            "verbose"   : ({Boolean},"print all error messages as usual")
        },
        returns     = {Nothing},
        example     = """
            try [
                ; let's try something dangerous
                print 10 / 0
            ]
            
            ; we catch the exception but do nothing with it
        """:
            ##########################################################
            let verbose = (popAttr("verbose")!=VNULL)
            let execInParent = (popAttr("import")!=VNULL)
            try:
                discard execBlock(x, execInParent=execInParent, inTryBlock=true)
            except:
                let e = getCurrentException()
                if verbose:
                    showVMErrors(e)

    builtin "try?",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "perform action, catch possible errors and return status",
        args        = {
            "action": {Block}
        },
        attrs       = {
            "import"    : ({Boolean},"execute at root level"),
            "verbose"   : ({Boolean},"print all error messages as usual")
        },
        returns     = {Boolean},
        example     = """
            try? [
                ; let's try something dangerous
                print 10 / 0
            ]
            else [
                print "something went terribly wrong..."
            ]
            
            ; something went terribly wrong...
        """:
            ##########################################################
            let verbose = (popAttr("verbose")!=VNULL)
            let execInParent = (popAttr("import")!=VNULL)
            try:
                discard execBlock(x, execInParent=execInParent, inTryBlock=true)
                push(VTRUE)
            except:
                let e = getCurrentException()
                if verbose:
                    showVMErrors(e)
                push(VFALSE)

    builtin "unless",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "perform action, if given condition is false or null",
        args        = {
            "condition" : {Any},
            "action"    : {Block}
        },
        attrs       = NoAttrs,
        returns     = {Nothing},
        example     = """
            x: 2
            
            unless x=1 -> print "yep, x is not 1!"
            ; yep, x is not 1!
        """:
            ##########################################################
            let condition = x.kind==Null or (x.kind==Boolean and x.b==false)
            if condition: 
                discard execBlock(y)

    builtin "unless?",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "perform action, if given condition is false or null and return condition result",
        args        = {
            "condition" : {Any},
            "action"    : {Block}
        },
        attrs       = NoAttrs,
        returns     = {Boolean},
        example     = """
            x: 2
            
            result: unless? x=1 -> print "yep, x is not 1!"
            ; yep, x is not 1!
            
            print result
            ; true
            
            z: 1
            
            unless? x>z [
                print "yep, x was not greater than z"
            ]
            else [
                print "x was greater than z"
            ]
            ; x was greater than z
        """:
            ##########################################################
            let condition = x.kind==Null or (x.kind==Boolean and x.b==false)
            if condition: 
                discard execBlock(y)
                # if vmReturn:
                #     return ReturnResult
            push(newBoolean(condition))

    builtin "until",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "execute action until the given condition is not false or null",
        args        = {
            "action"    : {Block},
            "condition" : {Block}
        },
        attrs       = NoAttrs,
        returns     = {Nothing},
        example     = """
            i: 0 
            until [
                print ["i =>" i] 
                i: i + 1
            ][i = 10]
            
            ; i => 0 
            ; i => 1 
            ; i => 2 
            ; i => 3 
            ; i => 4 
            ; i => 5 
            ; i => 6 
            ; i => 7 
            ; i => 8 
            ; i => 9 
        """:
            ##########################################################
            let preevaledX = doEval(x)
            let preevaledY = doEval(y)

            while true:
                handleBranching:
                    discard execBlock(VNULL, evaluated=preevaledX)
                    discard execBlock(VNULL, evaluated=preevaledY)
                    let popped = pop()
                    let condition = not (popped.kind==Null or (popped.kind==Boolean and popped.b==false))
                    if condition:
                        break
                do:
                    discard

    builtin "var",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "get symbol value by given name",
        args        = {
            "symbol"    : {String,Literal}
        },
        attrs       = NoAttrs,
        returns     = {Any},
        example     = """
            a: 2
            print var 'a            ; a

            f: function [x][x+2]
            print f 10              ; 12

            g: var 'f               
            print g 10              ; 12
        """:
            ##########################################################
            push(InPlace)

    builtin "when?",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "check if a specific condition is fulfilled and, if so, execute given action",
        args        = {
            "condition" : {Block},
            "action"    : {Block}
        },
        attrs       = NoAttrs,
        returns     = {Boolean},
        example     = """
            a: 2
            case [a]
                when? [<2] -> print "a is less than 2"
                when? [=2] -> print "a is 2"
                else       -> print "a is greater than 2"
        """:
            ##########################################################
            let z = pop()
            if not z.b:
                let top = sTop()

                var newb: Value = newBlock()
                for old in top.a:
                    newb.a.add(old)
                for cond in x.a:
                    newb.a.add(cond)

                discard execBlock(newb)

                let res = sTop()
                if res.b: 
                    discard execBlock(y)
                    discard pop()
                    discard pop()
                    push(newBoolean(true))
            else:
                push(z)

    builtin "while",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "execute action while the given condition is is not false or null",
        args        = {
            "condition" : {Block,Null},
            "action"    : {Block}
        },
        attrs       = {
            "import": ({Boolean},"execute at root level")
        },
        returns     = {Nothing},
        example     = """
            i: 0 
            while [i<10][
                print ["i =>" i] 
                i: i + 1
            ]
            
            ; i => 0 
            ; i => 1 
            ; i => 2 
            ; i => 3 
            ; i => 4 
            ; i => 5 
            ; i => 6 
            ; i => 7 
            ; i => 8 
            ; i => 9 

            while ø [
                print "something"   ; infinitely
            ]
        """:
            ##########################################################
            var execInParent = (popAttr("import") != VNULL)

            if x.kind==Block:
                let preevaledX = doEval(x)
                let preevaledY = doEval(y)

                discard execBlock(VNULL, evaluated=preevaledX)
                var popped = pop()

                while not (popped.kind==Null or (popped.kind==Boolean and popped.b==false)):
                    handleBranching:
                        if execInParent:
                            discard execBlock(VNULL, evaluated=preevaledY, execInParent=true)
                        else:
                            discard execBlock(VNULL, evaluated=preevaledY)
                        discard execBlock(VNULL, evaluated=preevaledX)
                        popped = pop()
                    do:
                        discard
            else:
                let preevaledY = doEval(y)
                while true:
                    handleBranching:
                        if execInParent:
                            discard execBlock(VNULL, evaluated=preevaledY, execInParent=true)
                        else:
                            discard execBlock(VNULL, evaluated=preevaledY)
                    do:
                        discard

#=======================================
# Add Library
#=======================================

Libraries.add(defineSymbols)