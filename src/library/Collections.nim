######################################################
# Arturo
# Programming Language + Bytecode VM compiler
# (c) 2019-2021 Yanis Zafirópulos
#
# @file: library/Collections.nim
######################################################

#=======================================
# Pragmas
#=======================================

{.used.}

#=======================================
# Libraries
#=======================================

when not defined(WEB):
    import oids
    import nre except toSeq
else:
    import jsre

import algorithm, os, random, sequtils
import strutils, sugar, unicode
    

import helpers/arrays
import helpers/strings
import helpers/unisort
when defined(WEB):
    import helpers/js

import vm/lib

#=======================================
# Methods
#=======================================

proc defineSymbols*() =

    when defined(VERBOSE):
        echo "- Importing: Collections"

    builtin "append",
        alias       = doubleplus, 
        rule        = InfixPrecedence,
        description = "append value to given collection",
        args        = {
            "collection"    : {String,Char,Block,Literal},
            "value"         : {Any}
        },
        attrs       = NoAttrs,
        returns     = {String,Block,Nothing},
        example     = """
            append "hell" "o"         ; => "hello"
            append [1 2 3] 4          ; => [1 2 3 4]
            append [1 2 3] [4 5]      ; => [1 2 3 4 5]
            
            print "hell" ++ "o!"      ; hello!             
            print [1 2 3] ++ 4 ++ 5   ; [1 2 3 4 5]
            
            a: "hell"
            append 'a "o"
            print a                   ; hello
            
            b: [1 2 3]
            'b ++ 4
            print b                   ; [1 2 3 4]
        """:
            ##########################################################
            if x.kind==Literal:
                if InPlace.kind==String:
                    if y.kind==String:
                        InPlaced.s &= y.s
                    elif y.kind==Char:
                        InPlaced.s &= $(y.c)
                elif InPlaced.kind==Char:
                    if y.kind==String:
                        SetInPlace(newString($(InPlaced.c) & y.s))
                    elif y.kind==Char:
                        SetInPlace(newString($(InPlaced.c) & $(y.c)))
                else:
                    if y.kind==Block:
                        for item in y.a:
                            InPlaced.a.add(item)
                    else:
                        InPlaced.a.add(y)
            else:
                if x.kind==String:
                    if y.kind==String:
                        push(newString(x.s & y.s))
                    elif y.kind==Char:
                        push(newString(x.s & $(y.c)))  
                elif x.kind==Char:
                    if y.kind==String:
                        push(newString($(x.c) & y.s))
                    elif y.kind==Char:
                        push(newString($(x.c) & $(y.c)))          
                else:
                    var ret = newBlock(x.a)

                    if y.kind==Block:
                        for item in y.a:
                            ret.a.add(item)
                    else:
                        ret.a.add(y)
                        
                    push(ret)

    builtin "chop",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "remove last item from given collection",
        args        = {
            "collection"    : {String,Block,Literal}
        },
        attrs       = NoAttrs,
        returns     = {String,Block,Nothing},
        example     = """
            print chop "books"          ; book
            print chop chop "books"     ; boo

            str: "books"
            chop 'str                   ; str: "book"

            chop [1 2 3 4]              ; => [1 2 3]
        """:
            ##########################################################
            if x.kind==Literal:
                if InPlace.kind==String:
                    InPlaced.s = InPlaced.s[0..^2]
                elif InPlaced.kind==Block:
                    InPlaced.a = InPlaced.a[0..^2]
            else:
                if x.kind==String:
                    push(newString(x.s[0..^2]))
                elif x.kind==Block:
                    push(newBlock(x.a[0..^2]))

    builtin "combine",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "get combination of elements in given collections",
        args        = {
            "collectionA"   : {Block},
            "collectionB"   : {Block}
        },
        attrs       = NoAttrs,
        returns     = {Block},
        example     = """
            combine ["one" "two" "three"] [1 2 3]
            ; => [[1 "one"] [2 "two"] [3 "three"]]
        """:
            ##########################################################
            push(newBlock(zip(x.a,y.a).map((z)=>newBlock(@[z[0],z[1]]))))

    builtin "contains?",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "check if collection contains given value",
        args        = {
            "collection"    : {String,Block,Dictionary},
            "value"         : {Any}
        },
        attrs       = {
            "regex" : ({Boolean},"match against a regular expression")
        },
        returns     = {String,Block,Dictionary,Nothing},
        example     = """
            arr: [1 2 3 4]
            
            contains? arr 5             ; => false
            contains? arr 2             ; => true
            
            user: #[
                name: "John"
                surname: "Doe"
            ]
            
            contains? dict "John"       ; => true
            contains? dict "Paul"       ; => false
            
            contains? keys dict "name"  ; => true
            
            contains? "hello" "x"       ; => false
        """:
            ##########################################################
            case x.kind:
                of String:
                    if (popAttr("regex") != VNULL):
                        when not defined(WEB):
                            push(newBoolean(nre.contains(x.s, nre.re(y.s))))
                        else:
                            push(newBoolean(test(newRegExp(y.s,""), x.s)))
                    else:
                        push(newBoolean(y.s in x.s))
                of Block:
                    push(newBoolean(y in x.a))
                of Dictionary: 
                    let values = toSeq(x.d.values)
                    push(newBoolean(y in values))
                else:
                    discard

    builtin "drop",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "drop first <number> of elements from given collection and return the remaining ones",
        args        = {
            "collection"    : {String,Block,Literal},
            "number"        : {Integer}
        },
        attrs       = NoAttrs,
        returns     = {String,Block,Nothing},
        example     = """
            str: drop "some text" 5
            print str                     ; text
            
            arr: 1..10
            drop 'arr 3                   ; arr: [4 5 6 7 8 9 10]
        """:
            ##########################################################
            if x.kind==Literal:
                if InPlace.kind==String:
                    InPlaced.s = InPlaced.s[y.i..^1]
                elif InPlaced.kind==Block:
                    InPlaced.a = InPlaced.a[y.i..^1]
            else:
                if x.kind==String:
                    push(newString(x.s[y.i..^1]))
                elif x.kind==Block:
                    push(newBlock(x.a[y.i..^1]))

    builtin "empty",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "empty given collection",
        args        = {
            "collection"    : {Literal}
        },
        attrs       = NoAttrs,
        returns     = {Nothing},
        example     = """
            a: [1 2 3]
            empty 'a              ; a: []
            
            str: "some text"
            empty 'str            ; str: ""
        """:
            ##########################################################
            case InPlace.kind:
                of String: InPlaced.s = ""
                of Block: InPlaced.a = @[]
                of Dictionary: InPlaced.d = initOrderedTable[string,Value]()
                else: discard

    builtin "empty?",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "check if given collection is empty",
        args        = {
            "collection"    : {String,Block,Dictionary,Null}
        },
        attrs       = NoAttrs,
        returns     = {Boolean},
        example     = """
            empty? ""             ; => true
            empty? []             ; => true
            empty? #[]            ; => true
            
            empty [1 "two" 3]     ; => false
        """:
            ##########################################################
            case x.kind:
                of Null: push(VTRUE)
                of String: push(newBoolean(x.s==""))
                of Block: push(newBoolean(x.a.len==0))
                of Dictionary: push(newBoolean(x.d.len==0))
                else: discard

    builtin "extend",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "get new dictionary by merging given ones",
        args        = {
            "parent"        : {Dictionary},
            "additional"    : {Dictionary}
        },
        attrs       = NoAttrs,
        returns     = {Dictionary},
        example     = """
            person: #[ name: "john" surname: "doe" ]

            print extend person #[ age: 35 ]
            ; [name:john surname:doe age:35]
        """:
            ##########################################################
            if x.kind==Literal:
                discard InPlace
                for k,v in pairs(y.d):
                    InPlaced.d[k] = v
            else:
                var res = copyValue(x)
                for k,v in pairs(y.d):
                    res.d[k] = v

                push(res)

    builtin "first",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "return the first item of the given collection",
        args        = {
            "collection"    : {String,Block}
        },
        attrs       = {
            "n"     : ({Integer},"get first <n> items")
        },
        returns     = {Any},
        example     = """
            print first "this is some text"       ; t
            print first ["one" "two" "three"]     ; one
            
            print first.n:2 ["one" "two" "three"] ; one two
        """:
            ##########################################################
            if (let aN = popAttr("n"); aN != VNULL):
                if x.kind==String: push(newString(x.s[0..aN.i-1]))
                else: push(newBlock(x.a[0..aN.i-1]))
            else:
                if x.kind==String: push(newChar(x.s.runeAt(0)))
                else: push(x.a[0])

    builtin "flatten",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "flatten given collection by eliminating nested blocks",
        args        = {
            "collection"    : {Block},

        },
        attrs       = {
            "once"  : ({Boolean},"do not perform recursive flattening")
        },
        returns     = {Block},
        example     = """
            arr: [[1 2 3] [4 5 6]]
            print flatten arr
            ; 1 2 3 4 5 6
            
            arr: [[1 2 3] [4 5 6]]
            flatten 'arr
            ; arr: [1 2 3 4 5 6]

            flatten [1 [2 3] [4 [5 6]]]
            ; => [1 2 3 4 5 6]

            flatten.once [1 [2 3] [4 [5 6]]]
            ; => [1 2 3 4 [5 6]]
        """:
            ##########################################################
            if x.kind==Literal:
                InPlace = InPlaced.flattened(once = popAttr("once")!=VNULL)
            else:
                push(x.flattened(once = popAttr("once")!=VNULL))

    builtin "get",
        alias       = backslash, 
        rule        = InfixPrecedence,
        description = "get collection's item by given index",
        args        = {
            "collection"    : {String,Block,Dictionary,Date},
            "index"         : {Any}
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
            print user \ 'username        ; Doe
            
            arr: ["zero" "one" "two"]
            
            print arr\1                   ; one
            
            print get arr 2               ; two
            print arr \ 2                 ; two
            
            str: "Hello world!"
            
            print str\0                   ; H
            
            print get str 1               ; e
            print str \ 1                 ; e
        """:
            ##########################################################
            case x.kind:
                of Block: push(GetArrayIndex(x.a, y.i))
                of Dictionary: 
                    if y.kind==String:
                        push(GetKey(x.d, y.s))
                    else:
                        push(GetKey(x.d, $(y)))
                of String: push(newChar(x.s.runeAtPos(y.i)))
                of Date: 
                    push(GetKey(x.e, y.s))
                else: discard

    builtin "in?",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "check if value exists in given collection",
        args        = {
            "value"         : {Any},
            "collection"    : {String,Block,Dictionary}
        },
        attrs       = {
            "regex" : ({Boolean},"match against a regular expression")
        },
        returns     = {String,Block,Dictionary,Nothing},
        example     = """
            arr: [1 2 3 4]
            
            in? 5 arr             ; => false
            in? 2 arr             ; => true
            
            user: #[
                name: "John"
                surname: "Doe"
            ]
            
            in? "John" dict       ; => true
            in? "Paul" dict       ; => false
            
            in? "name" keys dict  ; => true
            
            in? "x" "hello"       ; => false
        """:
            ##########################################################
            case y.kind:
                of String:
                    if (popAttr("regex") != VNULL):
                        when not defined(WEB):
                            push(newBoolean(nre.contains(y.s, nre.re(x.s))))
                        else:
                            push(newBoolean(test(newRegExp(x.s,""), y.s)))
                    else:
                        push(newBoolean(x.s in y.s))
                of Block:
                    push(newBoolean(x in y.a))
                of Dictionary: 
                    let values = toSeq(y.d.values)
                    push(newBoolean(x in values))
                else:
                    discard

    builtin "index",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "return first index of value in given collection",
        args        = {
            "collection"    : {String,Block,Dictionary},
            "value"         : {Any}
        },
        attrs       = NoAttrs,
        returns     = {Integer,String,Null},
        example     = """
            ind: index "hello" "e"
            print ind                 ; 1
            
            print index [1 2 3] 3     ; 2
            
            type index "hello" "x"
            ; :null
        """:
            ##########################################################
            case x.kind:
                of String:
                    let indx = x.s.find(y.s)
                    if indx != -1: push(newInteger(indx))
                    else: push(VNULL)
                of Block:
                    let indx = x.a.find(y)
                    if indx != -1: push(newInteger(indx))
                    else: push(VNULL)
                of Dictionary:
                    var found = false
                    for k,v in pairs(x.d):
                        if v==y:
                            push(newString(k))
                            found=true
                            break

                    if not found:
                        push(VNULL)
                else: discard

    builtin "insert",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "insert value in collection at given index",
        args        = {
            "collection"    : {String,Block,Dictionary,Literal},
            "index"         : {Integer,String},
            "value"         : {Any}
        },
        attrs       = NoAttrs,
        returns     = {String,Block,Dictionary,Nothing},
        example     = """
            insert [1 2 3 4] 0 "zero"
            ; => ["zero" 1 2 3 4]
            
            print insert "heo" 2 "ll"
            ; hello
            
            dict: #[
                name: John
            ]
            
            insert 'dict 'name "Jane"
            ; dict: [name: "Jane"]
        """:
            ##########################################################
            if x.kind==Literal:
                case InPlace.kind:
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
                        var copied = x.a
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
        description = "check if dictionary contains given key",
        args        = {
            "collection"    : {Dictionary},
            "key"           : {Any}
        },
        attrs       = NoAttrs,
        returns     = {Boolean},
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
            ##########################################################
            var needle: string
            if y.kind==String:
                needle = y.s
            else:
                needle = $(y)
            push(newBoolean(x.d.hasKey(needle)))

    builtin "keys",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "get list of keys for given dictionary",
        args        = {
            "dictionary"    : {Dictionary}
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
            ##########################################################
            let s = toSeq(x.d.keys)
            push(newStringBlock(s))

    builtin "last",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "return the last item of the given collection",
        args        = {
            "collection"    : {String,Block}
        },
        attrs       = {
            "n"     : ({Integer},"get last <n> items")
        },
        returns     = {Any},
        example     = """
            print last "this is some text"       ; t
            print last ["one" "two" "three"]     ; three
            
            print last.n:2 ["one" "two" "three"] ; two three
        """:
            ##########################################################
            if (let aN = getAttr("n"); aN != VNULL):
                if x.kind==String: push(newString(x.s[x.s.len-aN.i..^1]))
                else: push(newBlock(x.a[x.a.len-aN.i..^1]))
            else:
                if x.kind==String: 
                    push(newChar(toRunes(x.s)[^1]))
                else: push(x.a[x.a.len-1])

    builtin "max",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "get maximum element in given collection",
        args        = {
            "collection"    : {Block}
        },
        attrs       = NoAttrs,
        returns     = {Any,Null},
        example     = """
            print max [4 2 8 5 1 9]       ; 9
        """:
            ##########################################################
            if x.a.len==0: push(VNULL)
            else:
                var maxElement = x.a[0]
                var i = 1
                while i < x.a.len:
                    if (x.a[i]>maxElement):
                        maxElement = x.a[i]
                    inc(i)

                push(maxElement)

    builtin "min",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "get minimum element in given collection",
        args        = {
            "collection"    : {Block}
        },
        attrs       = NoAttrs,
        returns     = {Any,Null},
        example     = """
            print min [4 2 8 5 1 9]       ; 1
        """:
            ##########################################################
            if x.a.len==0: push(VNULL)
            else:
                var minElement = x.a[0]
                var i = 1
                while i < x.a.len:
                    if (x.a[i]<minElement):
                        minElement = x.a[i]
                    inc(i)
                    
                push(minElement)

    builtin "permutate",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "get all possible permutations of the elements in given collection",
        args        = {
            "collection"    : {Block}
        },
        attrs       = NoAttrs,
        returns     = {Block},
        example     = """
            permutate [A B C]
            ; => [[A B C] [A C B] [C A B] [B A C] [B C A] [C B A]]
        """:
            ##########################################################
            var ret: ValueArray = @[]
        
            permutate(x.a, proc(s: ValueArray)= 
                ret.add(newBlock(s))
            )

            push(newBlock(ret))

    builtin "remove",
        alias       = doubleminus, 
        rule        = InfixPrecedence,
        description = "remove value from given collection",
        args        = {
            "collection"    : {String,Block,Dictionary,Literal},
            "value"         : {Any}
        },
        attrs       = {
            "key"   : ({Boolean},"remove dictionary key"),
            "once"  : ({Boolean},"remove only first occurence"),
            "index" : ({Boolean},"remove specific index"),
            "prefix": ({Boolean},"remove first matching prefix from string"),
            "suffix": ({Boolean},"remove first matching suffix from string")
        },
        returns     = {String,Block,Dictionary,Nothing},
        example     = """
            remove "hello" "l"        ; => "heo"
            print "hello" -- "l"      ; heo
            
            str: "mystring"
            remove 'str "str"         
            print str                 ; mying
            
            print remove.once "hello" "l"
            ; helo
            
            remove [1 2 3 4] 4        ; => [1 2 3]
        """:
            ##########################################################
            if x.kind==Literal:
                if InPlace.kind==String:
                    if (popAttr("once") != VNULL):
                        SetInPlace(newString(InPlaced.s.removeFirst(y.s)))
                    elif (popAttr("prefix") != VNULL):
                        InPlace.s.removePrefix(y.s)
                    elif (popAttr("suffix") != VNULL):
                        InPlace.s.removeSuffix(y.s)
                    else:
                        SetInPlace(newString(InPlaced.s.replace(y.s)))
                elif InPlaced.kind==Block: 
                    if (popAttr("once") != VNULL):
                        SetInPlace(newBlock(InPlaced.a.removeFirst(y)))
                    elif (popAttr("index") != VNULL):
                        SetInPlace(newBlock(InPlaced.a.removeByIndex(y.i)))
                    else:
                        SetInPlace(newBlock(InPlaced.a.removeAll(y)))
                elif InPlaced.kind==Dictionary:
                    let key = (popAttr("key") != VNULL)
                    if (popAttr("once") != VNULL):
                        SetInPlace(newDictionary(InPlaced.d.removeFirst(y, key)))
                    else:
                        SetInPlace(newDictionary(InPlaced.d.removeAll(y, key)))
            else:
                if x.kind==String:
                    if (popAttr("once") != VNULL):
                        push(newString(x.s.removeFirst(y.s)))
                    elif (popAttr("prefix") != VNULL):
                        var ret = x.s
                        ret.removePrefix(y.s)
                        push(newString(ret))
                    elif (popAttr("suffix") != VNULL):
                        var ret = x.s
                        ret.removeSuffix(y.s)
                        push(newString(ret))
                    else:
                        push(newString(x.s.replace(y.s)))
                elif x.kind==Block: 
                    if (popAttr("once") != VNULL):
                        push(newBlock(x.a.removeFirst(y)))
                    elif (popAttr("index") != VNULL):
                        push(newBlock(x.a.removeByIndex(y.i)))
                    else:
                        push(newBlock(x.a.removeAll(y)))
                elif x.kind==Dictionary:
                    let key = (popAttr("key") != VNULL)
                    if (popAttr("once") != VNULL):
                        push(newDictionary(x.d.removeFirst(y, key)))
                    else:
                        push(newDictionary(x.d.removeAll(y, key)))

    builtin "repeat",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "repeat value the given number of times and return new one",
        args        = {
            "value" : {Any,Literal},
            "times" : {Integer}
        },
        attrs       = NoAttrs,
        returns     = {String,Block},
        example     = """
            print repeat "hello" 3
            ; hellohellohello
            
            repeat [1 2 3] 3
            ; => [1 2 3 1 2 3 1 2 3]
            
            repeat 5 3
            ; => [5 5 5]
            
            repeat [[1 2 3]] 3
            ; => [[1 2 3] [1 2 3] [1 2 3]]
        """:
            ##########################################################
            if x.kind==Literal:
                if InPlace.kind==String:
                    SetInPlace(newString(InPlaced.s.repeat(y.i)))
                elif InPlaced.kind==Block:
                    SetInPlace(newBlock(InPlaced.a.cycle(y.i)))
                else:
                    SetInPlace(newBlock(InPlaced.repeat(y.i)))
            else:
                if x.kind==String:
                    push(newString(x.s.repeat(y.i)))
                elif x.kind==Block:
                    push(newBlock(x.a.cycle(y.i)))
                else:
                    push(newBlock(x.repeat(y.i)))

    builtin "reverse",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "reverse given collection",
        args        = {
            "collection"    : {String,Block,Literal}
        },
        attrs       = NoAttrs,
        returns     = {String,Block,Nothing},
        example     = """
            print reverse [1 2 3 4]           ; 4 3 2 1
            print reverse "Hello World"       ; dlroW olleH
            
            str: "my string"
            reverse 'str
            print str                         ; gnirts ym
        """:
            ##########################################################
            proc reverse(s: var string) =
                for i in 0 .. s.high div 2:
                    swap(s[i], s[s.high - i])
        
            proc reversed(s: string): string =
                result = newString(s.len)
                for i,c in s:
                    result[s.high - i] = c

            if x.kind==Literal:
                if InPlace.kind==String:
                    InPlaced.s.reverse()
                else:
                    InPlaced.a.reverse()
            else:
                if x.kind==Block: push(newBlock(x.a.reversed))
                elif x.kind==String: push(newString(x.s.reversed))

    builtin "sample",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "get a random element from given collection",
        args        = {
            "collection"    : {Block}
        },
        attrs       = NoAttrs,
        returns     = {Any},
        example     = """
            sample [1 2 3]        ; (return a random number from 1 to 3)
            print sample ["apple" "appricot" "banana"]
            ; apple
        """:
            ##########################################################
            push(sample(x.a))

    builtin "set",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "set collection's item at index to given value",
        args        = {
            "collection"    : {String,Block,Dictionary},
            "index"         : {Any},
            "value"         : {Any}
        },
        attrs       = NoAttrs,
        returns     = {Nothing},
        example     = """
            myDict: #[ 
                name: "John"
                age: 34
            ]
            
            set myDict 'name "Michael"        ; => [name: "Michael", age: 34]
            
            arr: [1 2 3 4]
            set arr 0 "one"                   ; => ["one" 2 3 4]
        """:
            ##########################################################
            case x.kind:
                of Block: 
                    SetArrayIndex(x.a, y.i, z)
                of Dictionary:
                    if y.kind==String:
                        x.d[y.s] = z
                    else:
                        x.d[$(y)] = z
                else: discard

    builtin "shuffle",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "get given collection shuffled",
        args        = {
            "collection"    : {Block,Literal}
        },
        attrs       = NoAttrs,
        returns     = {Block,Nothing},
        example     = """
            shuffle [1 2 3 4 5 6]         ; => [1 5 6 2 3 4 ]
            
            arr: [2 5 9]
            shuffle 'arr
            print arr                     ; 5 9 2
        """:
            ##########################################################
            if x.kind==Literal:
                InPlace.a.shuffle()
            else:
                push(newBlock(x.a.dup(shuffle)))

    builtin "size",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "get size/length of given collection",
        args        = {
            "collection"    : {String,Block,Dictionary}
        },
        attrs       = NoAttrs,
        returns     = {Integer},
        example     = """
            str: "some text"      
            print size str                ; 9
            
            print size "你好!"              ; 3
        """:
            ##########################################################
            if x.kind==String:
                push(newInteger(runeLen(x.s)))
            elif x.kind==Dictionary:
                push(newInteger(x.d.len))
            else:
                push(newInteger(x.a.len))
            
    builtin "slice",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "get a slice of collection between given indices",
        args        = {
            "collection"    : {String,Block},
            "from"          : {Integer},
            "to"            : {Integer}
        },
        attrs       = NoAttrs,
        returns     = {String,Block},
        example     = """
            slice "Hello" 0 3             ; => "Hell"
            print slice 1..10 3 4         ; 4 5
        """:
            ##########################################################
            if x.kind==String:
                push(newString(x.s.runeSubStr(y.i,z.i-y.i+1)))
            else:
                push(newBlock(x.a[y.i..z.i]))

    builtin "sort",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "sort given block in ascending order",
        args        = {
            "collection"    : {Block,Dictionary,Literal}
        },
        attrs       = {
            "as"        : ({Literal},"localized by ISO 639-1 language code"),
            "sensitive" : ({Boolean},"case-sensitive sorting"),
            "descending": ({Boolean},"sort in ascending order"),
            "values"    : ({Boolean},"sort dictionary by values"),
            "by"        : ({String,Literal},"sort array of dictionaries by given key")
        },
        returns     = {Block,Nothing},
        example     = """
            a: [3 1 6]
            print sort a                  ; 1 3 6
            
            print sort.descending a       ; 6 3 1
            
            b: ["one" "two" "three"]
            sort 'b
            print b                       ; one three two
        """:
            ##########################################################
            var sortOrdering = SortOrder.Ascending

            if (popAttr("descending")!=VNULL):
                sortOrdering = SortOrder.Descending

            if x.kind==Block: 
                if (let aBy = popAttr("by"); aBy != VNULL):
                    var sorted: ValueArray = x.a.sorted(
                        proc (v1, v2: Value): int = 
                            cmp(v1.d[aBy.s], v2.d[aBy.s]), order=sortOrdering)
                    push(newBlock(sorted))
                else:
                    if (let aAs = popAttr("as"); aAs != VNULL):
                        push(newBlock(x.a.unisorted(aAs.s, sensitive = popAttr("sensitive")!=VNULL, order = sortOrdering)))
                    else:
                        if (popAttr("sensitive")!=VNULL):
                            push(newBlock(x.a.unisorted("en", sensitive=true, order = sortOrdering)))
                        else:
                            if x.a[0].kind==String:
                                push(newBlock(x.a.unisorted("en", order = sortOrdering)))
                            else:
                                push(newBlock(x.a.sorted(order = sortOrdering)))

            elif x.kind==Dictionary:
                var sorted = x.d
                if (popAttr("values") != VNULL):
                    sorted.sort(proc (x, y: (string, Value)): int = cmp(x[1], y[1]), order=sortOrdering)
                else:
                    sorted.sort(system.cmp, order=sortOrdering)
                
                push(newDictionary(sorted))

            else: 
                if InPlace.kind==Block:
                    if (let aBy = popAttr("by"); aBy != VNULL):
                        InPlace.a.sort(
                            proc (v1, v2: Value): int = 
                                cmp(v1.d[aBy.s], v2.d[aBy.s]), order=sortOrdering)
                    else:
                        if (let aAs = popAttr("as"); aAs != VNULL):
                            InPlaced.a.unisort(aAs.s, sensitive = popAttr("sensitive")!=VNULL, order = sortOrdering)
                        else:
                            if (popAttr("sensitive")!=VNULL):
                                InPlaced.a.unisort("en", sensitive=true, order = sortOrdering)
                            else:
                                if InPlace.a[0].kind==String:
                                    InPlaced.a.unisort("en", order = sortOrdering)
                                else:
                                    InPlaced.a.sort(order = sortOrdering)
                else:
                    if (popAttr("values") != VNULL):
                        InPlaced.d.sort(proc (x, y: (string,Value)): int = cmp(x[1], y[1]), order=sortOrdering)
                    else:
                        InPlaced.d.sort(system.cmp, order=sortOrdering)


    # TODO(Collections\split) Add better support for unicode strings
    #  Currently, simple split works fine - but using different attributes (at, every, by, etc) doesn't
    #  labels: library,bug
    builtin "split",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "split collection to components",
        args        = {
            "collection"    : {String,Block,Literal}
        },
        attrs       = {
            "words"     : ({Boolean},"split string by whitespace"),
            "lines"     : ({Boolean},"split string by lines"),
            "by"        : ({String,Block},"split using given separator"),
            "regex"     : ({Boolean},"match against a regular expression"),
            "at"        : ({Integer},"split collection at given position"),
            "every"     : ({Integer},"split collection every <n> elements"),
            "path"      : ({Boolean},"split path components in string")
        },
        returns     = {Block,Nothing},
        example     = """
            split "hello"                 ; => [`h` `e` `l` `l` `o`]
            split.words "hello world"     ; => ["hello" "world"]
            
            split.every: 2 "helloworld"
            ; => ["he" "ll" "ow" "or" "ld"]
            
            split.at: 4 "helloworld"
            ; => ["hell" "oworld"]
            
            arr: 1..9
            split.at:3 'arr
            ; => [ [1 2 3 4] [5 6 7 8 9] ]
        """:
            ##########################################################
            if x.kind==Literal:
                if InPlace.kind==String:
                    if (popAttr("words") != VNULL):
                        SetInPlace(newStringBlock(strutils.splitWhitespace(InPlaced.s)))
                    elif (popAttr("lines") != VNULL):
                        SetInPlace(newStringBlock(InPlaced.s.splitLines()))
                    elif (popAttr("path") != VNULL):
                        SetInPlace(newStringBlock(InPlaced.s.split(DirSep)))
                    elif (let aBy = popAttr("by"); aBy != VNULL):
                        if aBy.kind==String:
                            SetInPlace(newStringBlock(InPlaced.s.split(aBy.s)))
                        else:
                            SetInPlace(newStringBlock(toSeq(InPlaced.s.tokenize(aBy.a.map((k)=>k.s)))))
                    elif (let aRegex = popAttr("regex"); aRegex != VNULL):
                        when not defined(WEB):
                            SetInPlace(newStringBlock(InPlaced.s.split(nre.re(aRegex.s))))
                        else:
                            SetInPlace(newStringBlock(InPlaced.s.split(newRegExp(aRegex.s,""))))
                    elif (let aAt = popAttr("at"); aAt != VNULL):
                        SetInPlace(newStringBlock(@[InPlaced.s[0..aAt.i-1], InPlaced.s[aAt.i..^1]]))
                    elif (let aEvery = popAttr("every"); aEvery != VNULL):
                        var ret: seq[string] = @[]
                        var length = InPlaced.s.len
                        var i = 0

                        while i<length:
                            ret.add(InPlaced.s[i..i+aEvery.i-1])
                            i += aEvery.i

                        SetInPlace(newStringBlock(ret))
                    else:
                        SetInPlace(newStringBlock(toSeq(runes(x.s)).map((x) => $(x))))
                else:
                    if (let aAt = popAttr("at"); aAt != VNULL):
                        SetInPlace(newBlock(@[newBlock(InPlaced.a[0..aAt.i]), newBlock(InPlaced.a[aAt.i..^1])]))
                    elif (let aEvery = popAttr("every"); aEvery != VNULL):
                        var ret: ValueArray = @[]
                        var length = InPlaced.a.len
                        var i = 0

                        while i<length:
                            ret.add(InPlaced.a[i..i+aEvery.i-1])
                            i += aEvery.i

                        SetInPlace(newBlock(ret))
                    else: discard

            elif x.kind==String:
                if (popAttr("words") != VNULL):
                    push(newStringBlock(strutils.splitWhitespace(x.s)))
                elif (popAttr("lines") != VNULL):
                    push(newStringBlock(x.s.splitLines()))
                elif (popAttr("path") != VNULL):
                    push(newStringBlock(x.s.split(DirSep)))
                elif (let aBy = popAttr("by"); aBy != VNULL):
                    if aBy.kind==String:
                        push(newStringBlock(x.s.split(aBy.s)))
                    else:
                        push(newStringBlock(toSeq(x.s.tokenize(aBy.a.map((k)=>k.s)))))
                elif (let aRegex = popAttr("regex"); aRegex != VNULL):
                    when not defined(WEB):
                        push(newStringBlock(x.s.split(nre.re(aRegex.s))))
                    else:
                        push(newStringBlock(x.s.split(newRegExp(aRegex.s,""))))
                elif (let aAt = popAttr("at"); aAt != VNULL):
                    push(newStringBlock(@[x.s[0..aAt.i-1], x.s[aAt.i..^1]]))
                elif (let aEvery = popAttr("every"); aEvery != VNULL):
                    var ret: seq[string] = @[]
                    var length = x.s.len
                    var i = 0

                    while i<length:
                        ret.add(x.s[i..i+aEvery.i-1])
                        i += aEvery.i

                    push(newStringBlock(ret))
                else:
                    push(newStringBlock(toSeq(runes(x.s)).map((x) => $(x))))
            else:
                if (let aAt = popAttr("at"); aAt != VNULL):
                    push(newBlock(@[newBlock(x.a[0..aAt.i-1]), newBlock(x.a[aAt.i..^1])]))
                elif (let aEvery = popAttr("every"); aEvery != VNULL):
                    var ret: ValueArray = @[]
                    var length = x.a.len
                    var i = 0

                    while i<length:
                        if i+aEvery.i > length:
                            ret.add(newBlock(x.a[i..^1]))
                        else:
                            ret.add(newBlock(x.a[i..i+aEvery.i-1]))

                        i += aEvery.i

                    push(newBlock(ret))
                else: push(x)

    builtin "squeeze",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "reduce adjacent elements in given collection",
        args        = {
            "collection"    : {String,Block,Literal}
        },
        attrs       = NoAttrs,
        returns     = {String,Block,Nothing},
        example     = """
            print squeeze [1 1 2 3 4 2 3 4 4 5 5 6 7]
            ; 1 2 3 4 2 3 4 5 6 7 

            arr: [4 2 1 1 3 6 6]
            squeeze 'arr            ; a: [4 2 1 3 6]

            print squeeze hello world";
            ; helo world
        """:
            ##########################################################
            if x.kind==Literal:
                if InPlace.kind==String:
                    var i = 0
                    var ret = ""
                    while i<InPlaced.s.len:
                        ret &= $(InPlaced.s[i])
                        while (i+1<InPlaced.s.len and InPlaced.s[i+1]==x.s[i]):
                            i += 1
                        i += 1
                    SetInPlace(newString(ret))
                elif InPlaced.kind==Block:
                    var i = 0
                    var ret: ValueArray = @[]
                    while i<InPlaced.a.len:
                        ret.add(InPlaced.a[i])
                        while (i+1<InPlaced.a.len and InPlaced.a[i+1]==InPlaced.a[i]):
                            i += 1
                        i += 1
                    SetInPlace(newBlock(ret))
            else:
                if x.kind==String:
                    var i = 0
                    var ret = ""
                    while i<x.s.len:
                        ret &= $(x.s[i])
                        while (i+1<x.s.len and x.s[i+1]==x.s[i]):
                            i += 1
                        i += 1
                    push(newString(ret))
                elif x.kind==Block:
                    var i = 0
                    var ret: ValueArray = @[]
                    while i<x.a.len:
                        ret.add(x.a[i])
                        while (i+1<x.a.len and x.a[i+1]==x.a[i]):
                            i += 1
                        i += 1
                    push(newBlock(ret))

    builtin "take",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "keep first <number> of elements from given collection and return the remaining ones",
        args        = {
            "collection"    : {String,Block,Literal},
            "number"        : {Integer}
        },
        attrs       = NoAttrs,
        returns     = {String,Block,Nothing},
        example     = """
            str: take "some text" 5
            print str                     ; some
            
            arr: 1..10
            take 'arr 3                   ; arr: [1 2 3]
        """:
            ##########################################################
            if x.kind==Literal:
                if InPlace.kind==String:
                    InPlaced.s = InPlaced.s[0..y.i-1]
                elif InPlaced.kind==Block:
                    InPlaced.a = InPlaced.a[0..y.i-1]
            else:
                if x.kind==String:
                    push(newString(x.s[0..y.i-1]))
                elif x.kind==Block:
                    push(newBlock(x.a[0..y.i-1]))

    builtin "unique",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "get given block without duplicates",
        args        = {
            "collection"    : {String,Block,Literal}
        },
        attrs       = {
            "id"    : ({Boolean},"generate unique id using given prefix"),
        },
        returns     = {Block,Nothing},
        example     = """
            arr: [1 2 4 1 3 2]
            print unique arr              ; 1 2 4 3
            
            arr: [1 2 4 1 3 2]
            unique 'arr
            print arr                     ; 1 2 4 3
        """:
            ##########################################################
            if (popAttr("id") != VNULL):
                when not defined(WEB):
                    push newString(x.s & $(genOid()))
            else:
                if x.kind==Block: push(newBlock(x.a.deduplicate()))
                else: InPlace.a = InPlaced.a.deduplicate()

    builtin "values",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "get list of values for given dictionary",
        args        = {
            "dictionary"    : {Dictionary}
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
            ##########################################################
            let s = toSeq(x.d.values)
            push(newBlock(s))

#=======================================
# Add Library
#=======================================

Libraries.add(defineSymbols)