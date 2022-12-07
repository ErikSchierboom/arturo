#=======================================================
# Arturo
# Programming Language + Bytecode VM compiler
# (c) 2019-2022 Yanis Zafirópulos
#
# @file: library/Collections.nim
#=======================================================

## The main Collections module 
## (part of the standard library)

#=======================================
# Pragmas
#=======================================

{.used.}

#=======================================
# Libraries
#=======================================

when not defined(WEB):
    import oids
else:
    import std/jsbigints

when not defined(NOGMP):
    import helpers/bignums as BignumsHelper

import algorithm, os, random, sequtils
import strutils, sugar, unicode

import helpers/arrays
import helpers/combinatorics
import helpers/ranges
import helpers/strings
import helpers/unisort

import vm/lib

import vm/values/custom/[vbinary, vrange]

#=======================================
# Methods
#=======================================

proc defineSymbols*() =

    builtin "append",
        alias       = doubleplus,
        rule        = InfixPrecedence,
        description = "append value to given collection",
        args        = {
            "collection": {String, Char, Block, Binary, Literal},
            "value"     : {Any}
        },
        attrs       = NoAttrs,
        returns     = {String, Block, Binary, Nothing},
        example     = """
            append "hell" "o"         ; => "hello"
            append [1 2 3] 4          ; => [1 2 3 4]
            append [1 2 3] [4 5]      ; => [1 2 3 4 5]
            ..........
            print "hell" ++ "o!"      ; hello!
            print [1 2 3] ++ 4 ++ 5   ; [1 2 3 4 5]
            ..........
            a: "hell"
            append 'a "o"
            print a                   ; hello
            ..........
            b: [1 2 3]
            'b ++ 4
            print b                   ; [1 2 3 4]
        """:
            #=======================================================
            if x.kind == Literal:
                ensureInPlace()
                if InPlaced.kind == String:
                    if y.kind == String:
                        InPlaced.s &= y.s
                    elif y.kind == Char:
                        InPlaced.s &= $(y.c)
                elif InPlaced.kind == Char:
                    if y.kind == String:
                        SetInPlace(newString($(InPlaced.c) & y.s))
                    elif y.kind == Char:
                        SetInPlace(newString($(InPlaced.c) & $(y.c)))
                else:
                    if y.kind == Block:
                        # TODO(Collections\append) In-place appending should actually work in-place
                        #  labels: enhancement, library
                        InPlaced.cleanAppendInPlace(y)
                    else:
                        InPlaced.a.add(y)
            else:
                if x.kind == String:
                    if y.kind == String:
                        push(newString(x.s & y.s))
                    elif y.kind == Char:
                        push(newString(x.s & $(y.c)))
                elif x.kind == Char:
                    if y.kind == String:
                        push(newString($(x.c) & y.s))
                    elif y.kind == Char:
                        push(newString($(x.c) & $(y.c)))
                elif x.kind == Binary:
                    if y.kind == Binary:
                        push(newBinary(x.n & y.n))
                    elif y.kind == Integer:
                        push(newBinary(x.n & numberToBinary(y.i)))
                else:
                    if y.kind==Block:
                        push newBlock(cleanAppend(x, y))
                    else:
                        push newBlock(cleanAppend(x, y, singleValue=true))

    builtin "chop",
        alias       = unaliased,
        rule        = PrefixPrecedence,
        description = "remove last item from given collection",
        args        = {
            "collection": {String, Block, Literal}
        },
        attrs       = NoAttrs,
        returns     = {String, Block, Nothing},
        example     = """
            print chop "books"          ; book
            print chop chop "books"     ; boo
            ..........
            str: "books"
            chop 'str                   ; str: "book"
            ..........
            chop [1 2 3 4]              ; => [1 2 3]
        """:
            #=======================================================
            if x.kind == Literal:
                ensureInPlace()
                if InPlaced.kind == String:
                    InPlaced.s = InPlaced.s[0..^2]
                elif InPlaced.kind == Block:
                    if InPlaced.a.len > 0:
                        InPlaced.a = InPlaced.a[0..^2]
            else:
                if x.kind == String:
                    push(newString(x.s[0..^2]))
                elif x.kind == Block:
                    ensureCleaned(x)
                    if cleanX.len == 0: push(newBlock())
                    else: push(newBlock(cleanX[0..^2]))

    builtin "combine",
        alias       = unaliased,
        rule        = PrefixPrecedence,
        description = "get all possible combinations of the elements in given collection",
        args        = {
            "collection": {Block}
        },
        attrs       = {
            "by"        : ({Integer}, "define size of each set"),
            "repeated"  : ({Logical}, "allow for combinations with repeated elements"),
            "count"     : ({Logical}, "just count the number of combinations")
        },
        returns     = {Block, Integer},
        example     = """
            combine [A B C]
            ; => [[A B C]]

            combine.repeated [A B C]
            ; => [[A A A] [A A B] [A A C] [A B B] [A B C] [A C C] [B B B] [B B C] [B C C] [C C C]]
            ..........
            combine.by:2 [A B C]
            ; => [[A B] [A C] [B C]]

            combine.repeated.by:2 [A B C]
            ; => [[A A] [A B] [A C] [B B] [B C] [C C]]
            ..........
            combine.count [A B C]
            ; => 1

            combine.count.repeated.by:2 [A B C]
            ; => 6
        """:
            #=======================================================
            let doRepeat = hadAttr("repeated")

            ensureCleaned(x)

            var sz = cleanX.len
            if checkAttr("by"):
                if aBy.i > 0 and aBy.i < sz:
                    sz = aBy.i

            if hadAttr("count"):
                push(countCombinations(cleanX, sz, doRepeat))
            else:
                push(newBlock(getCombinations(cleanX, sz, doRepeat).map((
                        z)=>newBlock(z))))

    builtin "contains?",
        alias       = unaliased,
        rule        = PrefixPrecedence,
        description = "check if collection contains given value",
        args        = {
            "collection": {String, Block, Range, Dictionary},
            "value"     : {Any}
        },
        attrs       = {
            "at"    : ({Integer}, "check at given location within collection")
        },
        returns     = {Logical},
        example     = """
            arr: [1 2 3 4]

            contains? arr 5             ; => false
            contains? arr 2             ; => true
            ..........
            user: #[
                name: "John"
                surname: "Doe"
            ]

            contains? dict "John"       ; => true
            contains? dict "Paul"       ; => false

            contains? keys dict "name"  ; => true
            ..........
            contains? "hello" "x"       ; => false
            contains? "hello" `h`       ; => true
            ..........
            contains?.at:1 "hello" "el" ; => true
            contains?.at:4 "hello" `o`  ; => true
            ..........
            print contains?.at:2 ["one" "two" "three"] "two"
            ; false

            print contains?.at:1 ["one" "two" "three"] "two"
            ; true
        """:
            #=======================================================
            if checkAttr("at"):
                let at = aAt.i
                case x.kind:
                    of String:
                        if y.kind == Regex:
                            push(newLogical(x.s.contains(y.rx, at)))
                        elif y.kind == Char:
                            push(newLogical(toRunes(x.s)[at] == y.c))
                        else:
                            push(newLogical(x.s.continuesWith(y.s, at)))
                    of Block:
                        ensureCleaned(x)
                        push(newLogical(cleanX[at] == y))
                    of Range:
                        push(newLogical(x.rng[at] == y))
                    of Dictionary:
                        let values = toSeq(x.d.values)
                        push(newLogical(values[at] == y))
                    else:
                        discard
            else:
                case x.kind:
                    of String:
                        if y.kind == Regex:
                            push(newLogical(x.s.contains(y.rx)))
                        elif y.kind == Char:
                            push(newLogical($(y.c) in x.s))
                        else:
                            push(newLogical(y.s in x.s))
                    of Block:
                        ensureCleaned(x)
                        push(newLogical(y in cleanX))
                    of Range:
                        push(newLogical(y in x.rng))
                    of Dictionary:
                        let values = toSeq(x.d.values)
                        push(newLogical(y in values))
                    else:
                        discard

    builtin "couple",
        alias       = unaliased,
        rule        = PrefixPrecedence,
        description = "get combination of elements in given collections as array of tuples",
        args        = {
            "collectionA"   : {Block},
            "collectionB"   : {Block}
        },
        attrs       = NoAttrs,
        returns     = {Block},
        example     = """
            couple ["one" "two" "three"] [1 2 3]
            ; => [[1 "one"] [2 "two"] [3 "three"]]
        """:
            #=======================================================
            ensureCleaned(x)
            ensureCleaned(y)
            push(newBlock(zip(cleanX, cleanY).map((z)=>newBlock(@[z[0], z[1]]))))

    builtin "decouple",
        alias       = unaliased,
        rule        = PrefixPrecedence,
        description = "get tuple of collections from a coupled collection of tuples",
        args        = {
            "collection": {Block}
        },
        attrs       = NoAttrs,
        returns     = {Block},
        example     = """
            c: couple ["one" "two" "three"] [1 2 3]
            ; c: [[1 "one"] [2 "two"] [3 "three"]]

            decouple c
            ; => ["one" "two" "three"] [1 2 3]
        """:
            #=======================================================
            ensureCleaned(x)
            let res = unzip(cleanX.map((z)=>(z.a[0], z.a[1])))
            push(newBlock(@[newBlock(res[0]), newBlock(res[1])]))

    builtin "drop",
        alias       = unaliased,
        rule        = PrefixPrecedence,
        description = "drop first *number* of elements from given collection and return the remaining ones",
        args        = {
            "collection": {String, Block, Literal},
            "number"    : {Integer}
        },
        attrs       = NoAttrs,
        returns     = {String, Block, Nothing},
        example     = """
            str: drop "some text" 5
            print str                     ; text
            ..........
            arr: 1..10
            drop 'arr 3                   ; arr: [4 5 6 7 8 9 10]
        """:
            #=======================================================
            if x.kind == Literal:
                ensureInPlace()
                if InPlaced.kind == String:
                    InPlaced.s = InPlaced.s[y.i..^1]
                elif InPlaced.kind == Block:
                    if InPlaced.a.len > 0:
                        InPlaced.a = InPlaced.a[y.i..^1]
            else:
                if x.kind == String:
                    push(newString(x.s[y.i..^1]))
                elif x.kind == Block:
                    ensureCleaned(x)
                    if cleanX.len == 0: push(newBlock())
                    else: push(newBlock(cleanX[y.i..^1]))

    builtin "empty",
        alias       = unaliased,
        rule        = PrefixPrecedence,
        description = "empty given collection",
        args        = {
            "collection": {Literal}
        },
        attrs       = NoAttrs,
        returns     = {Nothing},
        example     = """
            a: [1 2 3]
            empty 'a              ; a: []
            ..........
            str: "some text"
            empty 'str            ; str: ""
        """:
            #=======================================================
            ensureInPlace()
            case InPlaced.kind:
                of String: InPlaced.s = ""
                of Block: InPlaced.a = @[]
                of Dictionary: InPlaced.d = initOrderedTable[string, Value]()
                else: discard

    builtin "empty?",
        alias       = unaliased,
        rule        = PrefixPrecedence,
        description = "check if given collection is empty",
        args        = {
            "collection": {String, Block, Dictionary, Null}
        },
        attrs       = NoAttrs,
        returns     = {Logical},
        example     = """
            empty? ""             ; => true
            empty? []             ; => true
            empty? #[]            ; => true

            empty? [1 "two" 3]    ; => false
        """:
            #=======================================================
            case x.kind:
                of Null: push(VTRUE)
                of String: push(newLogical(x.s == ""))
                of Block:
                    ensureCleaned(x)
                    push(newLogical(cleanX.len == 0))
                of Dictionary: push(newLogical(x.d.len == 0))
                else: discard

    # TODO(Collections/extend) Could also work with literal values
    #  labels: library, enhancement, new feature
    builtin "extend",
        alias       = unaliased,
        rule        = PrefixPrecedence,
        description = "get new dictionary by merging given ones",
        args        = {
            "parent"    : {Dictionary},
            "additional": {Dictionary}
        },
        attrs       = NoAttrs,
        returns     = {Dictionary},
        example     = """
            person: #[ name: "john" surname: "doe" ]

            print extend person #[ age: 35 ]
            ; [name:john surname:doe age:35]
        """:
            #=======================================================
            if x.kind == Literal:
                ensureInPlace()
                for k, v in pairs(y.d):
                    InPlaced.d[k] = v
            else:
                var res = copyValue(x)
                for k, v in pairs(y.d):
                    res.d[k] = v

                push(res)

    builtin "first",
        alias       = unaliased,
        rule        = PrefixPrecedence,
        description = "return the first item of the given collection",
        args        = {
            "collection": {String, Block, Range}
        },
        attrs       = {
            "n"     : ({Integer}, "get first *n* items")
        },
        returns     = {Any, Null},
        example     = """
            print first "this is some text"       ; t
            print first ["one" "two" "three"]     ; one
            ..........
            print first.n:2 ["one" "two" "three"] ; one two
        """:
            #=======================================================
            if checkAttr("n"):
                if x.kind == String:
                    if x.s.len == 0: push(newString(""))
                    else: push(newString(x.s[0..aN.i-1]))
                elif x.kind == Range:
                    var res: ValueArray = newSeq[Value](aN.i)
                    var i = 0
                    for item in items(x.rng):
                        res[i] = item
                        i += 1
                        if i == aN.i: break
                    push(newBlock(res))
                else:
                    ensureCleaned(x)
                    if cleanX.len == 0: push(newBlock())
                    else: push(newBlock(cleanX[0..aN.i-1]))
            else:
                if x.kind == String:
                    if x.s.len == 0: push(VNULL)
                    else: push(newChar(x.s.runeAt(0)))
                elif x.kind == Range:
                    push(x.rng[0])
                else:
                    ensureCleaned(x)
                    if cleanX.len == 0: push(VNULL)
                    else: push(cleanX[0])

    builtin "flatten",
        alias       = unaliased,
        rule        = PrefixPrecedence,
        description = "flatten given collection by eliminating nested blocks",
        args        = {
            "collection": {Block},

        },
        attrs       = {
            "once"  : ({Logical}, "do not perform recursive flattening")
        },
        returns     = {Block},
        example     = """
            arr: [[1 2 3] [4 5 6]]
            print flatten arr
            ; 1 2 3 4 5 6
            ..........
            arr: [[1 2 3] [4 5 6]]
            flatten 'arr
            ; arr: [1 2 3 4 5 6]
            ..........
            flatten [1 [2 3] [4 [5 6]]]
            ; => [1 2 3 4 5 6]
            ..........
            flatten.once [1 [2 3] [4 [5 6]]]
            ; => [1 2 3 4 [5 6]]
        """:
            #=======================================================
            if x.kind == Literal:
                ensureInPlace()
                SetInPlace(InPlaced.flattened(once = hadAttr("once")))
            else:
                push(newBlock(cleanedBlock(x.a)).flattened(once = hadAttr("once")))

    builtin "get",
        alias       = unaliased,
        rule        = InfixPrecedence,
        description = "get collection's item by given index",
        args        = {
            "collection": {String, Block, Range, Dictionary, Object, Date, Binary, Bytecode},
            "index"     : {Any}
        },
        attrs       = NoAttrs,
        returns     = {Any},
        example     = """
            user: #[
                name: "John"
                surname: "Doe"
            ]

            print user\name               ; John

            print get user 'surname       ; Doe
            print user\surname            ; Doe
            ..........
            arr: ["zero" "one" "two"]

            print arr\1                   ; one

            print get arr 2               ; two
            y: 2
            print arr\[y]                 ; two
            ..........
            str: "Hello world!"

            print str\0                   ; H

            print get str 1               ; e
            z: 0
            print str\[z+1]               ; e
        """:
            #=======================================================
            case x.kind:
                of Block:
                    if likely(y.kind==Integer):
                        ensureCleaned(x)
                        push(GetArrayIndex(cleanX, y.i))
                    else:
                        let rLen = y.rng.len
                        var res: ValueArray = newSeq[Value](rLen)
                        var i = 0
                        for item in items(y.rng):
                            res[i] = GetArrayIndex(x.a, item.i)
                            i += 1
                        push(newBlock(res))
                of Range:
                    if likely(y.kind==Integer):
                        push(x.rng[y.i])
                    else:
                        let rLen = y.rng.len
                        var res: ValueArray = newSeq[Value](rLen)
                        var i = 0
                        for item in items(y.rng):
                            res[i] = x.rng[item.i]
                            i += 1
                        push(newBlock(res))
                of Binary:
                    push(newInteger(int(x.n[y.i])))
                of Bytecode:
                    if y.s == "data":
                        push(newBlock(x.trans.constants))
                    elif y.s == "code":
                        push(newBlock(x.trans.instructions.map((w) =>
                                newInteger(int(w)))))
                    else:
                        push(VNULL)
                of Dictionary:
                    case y.kind:
                        of String, Word, Literal, Label:
                            push(GetKey(x.d, y.s))
                        else:
                            push(GetKey(x.d, $(y)))
                of Object:
                    case y.kind:
                        of String, Word, Literal, Label:
                            push(GetKey(x.o, y.s))
                        else:
                            push(GetKey(x.o, $(y)))
                of String:
                    push(newChar(x.s.runeAtPos(y.i)))
                of Date:
                    push(GetKey(x.e, y.s))
                else: discard

    builtin "in?",
        alias       = unaliased,
        rule        = PrefixPrecedence,
        description = "check if value exists in given collection",
        args        = {
            "value"     : {Any},
            "collection": {String, Block, Range, Dictionary}
        },
        attrs       = {
            "at"    : ({Integer}, "check at given location within collection")
        },
        returns     = {Logical},
        example     = """
            arr: [1 2 3 4]

            in? 5 arr             ; => false
            in? 2 arr             ; => true
            ..........
            user: #[
                name: "John"
                surname: "Doe"
            ]

            in? "John" dict       ; => true
            in? "Paul" dict       ; => false

            in? "name" keys dict  ; => true
            ..........
            in? "x" "hello"       ; => false
            in? `h` "hello"       ; => true
            ..........
            in?.at:1 "el" "hello" ; => true
            in?.at:4 `o` "hello"  ; => true
            ..........
            print in?.at:2 "two" ["one" "two" "three"]
            ; false

            print in?.at:1 "two" ["one" "two" "three"]
            ; true
        """:
            #=======================================================
            if checkAttr("at"):
                let at = aAt.i
                case y.kind:
                    of String:
                        if x.kind == Regex:
                            push(newLogical(y.s.contains(x.rx, at)))
                        elif x.kind == Char:
                            push(newLogical(toRunes(y.s)[at] == x.c))
                        else:
                            push(newLogical(y.s.continuesWith(x.s, at)))
                    of Block:
                        ensureCleaned(y)
                        push(newLogical(cleanY[at] == x))
                    of Range:
                        push(newLogical(y.rng[at] == x))
                    of Dictionary:
                        let values = toSeq(y.d.values)
                        push(newLogical(values[at] == x))
                    else:
                        discard
            else:
                case y.kind:
                    of String:
                        if x.kind == Regex:
                            push(newLogical(y.s.contains(x.rx)))
                        elif x.kind == Char:
                            push(newLogical($(x.c) in y.s))
                        else:
                            push(newLogical(x.s in y.s))
                    of Block:
                        push(newLogical(x in y.a))
                    of Range:
                        push(newLogical(x in y.rng))
                    of Dictionary:
                        let values = toSeq(y.d.values)
                        push(newLogical(x in values))
                    else:
                        discard

    builtin "index",
        alias       = unaliased,
        rule        = PrefixPrecedence,
        description = "return first index of value in given collection",
        args        = {
            "collection": {String, Block, Range, Dictionary},
            "value"     : {Any}
        },
        attrs       = NoAttrs,
        returns     = {Integer, String, Null},
        example     = """
            ind: index "hello" "e"
            print ind                 ; 1
            ..........
            print index [1 2 3] 3     ; 2
            ..........
            type index "hello" "x"
            ; :null
        """:
            #=======================================================
            case x.kind:
                of String:
                    let indx = x.s.find(y.s)
                    if indx != -1: push(newInteger(indx))
                    else: push(VNULL)
                of Block:
                    ensureCleaned(x)
                    let indx = cleanX.find(y)
                    if indx != -1: push(newInteger(indx))
                    else: push(VNULL)
                of Range:
                    let indx = x.rng.find(y)
                    if indx != -1: push(newInteger(indx))
                    else: push(VNULL)
                of Dictionary:
                    var found = false
                    for k, v in pairs(x.d):
                        if v == y:
                            push(newString(k))
                            found = true
                            break

                    if not found:
                        push(VNULL)
                else: discard

    builtin "insert",
        alias       = unaliased,
        rule        = PrefixPrecedence,
        description = "insert value in collection at given index",
        args        = {
            "collection": {String, Block, Dictionary, Literal},
            "index"     : {Integer, String},
            "value"     : {Any}
        },
        attrs       = NoAttrs,
        returns     = {String, Block, Dictionary, Nothing},
        example     = """
            insert [1 2 3 4] 0 "zero"
            ; => ["zero" 1 2 3 4]

            print insert "heo" 2 "ll"
            ; hello
            ..........
            dict: #[
                name: John
            ]

            insert 'dict 'name "Jane"
            ; dict: [name: "Jane"]
        """:
            #=======================================================
            if x.kind == Literal:
                ensureInPlace()
                case InPlaced.kind:
                    of String: InPlaced.s.insert(z.s, y.i)
                    of Block: InPlaced.a.insert(z, y.i)
                    of Dictionary:
                        InPlaced.d[y.s] = z
                    else: discard
            else:
                case x.kind:
                    of String:
                        var copied = x.s
                        copied.insert(z.s, y.i)
                        push(newString(copied))
                    of Block:
                        var copied = cleanedBlock(x.a)
                        copied.insert(z, y.i)
                        push(newBlock(copied))
                    of Dictionary:
                        var copied = x.d
                        copied[y.s] = z
                        push(newDictionary(copied))
                    else: discard

    builtin "key?",
        alias       = unaliased,
        rule        = PrefixPrecedence,
        description = "check if collection contains given key",
        args        = {
            "collection": {Dictionary, Object},
            "key"       : {Any}
        },
        attrs       = NoAttrs,
        returns     = {Logical},
        example     = """
            user: #[
                name: "John"
                surname: "Doe"
            ]

            key? user 'age            ; => false
            if key? user 'name [
                print ["Hello" user\name]
            ]
            ; Hello John
        """:
            #=======================================================
            var needle: string
            if y.kind == String: needle = y.s
            else: needle = $(y)

            if x.kind == Dictionary:
                push(newLogical(x.d.hasKey(needle)))
            else:
                push(newLogical(x.o.hasKey(needle)))

    builtin "keys",
        alias       = unaliased,
        rule        = PrefixPrecedence,
        description = "get list of keys for given collection",
        args        = {
            "dictionary": {Dictionary, Object}
        },
        attrs       = NoAttrs,
        returns     = {Block},
        example     = """
            user: #[
                name: "John"
                surname: "Doe"
            ]

            keys user
            => ["name" "surname"]
        """:
            #=======================================================
            var s: seq[string]
            if x.kind == Dictionary:
                s = toSeq(x.d.keys)
            else:
                s = toSeq(x.o.keys)

            push(newStringBlock(s))

    builtin "last",
        alias       = unaliased,
        rule        = PrefixPrecedence,
        description = "return the last item of the given collection",
        args        = {
            "collection": {String, Block, Range}
        },
        attrs       = {
            "n"     : ({Integer}, "get last *n* items")
        },
        returns     = {Any, Null},
        example     = """
            print last "this is some text"       ; t
            print last ["one" "two" "three"]     ; three
            ..........
            print last.n:2 ["one" "two" "three"] ; two three
        """:
            #=======================================================
            if checkAttr("n"):
                if x.kind == String:
                    if x.s.len == 0: push(newString(""))
                    else: push(newString(x.s[x.s.len-aN.i..^1]))
                elif x.kind == Range:
                    let items = toSeq(x.rng.items)
                    push(newBlock(items[x.rng.len-aN.i..^1]))
                else:
                    ensureCleaned(x)
                    if cleanX.len == 0: push(newBlock())
                    else: push(newBlock(cleanX[cleanX.len-aN.i..^1]))
            else:
                if x.kind == String:
                    if x.s.len == 0: push(VNULL)
                    else: push(newChar(toRunes(x.s)[^1]))
                elif x.kind == Range:
                    let items = toSeq(x.rng.items)
                    push(items[x.rng.len-1])
                else:
                    ensureCleaned(x)
                    if cleanX.len == 0: push(VNULL)
                    else: push(cleanX[cleanX.len-1])

    builtin "max",
        alias       = unaliased,
        rule        = PrefixPrecedence,
        description = "get maximum element in given collection",
        args        = {
            "collection": {Block,Range}
        },
        attrs       = {
            "index" : ({Logical}, "retrieve index of maximum element"),
        },
        returns     = {Any, Null},
        example     = """
            print max [4 2 8 5 1 9]       ; 9
        """:
            #=======================================================
            let withIndex = hadAttr("index")

            if x.kind==Range:
                let (maxIndex, maxElement) = max(x.rng)
                if withIndex: push(newInteger(maxIndex))
                else: push(maxElement)
            else:
                ensureCleaned(x)
                if cleanX.len == 0: push(VNULL)
                else:
                    var maxElement = cleanX[0]
                    if withIndex:
                        var maxIndex = 0
                        var i = 1
                        while i < cleanX.len:
                            if (cleanX[i] > maxElement):
                                maxElement = cleanX[i]
                                maxIndex = i
                            inc(i)

                        push(newInteger(maxIndex))
                    else:
                        var i = 1
                        while i < cleanX.len:
                            if (cleanX[i] > maxElement):
                                maxElement = cleanX[i]
                            inc(i)

                        push(maxElement)

    builtin "min",
        alias       = unaliased,
        rule        = PrefixPrecedence,
        description = "get minimum element in given collection",
        args        = {
            "collection": {Block,Range}
        },
        attrs       = {
            "index" : ({Logical}, "retrieve index of minimum element"),
        },
        returns     = {Any, Null},
        example     = """
            print min [4 2 8 5 1 9]       ; 1
        """:
            #=======================================================
            let withIndex = hadAttr("index")

            if x.kind==Range:
                let (minIndex, minElement) = min(x.rng)
                if withIndex: push(newInteger(minIndex))
                else: push(minElement)
            else:
                ensureCleaned(x)
                if cleanX.len == 0: push(VNULL)
                else:
                    var minElement = cleanX[0]
                    var minIndex = 0
                    if withIndex:
                        var i = 1
                        while i < cleanX.len:
                            if (cleanX[i] < minElement):
                                minElement = cleanX[i]
                                minIndex = i
                            inc(i)

                        push(newInteger(minIndex))
                    else:
                        var i = 1
                        while i < cleanX.len:
                            if (cleanX[i] < minElement):
                                minElement = cleanX[i]
                            inc(i)

                        push(minElement)

    builtin "one?",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "check if given number or collection size is one",
        args        = {
            "number"    : {Integer,Floating,String,Block,Range,Dictionary,Object,Null},
        },
        attrs       = NoAttrs,
        returns     = {Logical},
        example     = """
            one? 5              ; => false
            one? 4-3            ; => true
            ..........
            one? 1.0            ; => true
            one? 0.0            ; => false
            ..........
            items: ["apple"]
            one? items          ; => true

            items: [1 2 3]
            one? items          ; => false
            ..........
            one? ø              ; => false
        """:
            #=======================================================
            case x.kind:
                of Integer:
                    if x.iKind == BigInteger:
                        when defined(WEB):
                            push(newLogical(x.bi==big(1)))
                        elif not defined(NOGMP):
                            push(newLogical(x.bi==newInt(1)))
                    else:
                        push(newLogical(x == I1))
                of Floating:
                    push(newLogical(x == F1))
                of String:
                    push(newLogical(runeLen(x.s) == 1))
                of Block:
                    ensureCleaned(x)
                    push(newLogical(cleanX.len == 1))
                of Range:
                    push(newLogical(x.rng.len == 1))
                of Dictionary:
                    push(newLogical(x.d.len == 1))
                of Object:
                    push(newLogical(x.o.len == 1))
                else:
                    push(VFALSE)

    builtin "permutate",
        alias       = unaliased,
        rule        = PrefixPrecedence,
        description = "get all possible permutations of the elements in given collection",
        args        = {
            "collection": {Block}
        },
        attrs       = {
            "by"        : ({Integer}, "define size of each set"),
            "repeated"  : ({Logical}, "allow for permutations with repeated elements"),
            "count"     : ({Logical}, "just count the number of permutations")
        },
        returns     = {Block},
        example     = """
            permutate [A B C]
            ; => [[A B C] [A C B] [B A C] [B C A] [C A B] [C B A]]

            permutate.repeated [A B C]
            ; => [[A A A] [A A B] [A A C] [A B A] [A B B] [A B C] [A C A] [A C B] [A C C] [B A A] [B A B] [B A C] [B B A] [B B B] [B B C] [B C A] [B C B] [B C C] [C A A] [C A B] [C A C] [C B A] [C B B] [C B C] [C C A] [C C B] [C C C]]
            ..........
            permutate.by:2 [A B C]
            ; => [[A B] [A C] [B A] [B C] [C A] [C B]]

            permutate.repeated.by:2 [A B C]
            ; => [[A A] [A B] [A C] [B A] [B B] [B C] [C A] [C B] [C C]]
            ..........
            permutate.count [A B C]
            ; => 6

            permutate.count.repeated.by:2 [A B C]
            ; => 9
        """:
            #=======================================================
            let doRepeat = hadAttr("repeated")

            ensureCleaned(x)

            var sz = cleanX.len
            if checkAttr("by"):
                if aBy.i > 0 and aBy.i < sz:
                    sz = aBy.i

            if hadAttr("count"):
                push(countPermutations(cleanX, sz, doRepeat))
            else:
                push(newBlock(getPermutations(cleanX, sz, doRepeat).map((
                        z)=>newBlock(z))))

    builtin "prepend",
        alias       = unaliased,
        rule        = PrefixPrecedence,
        description = "prepend value to given collection",
        args        = {
            "collection": {String, Char, Block, Binary, Literal},
            "value"     : {Any}
        },
        attrs       = NoAttrs,
        returns     = {String, Block, Binary, Nothing},
        example     = """
        """:
            #=======================================================
            if x.kind == Literal:
                ensureInPlace()
                if InPlaced.kind == String:
                    if y.kind == String:
                        InPlaced.s.insert(y.s, 0)
                    elif y.kind == Char:
                        InPlaced.s.insert($(y.c), 0)
                elif InPlaced.kind == Char:
                    if y.kind == String:
                        SetInPlace(newString(y.s & $(InPlaced.c)))
                    elif y.kind == Char:
                        SetInPlace(newString($(y.c) & $(InPlaced.c)))
                else:
                    if y.kind == Block:
                        InPlaced.cleanPrependInPlace(y)
                    else:
                        InPlaced.a.insert(y, 0)
            else:
                if x.kind == String:
                    if y.kind == String:
                        push(newString(y.s & x.s))
                    elif y.kind == Char:
                        push(newString($(y.c) & x.s))
                elif x.kind == Char:
                    if y.kind == String:
                        push(newString(y.s & $(x.c)))
                    elif y.kind == Char:
                        push(newString($(y.c) & $(x.c)))
                elif x.kind == Binary:
                    if y.kind == Binary:
                        push(newBinary(y.n & x.n))
                    elif y.kind == Integer:
                        push(newBinary(numberToBinary(y.i) & x.n))
                else:
                    if y.kind==Block:
                        push newBlock(cleanPrepend(x, y))
                    else:
                        push newBlock(cleanPrepend(x, y, singleValue=true))

    builtin "remove",
        alias       = doubleminus,
        rule        = InfixPrecedence,
        description = "remove value from given collection",
        args        = {
            "collection": {String, Block, Dictionary, Literal},
            "value"     : {Any}
        },
        attrs       = {
            "key"   : ({Logical}, "remove dictionary key"),
            "once"  : ({Logical}, "remove only first occurence"),
            "index" : ({Logical}, "remove specific index"),
            "prefix": ({Logical}, "remove first matching prefix from string"),
            "suffix": ({Logical}, "remove first matching suffix from string")
        },
        returns     = {String, Block, Dictionary, Nothing},
        example     = """
            remove "hello" "l"        ; => "heo"
            print "hello" -- "l"      ; heo
            ..........
            str: "mystring"
            remove 'str "str"
            print str                 ; mying
            ..........
            print remove.once "hello" "l"
            ; helo
            ..........
            remove [1 2 3 4] 4        ; => [1 2 3]
        """:
            #=======================================================
            if x.kind == Literal:
                ensureInPlace()
                if InPlaced.kind == String:
                    if (hadAttr("once")):
                        SetInPlace(newString(InPlaced.s.removeFirst(y.s)))
                    elif (hadAttr("prefix")):
                        InPlaced.s.removePrefix(y.s)
                    elif (hadAttr("suffix")):
                        InPlaced.s.removeSuffix(y.s)
                    else:
                        SetInPlace(newString(InPlaced.s.removeAll(y)))
                elif InPlaced.kind == Block:
                    if (hadAttr("once")):
                        SetInPlace(newBlock(InPlaced.a.removeFirst(y)))
                    elif (hadAttr("index")):
                        # TODO(General) All `SetInPlace` or `InPlace=` that change the type of object should be changed
                        #  It doesn't work when in-place changing passed parameters to a function
                        #  The above is mostly a hack to get around this
                        #  labels: bug, critical, vm
                        InPlaced.kind = Block
                        InPlaced.a = InPlaced.a.removeByIndex(y.i)
                        #SetInPlace(newBlock(InPlaced.a.removeByIndex(y.i)))
                    else:
                        SetInPlace(newBlock(InPlaced.a.removeAll(y)))
                elif InPlaced.kind == Dictionary:
                    let key = (hadAttr("key"))
                    if (hadAttr("once")):
                        SetInPlace(newDictionary(InPlaced.d.removeFirst(y, key)))
                    else:
                        SetInPlace(newDictionary(InPlaced.d.removeAll(y, key)))
            else:
                if x.kind == String:
                    if (hadAttr("once")):
                        push(newString(x.s.removeFirst(y.s)))
                    elif (hadAttr("prefix")):
                        var ret = x.s
                        ret.removePrefix(y.s)
                        push(newString(ret))
                    elif (hadAttr("suffix")):
                        var ret = x.s
                        ret.removeSuffix(y.s)
                        push(newString(ret))
                    else:
                        push(newString(x.s.removeAll(y)))
                elif x.kind == Block:
                    ensureCleaned(x)
                    if (hadAttr("once")):
                        push(newBlock(cleanX.removeFirst(y)))
                    elif (hadAttr("index")):
                        push(newBlock(cleanX.removeByIndex(y.i)))
                    else:
                        push(newBlock(cleanX.removeAll(y)))
                elif x.kind == Dictionary:
                    let key = (hadAttr("key"))
                    if (hadAttr("once")):
                        push(newDictionary(x.d.removeFirst(y, key)))
                    else:
                        push(newDictionary(x.d.removeAll(y, key)))

    builtin "repeat",
        alias       = unaliased,
        rule        = PrefixPrecedence,
        description = "repeat value the given number of times and return new one",
        args        = {
            "value" : {Any, Literal},
            "times" : {Integer}
        },
        attrs       = NoAttrs,
        returns     = {String, Block},
        example     = """
            print repeat "hello" 3
            ; hellohellohello
            ..........
            repeat [1 2 3] 3
            ; => [1 2 3 1 2 3 1 2 3]
            ..........
            repeat 5 3
            ; => [5 5 5]
            ..........
            repeat [[1 2 3]] 3
            ; => [[1 2 3] [1 2 3] [1 2 3]]
        """:
            #=======================================================
            if x.kind == Literal:
                ensureInPlace()
                if InPlaced.kind == String:
                    SetInPlace(newString(InPlaced.s.repeat(y.i)))
                elif InPlaced.kind == Block:
                    SetInPlace(newBlock(InPlaced.a.cycle(y.i)))
                else:
                    SetInPlace(newBlock(InPlaced.repeat(y.i)))
            else:
                if x.kind == String:
                    push(newString(x.s.repeat(y.i)))
                elif x.kind == Block:
                    ensureCleaned(x)
                    push(newBlock(safeCycle(cleanX, y.i)))
                else:
                    push(newBlock(safeRepeat(x, y.i)))

    builtin "reverse",
        alias       = unaliased,
        rule        = PrefixPrecedence,
        description = "reverse given collection",
        args        = {
            "collection": {String, Block, Range, Literal}
        },
        attrs       = {
            "exact" : ({Logical}, "make sure the reverse range contains the same elements")
        },
        returns     = {String, Block, Nothing},
        example     = """
            print reverse [1 2 3 4]           ; 4 3 2 1
            print reverse "Hello World"       ; dlroW olleH
            ..........
            str: "my string"
            reverse 'str
            print str                         ; gnirts ym
        """:
            #=======================================================
            proc reverse(s: var string) =
                for i in 0 .. s.high div 2:
                    swap(s[i], s[s.high - i])

            proc reversed(s: string): string =
                result = newString(s.len)
                for i, c in s:
                    result[s.high - i] = c

            let exact = hadAttr("exact")

            if x.kind == Literal:
                ensureInPlace()
                if InPlaced.kind == String:
                    InPlaced.s.reverse()
                elif InPlaced.kind == Range:
                    InPlaced.rng = InPlaced.rng.reversed(safe=exact)
                else:
                    InPlaced.a.reverse()
            else:
                if x.kind == Block:
                    ensureCleaned(x)
                    push(newBlock(cleanX.reversed))
                elif x.kind == Range:
                    push(newRange(x.rng.reversed(safe=exact)))
                else:
                    push(newString(reversed(x.s)))

    builtin "rotate",
        alias       = unaliased,
        rule        = PrefixPrecedence,
        description = "right-rotate collection by given distance",
        args        = {
            "collection": {String, Block, Literal},
            "distance"  : {Integer}
        },
        attrs       = {
            "left"  : ({Logical}, "left rotation")
        },
        returns     = {String, Block, Nothing},
        example     = """
            rotate [a b c d e] 1            ; => [e a b c d]
            rotate.left [a b c d e] 1       ; => [b c d e a]

            rotate 1..6 4                   ; => [3 4 5 6 1 2]
        """:
            #=======================================================
            let distance = if (not hadAttr("left")): -y.i else: y.i

            if x.kind == Literal:
                ensureInPlace()
                if InPlaced.kind == String:
                    SetInPlace(newString(toSeq(runes(x.s)).map((x) => $(
                            x)).rotatedLeft(distance).join("")))
                elif InPlaced.kind == Block:
                    InPlaced.a.rotateLeft(distance)
            else:
                if x.kind == String:
                    push(newString(toSeq(runes(x.s)).map((x) => $(
                            x)).rotatedLeft(distance).join("")))
                elif x.kind == Block:
                    ensureCleaned(x)
                    push(newBlock(cleanX.rotatedLeft(distance)))

    builtin "sample",
        alias       = unaliased,
        rule        = PrefixPrecedence,
        description = "get a random element from given collection",
        args        = {
            "collection": {Block,Range}
        },
        attrs       = NoAttrs,
        returns     = {Any, Null},
        example     = """
            sample [1 2 3]        ; (return a random number from 1 to 3)
            print sample ["apple" "appricot" "banana"]
            ; apple
        """:
            #=======================================================
            if x.kind == Range:
                let rnd = rand(0..int(x.rng.len-1))
                push(x.rng[rnd])
            else:
                ensureCleaned(x)
                if cleanX.len == 0: push(VNULL)
                else: push(sample(cleanX))

    builtin "set",
        alias       = unaliased,
        rule        = PrefixPrecedence,
        description = "set collection's item at index to given value",
        args        = {
            "collection": {String, Block, Dictionary, Object, Binary, Bytecode},
            "index"     : {Any},
            "value"     : {Any}
        },
        attrs       = NoAttrs,
        returns     = {Nothing},
        example     = """
            myDict: #[
                name: "John"
                age: 34
            ]

            set myDict 'name "Michael"        ; => [name: "Michael", age: 34]
            ..........
            arr: [1 2 3 4]
            set arr 0 "one"                   ; => ["one" 2 3 4]

            arr\1: "dos"                      ; => ["one" "dos" 3 4]

            x: 2
            arr\[x]: "tres"                   ; => ["one" "dos" "tres" 4]
            ..........
            str: "hello"
            str\0: `x`
            print str
            ; xello
        """:
            #=======================================================
            case x.kind:
                of Block:
                    cleanBlock(x)
                    SetArrayIndex(x.a, y.i, z)
                of Binary:
                    let bn = numberToBinary(z.i)
                    if bn.len == 1:
                        x.n[y.i] = bn[0]
                    else:
                        for bi, bt in bn:
                            if not (bi+y.i < x.n.len):
                                x.n.add(byte(0))

                            x.n[bi + y.i] = bt
                of Bytecode:
                    if y.s == "data":
                        x.trans.constants = y.a
                    elif y.s == "code":
                        x.trans.instructions = y.a.map((w) => byte(w.i))
                    else:
                        discard
                of Dictionary:
                    case y.kind:
                        of String, Word, Literal, Label:
                            x.d[y.s] = z
                        else:
                            x.d[$(y)] = z
                of Object:
                    case y.kind:
                        of String, Word, Literal, Label:
                            x.o[y.s] = z
                        else:
                            x.o[$(y)] = z
                of String:
                    var res: string
                    var idx = 0
                    for r in x.s.runes:
                        if idx != y.i: res.add r
                        else: res.add z.c
                        idx += 1

                    x.s = res
                else: discard

    builtin "shuffle",
        alias       = unaliased,
        rule        = PrefixPrecedence,
        description = "get given collection shuffled",
        args        = {
            "collection": {Block, Literal}
        },
        attrs       = NoAttrs,
        returns     = {Block, Nothing},
        example     = """
            shuffle [1 2 3 4 5 6]         ; => [1 5 6 2 3 4 ]
            ..........
            arr: [2 5 9]
            shuffle 'arr
            print arr                     ; 5 9 2
        """:
            #=======================================================
            if x.kind == Literal:
                ensureInPlace()
                InPlaced.a.shuffle()
            else:
                ensureCleaned(x)
                push(newBlock(cleanX.dup(shuffle)))
 
    builtin "size",
        alias       = unaliased,
        rule        = PrefixPrecedence,
        description = "get size/length of given collection",
        args        = {
            "collection": {String, Block, Range, Dictionary, Object, Null}
        },
        attrs       = NoAttrs,
        returns     = {Integer, Floating},
        example     = """
            arr: ["one" "two" "three"]
            print size arr                ; 3
            ..........
            dict: #[name: "John", surname: "Doe"]
            print size dict               ; 2
            ..........
            str: "some text"
            print size str                ; 9

            print size "你好!"              ; 3
        """:
            #=======================================================
            if x.kind == String:
                push(newInteger(runeLen(x.s)))
            elif x.kind == Dictionary:
                push(newInteger(x.d.len))
            elif x.kind == Object:
                push(newInteger(x.o.len))
            elif x.kind == Range:
                let sz = x.rng.len
                if sz == InfiniteRange: push(newFloating(Inf))
                else: push(newInteger(sz))
            elif x.kind == Block:
                ensureCleaned(x)
                push(newInteger(cleanX.len))
            else: # Null
                push(newInteger(0))

    # TODO(Collections/slice) could also work with literal values
    #  labels: library, enhancement
    builtin "slice",
        alias       = unaliased,
        rule        = PrefixPrecedence,
        description = "get a slice of collection between given indices",
        args        = {
            "collection": {String, Block},
            "from"      : {Integer},
            "to"        : {Integer}
        },
        attrs       = NoAttrs,
        returns     = {String, Block},
        example     = """
            slice "Hello" 0 3             ; => "Hell"
            ..........
            print slice 1..10 3 4         ; 4 5
        """:
            #=======================================================
            if x.kind == String:
                if x.s.len == 0: push(newString(""))
                else:
                    if y.i >= 0 and z.i <= x.s.runeLen:
                        push(newString(x.s.runeSubStr(y.i, z.i-y.i+1)))
                    else:
                        push(newString(""))
            else:
                ensureCleaned(x)
                if y.i >= 0 and z.i <= cleanX.len-1:
                    push(newBlock(cleanX[y.i..z.i]))
                else:
                    push(newBlock())

    builtin "sort",
        alias       = unaliased,
        rule        = PrefixPrecedence,
        description = "sort given block in ascending order",
        args        = {
            "collection": {Block, Dictionary, Literal}
        },
        attrs       = {
            "as"        : ({Literal}, "localized by ISO 639-1 language code"),
            "sensitive" : ({Logical}, "case-sensitive sorting"),
            "descending": ({Logical}, "sort in descending order"),
            "ascii"     : ({Logical}, "sort by ASCII transliterations"),
            "values"    : ({Logical}, "sort dictionary by values"),
            "by"        : ({String, Literal}, "sort array of dictionaries by given key")
        },
        returns     = {Block, Nothing},
        example     = """
            a: [3 1 6]
            print sort a                  ; 1 3 6
            ..........
            print sort.descending a       ; 6 3 1
            ..........
            b: ["one" "two" "three"]
            sort 'b
            print b                       ; one three two
        """:
            #=======================================================
            var sortOrdering = SortOrder.Ascending

            if (hadAttr("descending")):
                sortOrdering = SortOrder.Descending

            if x.kind == Block:
                ensureCleaned(x)
                if cleanX.len == 0: push(newBlock())
                else:
                    if checkAttr("by"):
                        if cleanX.len > 0:
                            var sorted: ValueArray

                            if cleanX[0].kind == Dictionary:
                                sorted = cleanX.sorted(
                                    proc (v1, v2: Value): int =
                                    cmp(v1.d[aBy.s], v2.d[aBy.s]),
                                            order = sortOrdering)
                            else:
                                sorted = cleanX.sorted(
                                    proc (v1, v2: Value): int =
                                    cmp(v1.o[aBy.s], v2.o[aBy.s]),
                                            order = sortOrdering)

                            push(newBlock(sorted))
                        else:
                            push(newDictionary())
                    else:
                        var sortAscii = (hadAttr("ascii"))

                        if checkAttr("as"):
                            push(newBlock(cleanX.unisorted(aAs.s,
                                    sensitive = hadAttr("sensitive"),
                                    order = sortOrdering, ascii = sortAscii)))
                        else:
                            if (hadAttr("sensitive")):
                                push(newBlock(cleanX.unisorted("en",
                                        sensitive = true, order = sortOrdering,
                                        ascii = sortAscii)))
                            else:
                                if cleanX[0].kind == String:
                                    push(newBlock(cleanX.unisorted("en",
                                            order = sortOrdering,
                                            ascii = sortAscii)))
                                else:
                                    push(newBlock(cleanX.sorted(
                                            order = sortOrdering)))

            elif x.kind == Dictionary:
                var sorted = x.d
                if (hadAttr("values")):
                    sorted.sort(proc (x, y: (string, Value)): int = cmp(x[1],
                            y[1]), order = sortOrdering)
                else:
                    sorted.sort(system.cmp, order = sortOrdering)

                push(newDictionary(sorted))

            else:
                ensureInPlace()
                if InPlaced.kind == Block:
                    if InPlaced.a.len > 0:
                        if checkAttr("by"):
                            InPlaced.a.sort(
                                proc (v1, v2: Value): int =
                                cmp(v1.d[aBy.s], v2.d[aBy.s]),
                                        order = sortOrdering)
                        else:
                            if checkAttr("as"):
                                InPlaced.a.unisort(aAs.s, sensitive = hadAttr(
                                        "sensitive"), order = sortOrdering)
                            else:
                                if (hadAttr("sensitive")):
                                    InPlaced.a.unisort("en", sensitive = true,
                                            order = sortOrdering)
                                else:
                                    if InPlaced.a[0].kind == String:
                                        InPlaced.a.unisort("en",
                                                order = sortOrdering)
                                    else:
                                        InPlaced.a.sort(order = sortOrdering)
                else:
                    if (hadAttr("values")):
                        InPlaced.d.sort(proc (x, y: (string,
                                Value)): int = cmp(x[1], y[1]),
                                order = sortOrdering)
                    else:
                        InPlaced.d.sort(system.cmp, order = sortOrdering)

    # TODO(Collections/sorted?) doesn't work properly
    #  it should work in an identical way as `sort`
    #  labels: library, enhancement
    builtin "sorted?",
        alias       = unaliased,
        rule        = PrefixPrecedence,
        description = "check if given collection is already sorted",
        args        = {
            "collection": {Block}
        },
        attrs       = {
            "descending": ({Logical}, "check for sorting in ascending order")
        },
        returns     = {Logical},
        example     = """
            sorted? [1 2 3 4 5]         ; => true
            sorted? [4 3 2 1 5]         ; => false
            sorted? [5 4 3 2 1]         ; => false
            ..........
            sorted?.descending [5 4 3 2 1]      ; => true
            sorted?.descending [4 3 2 1 5]      ; => false
            sorted?.descending [1 2 3 4 5]      ; => false
        """:
            #=======================================================
            var ascending = true

            if (hadAttr("descending")):
                ascending = false

            push newLogical(isSorted(x.a, ascending = ascending))


    # TODO(Collections\split) Add better support for unicode strings
    #  Currently, simple split works fine - but using different attributes (at, every, by, etc) doesn't
    #  labels: library,bug
    builtin "split",
        alias       = unaliased,
        rule        = PrefixPrecedence,
        description = "split collection to components",
        args        = {
            "collection": {String, Block, Literal}
        },
        attrs       = {
            "words" : ({Logical}, "split string by whitespace"),
            "lines" : ({Logical}, "split string by lines"),
            "by"    : ({String, Regex, Block}, "split using given separator"),
            "at"    : ({Integer}, "split collection at given position"),
            "every" : ({Integer}, "split collection every *n* elements"),
            "path"  : ({Logical}, "split path components in string")
        },
        returns     = {Block, Nothing},
        example     = """
            split "hello"                 ; => [`h` `e` `l` `l` `o`]
            ..........
            split.words "hello world"     ; => ["hello" "world"]
            ..........
            split.every: 2 "helloworld"
            ; => ["he" "ll" "ow" "or" "ld"]
            ..........
            split.at: 4 "helloworld"
            ; => ["hell" "oworld"]
            ..........
            arr: 1..9
            split.at:3 'arr
            ; => [ [1 2 3 4] [5 6 7 8 9] ]
        """:
            #=======================================================
            # TODO(Collections\split) Verify it's working right
            #  labels: library, bug, unit-test, critical
            if x.kind == Literal:
                ensureInPlace()
                if InPlaced.kind == String:
                    if (hadAttr("words")):
                        SetInPlace(newStringBlock(strutils.splitWhitespace(InPlaced.s)))
                    elif (hadAttr("lines")):
                        SetInPlace(newStringBlock(InPlaced.s.splitLines()))
                    elif (hadAttr("path")):
                        SetInPlace(newStringBlock(InPlaced.s.split(DirSep)))
                    elif checkAttr("by"):
                        if aBy.kind == String:
                            SetInPlace(newStringBlock(InPlaced.s.split(aBy.s)))
                        elif aBy.kind == Regex:
                            SetInPlace(newStringBlock(InPlaced.s.split(aBy.rx)))
                        else:
                            SetInPlace(newStringBlock(toSeq(
                                    InPlaced.s.tokenize(aBy.a.map((k)=>k.s)))))
                    elif checkAttr("at"):
                        SetInPlace(newStringBlock(@[InPlaced.s[0..aAt.i-1],
                                InPlaced.s[aAt.i..^1]]))
                    elif checkAttr("every"):
                        var ret: seq[string]
                        var length = InPlaced.s.len
                        var i = 0

                        while i < length:
                            ret.add(InPlaced.s[i..i+aEvery.i-1])
                            i += aEvery.i

                        SetInPlace(newStringBlock(ret))
                    else:
                        SetInPlace(newStringBlock(toSeq(runes(x.s)).map((x) =>
                                $(x))))
                else:
                    if checkAttr("at"):
                        SetInPlace(newBlock(@[newBlock(InPlaced.a[0..aAt.i]),
                                newBlock(InPlaced.a[aAt.i..^1])]))
                    elif checkAttr("every"):
                        var ret: ValueArray
                        var length = InPlaced.a.len
                        var i = 0

                        while i < length:
                            ret.add(InPlaced.a[i..i+aEvery.i-1])
                            i += aEvery.i

                        SetInPlace(newBlock(ret))
                    else: discard

            elif x.kind == String:
                if (hadAttr("words")):
                    push(newStringBlock(strutils.splitWhitespace(x.s)))
                elif (hadAttr("lines")):
                    push(newStringBlock(x.s.splitLines()))
                elif (hadAttr("path")):
                    push(newStringBlock(x.s.split(DirSep)))
                elif checkAttr("by"):
                    if aBy.kind == String:
                        push(newStringBlock(x.s.split(aBy.s)))
                    elif aBy.kind == Regex:
                        push(newStringBlock(x.s.split(aBy.rx)))
                    else:
                        push(newStringBlock(toSeq(x.s.tokenize(aBy.a.map((k)=>k.s)))))
                elif checkAttr("at"):
                    push(newStringBlock(@[x.s[0..aAt.i-1], x.s[aAt.i..^1]]))
                elif checkAttr("every"):
                    var ret: seq[string]
                    var length = x.s.len
                    var i = 0

                    while i < length:
                        ret.add(x.s[i..i+aEvery.i-1])
                        i += aEvery.i

                    push(newStringBlock(ret))
                else:
                    push(newStringBlock(toSeq(runes(x.s)).map((x) => $(x))))
            else:
                ensureCleaned(x)
                if checkAttr("at"):
                    push(newBlock(@[newBlock(cleanX[0..aAt.i-1]), newBlock(
                            cleanX[aAt.i..^1])]))
                elif checkAttr("every"):
                    var ret: ValueArray
                    var length = cleanX.len
                    var i = 0

                    while i < length:
                        if i+aEvery.i > length:
                            ret.add(newBlock(cleanX[i..^1]))
                        else:
                            ret.add(newBlock(cleanX[i..i+aEvery.i-1]))

                        i += aEvery.i

                    push(newBlock(ret))
                else: push(x)

    builtin "squeeze",
        alias       = unaliased,
        rule        = PrefixPrecedence,
        description = "reduce adjacent elements in given collection",
        args        = {
            "collection": {String, Block, Literal}
        },
        attrs       = NoAttrs,
        returns     = {String, Block, Nothing},
        example     = """
            print squeeze [1 1 2 3 4 2 3 4 4 5 5 6 7]
            ; 1 2 3 4 2 3 4 5 6 7
            ..........
            arr: [4 2 1 1 3 6 6]
            squeeze 'arr            ; a: [4 2 1 3 6]
            ..........
            print squeeze "hello world"
            ; helo world
        """:
            #=======================================================
            if x.kind == Literal:
                ensureInPlace()
                if InPlaced.kind == String:
                    var i = 0
                    var ret: string
                    while i < InPlaced.s.len:
                        ret &= $(InPlaced.s[i])
                        while (i+1 < InPlaced.s.len and InPlaced.s[i+1] == x.s[i]):
                            i += 1
                        i += 1
                    SetInPlace(newString(ret))
                elif InPlaced.kind == Block:
                    var i = 0
                    var ret: ValueArray
                    while i < InPlaced.a.len:
                        ret.add(InPlaced.a[i])
                        while (i+1 < InPlaced.a.len and InPlaced.a[i+1] ==
                                InPlaced.a[i]):
                            i += 1
                        i += 1
                    SetInPlace(newBlock(ret))
            else:
                if x.kind == String:
                    var i = 0
                    var ret: string
                    while i < x.s.len:
                        ret &= $(x.s[i])
                        while (i+1 < x.s.len and x.s[i+1] == x.s[i]):
                            i += 1
                        i += 1
                    push(newString(ret))
                elif x.kind == Block:
                    var i = 0
                    var ret: ValueArray
                    ensureCleaned(x)
                    while i < cleanX.len:
                        ret.add(cleanX[i])
                        while (i+1 < cleanX.len and cleanX[i+1] == cleanX[i]):
                            i += 1
                        i += 1
                    push(newBlock(ret))

    builtin "take",
        alias       = unaliased,
        rule        = PrefixPrecedence,
        description = "keep first <number> of elements from given collection and return the remaining ones",
        args        = {
            "collection": {String, Block, Range, Literal},
            "number"    : {Integer}
        },
        attrs       = NoAttrs,
        returns     = {String, Block, Nothing},
        example     = """
            str: take "some text" 5
            print str                     ; some
            ..........
            arr: 1..10
            take 'arr 3                   ; arr: [1 2 3]
        """:
            #=======================================================
            var upperLimit = y.i-1
            if x.kind == Literal:
                ensureInPlace()
                if InPlaced.kind == String:
                    if x.s.len > 0:
                        if upperLimit > InPlaced.s.len - 1:
                            upperLimit = InPlaced.s.len-1
                        InPlaced.s = InPlaced.s[0..upperLimit]
                elif InPlaced.kind == Block:
                    if InPlaced.a.len > 0:
                        if upperLimit > InPlaced.a.len - 1:
                            upperLimit = InPlaced.a.len-1
                        InPlaced.a = InPlaced.a[0..upperLimit]
                elif InPlaced.kind == Range:
                    var res: ValueArray = newSeq[Value](upperLimit+1)
                    var i = 0
                    for item in items(InPlaced.rng):
                        res[i] = item
                        i += 1
                        if i == upperLimit+1: break
                    InPlaced = newBlock(res)
            else:
                if x.kind == String:
                    if x.s.len == 0: push(newString(""))
                    else:
                        if upperLimit > x.s.len - 1:
                            upperLimit = x.s.len-1
                        push(newString(x.s[0..upperLimit]))
                elif x.kind == Block:
                    ensureCleaned(x)
                    if cleanX.len == 0: push(newBlock())
                    else:
                        if upperLimit > cleanX.len - 1:
                            upperLimit = cleanX.len-1
                        push(newBlock(cleanX[0..upperLimit]))
                elif x.kind == Range:
                    var res: ValueArray = newSeq[Value](upperLimit+1)
                    var i = 0
                    for item in items(x.rng):
                        res[i] = item
                        i += 1
                        if i == upperLimit+1: break
                    push(newBlock(res))

    builtin "tally",
        alias       = unaliased,
        rule        = PrefixPrecedence,
        description = "find number of occurences of each value within given block and return as dictionary",
        args        = {
            "collection": {String, Block}
        },
        attrs       = NoAttrs,
        returns     = {Dictionary},
        example     = """
            tally "helloWorld"
            ; => [h:1 e:1 l:3 o:2 W:1 r:1 d:1]
            ..........
            tally [1 2 4 1 3 5 6 2 6 3 5 7 2 4 2 4 5 6 2 1 1 1]
            ; => [1:5 2:5 4:3 3:2 5:3 6:3 7:1]
        """:
            #=======================================================
            var occurences = initOrderedTable[string,Value]()

            if x.kind == String:
                for r in runes(x.s): 
                    let str = $(r)
                    if not occurences.hasKey(str):
                        occurences[str] = newInteger(0)

                    occurences[str].i += 1
            else:
                for item in x.a:
                    let str = $(item)
                    if not occurences.hasKey(str):
                        occurences[str] = newInteger(0)
                        
                    occurences[str].i += 1
            
            push(newDictionary(occurences))

    builtin "unique",
        alias       = unaliased,
        rule        = PrefixPrecedence,
        description = "get given block without duplicates",
        args        = {
            "collection": {String, Block, Literal}
        },
        attrs       = {
            "id"    : ({Logical}, "generate unique id using given prefix"),
        },
        returns     = {Block, Nothing},
        example     = """
            arr: [1 2 4 1 3 2]
            print unique arr              ; 1 2 4 3
            ..........
            arr: [1 2 4 1 3 2]
            unique 'arr
            print arr                     ; 1 2 4 3
        """:
            #=======================================================
            if (hadAttr("id")):
                # TODO(System\unique) make `.id` work for Web/JS builds
                #  labels: library,enhancement,web
                when not defined(WEB):
                    push newString(x.s & $(genOid()))
            else:
                if x.kind == Block:
                    ensureCleaned(x)
                    push(newBlock(cleanX.deduplicated()))
                else: 
                    ensureInPlace()
                    InPlaced.a = InPlaced.a.deduplicated()

    builtin "values",
        alias       = unaliased,
        rule        = PrefixPrecedence,
        description = "get list of values for given collection",
        args        = {
            "dictionary": {Block, Range, Dictionary, Object}
        },
        attrs       = NoAttrs,
        returns     = {Block},
        example     = """
            user: #[
                name: "John"
                surname: "Doe"
            ]

            values user
            => ["John" "Doe"]
        """:
            #=======================================================
            if x.kind == Block:
                push x
            elif x.kind == Range:
                let items = toSeq(x.rng.items)
                push(newBlock(items))
            elif x.kind == Dictionary:
                let s = toSeq(x.d.values)
                push(newBlock(s))
            else:
                let s = toSeq(x.o.values)
                push(newBlock(s))

    builtin "zero?",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "check if given number or collection size is zero",
        args        = {
            "number"    : {Integer,Floating,String,Block,Range,Dictionary,Object,Null},
        },
        attrs       = NoAttrs,
        returns     = {Logical},
        example     = """
            zero? 5-5           ; => true
            zero? 4             ; => false
            ..........
            zero? 1.0           ; => false
            zero? 0.0           ; => true
            ..........
            items: [1 2 3]
            zero? items         ; => false    

            items: []
            zero? items         ; => true
            ..........
            zero? ø             ; => true
        """:
            #=======================================================
            case x.kind:
                of Integer:
                    if x.iKind == BigInteger:
                        when defined(WEB):
                            push(newLogical(x.bi==big(0)))
                        elif not defined(NOGMP):
                            push(newLogical(isZero(x.bi)))
                    else:
                        push(newLogical(x == I0))
                of Floating:
                    push(newLogical(x == F0))
                of String:
                    push(newLogical(runeLen(x.s) == 0))
                of Block:
                    ensureCleaned(x)
                    push(newLogical(cleanX.len == 0))
                of Range:
                    push(newLogical(x.rng.len == 0))
                of Dictionary:
                    push(newLogical(x.d.len == 0))
                of Object:
                    push(newLogical(x.o.len == 0))
                else:
                    push(VTRUE)

#=======================================
# Add Library
#=======================================

Libraries.add(defineSymbols)
