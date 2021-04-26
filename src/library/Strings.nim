######################################################
# Arturo
# Programming Language + Bytecode VM compiler
# (c) 2019-2021 Yanis Zafirópulos
#
# @file: library/Strings.nim
######################################################

#=======================================
# Pragmas
#=======================================

{.used.}

#=======================================
# Libraries
#=======================================

when not defined(WEB):
    import re
    import nre except toSeq
import json, std/editdistance, os
import sequtils, strutils, unicode, xmltree

import helpers/colors
import helpers/strings

import vm/lib
import vm/[eval, exec, parse]

#=======================================
# Variables
#=======================================

var
    templateStore = initOrderedTable[string,Translation]()

#=======================================
# Methods
#=======================================

proc defineSymbols*() =

    when defined(VERBOSE):
        echo "- Importing: Strings"

    builtin "ascii?",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "check if given character/string is in ASCII",
        args        = {
            "string": {Char,String}
        },
        attrs       = NoAttrs,
        returns     = {Boolean},
        example     = """
            ascii? `d`              ; true
            ascii? `😀`             ; false

            ascii? "hello world"    ; true
            ascii? "Hællø wœrld"    ; false
            ascii? "Γειά!"          ; false
        """:
            ##########################################################
            if x.kind==Char:
                push(newBoolean(ord(x.c)<128))
            else:
                var allOK = true
                for ch in runes(x.s):
                    if ord(ch) >= 128:
                        allOK = false
                        push(VFALSE)
                        break

                if allOK:
                    push(VTRUE)

    builtin "capitalize",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "convert given string to capitalized",
        args        = {
            "string": {String,Literal}
        },
        attrs       = NoAttrs,
        returns     = {String,Nothing},
        example     = """
            print capitalize "hello World"      ; "Hello World"
            
            str: "hello World"
            capitalize 'str                     ; str: "Hello World"
        """:
            ##########################################################
            if x.kind==String: push(newString(x.s.capitalize()))
            else: InPlace.s = InPlaced.s.capitalize()

    builtin "color",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "get colored version of given string",
        args        = {
            "string": {String}
        },
        attrs       = {
            "rgb"       : ({Integer},"use specific RGB color"),
            "bold"      : ({Boolean},"bold font"),
            "black"     : ({Boolean},"black foreground color"),
            "red"       : ({Boolean},"red foreground color"),
            "green"     : ({Boolean},"green foreground color"),
            "yellow"    : ({Boolean},"yellow foreground color"),
            "blue"      : ({Boolean},"blue foreground color"),
            "magenta"   : ({Boolean},"magenta foreground color"),
            "cyan"      : ({Boolean},"cyan foreground color"),
            "white"     : ({Boolean},"white foreground color"),
            "gray"      : ({Boolean},"gray foreground color")
        },
        returns     = {String},
        example     = """
            print color.green "Hello!"                ; Hello! (in green)
            print color.red.bold "Some text"          ; Some text (in red/bold)
        """:
            ##########################################################
            var color = ""

            if (let aRgb = popAttr("rgb"); aRgb != VNULL):
                color = rgb($(aRgb.i))
            if (popAttr("black") != VNULL):
                color = blackColor
            elif (popAttr("red") != VNULL):
                color = redColor
            elif (popAttr("green") != VNULL):
                color = greenColor
            elif (popAttr("yellow") != VNULL):
                color = yellowColor
            elif (popAttr("blue") != VNULL):
                color = blueColor
            elif (popAttr("magenta") != VNULL):
                color = magentaColor
            elif (popAttr("cyan") != VNULL):
                color = cyanColor
            elif (popAttr("white") != VNULL):
                color = whiteColor
            elif (popAttr("gray") != VNULL):
                color = grayColor

            var finalColor = ""

            if (popAttr("bold") != VNULL):
                finalColor = bold(color)
            elif (popAttr("underline") != VNULL):
                finalColor = underline(color)
            else:
                finalColor = fg(color)

            push(newString(finalColor & x.s & resetColor))

    builtin "escape",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "escape given string",
        args        = {
            "string": {String,Literal}
        },
        attrs       = {
            "json"  : ({Boolean},"for literal use in JSON strings"),
            "regex" : ({Boolean},"for literal use in regular expression"),
            "shell" : ({Boolean},"for use in a shell command"),
            "xml"   : ({Boolean},"for use in an XML document")
        },
        returns     = {String,Nothing},
        example     = """
            str: {a long "string" + with \diffe\rent symbols.}

            print escape str
            ; "a long \"string\" + with \\diffe\\rent symbols."

            print escape.json str
            ; a long \"string\" + with \\diffe\\rent symbols.

            print escape.regex str
            ; a\x20long\x20\x22string\x22\x20\x2B\x20with\x20\x5Cdiffe\x5Crent\x20symbols\x2E

            print escape.shell str
            ; 'a long "string" + with \diffe\rent symbols.'

            print escape.xml str
            ; a long &quot;string&quot; + with \diffe\rent symbols.
        """:
            ##########################################################
            if x.kind==Literal:
                if (popAttr("json") != VNULL):
                    SetInPlace(newString(escapeJsonUnquoted(InPlace.s)))
                elif (popAttr("regex") != VNULL):
                    when not defined(WEB):
                        SetInPlace(newString(re.escapeRe(InPlace.s)))
                elif (popAttr("shell") != VNULL):
                    when not defined(WEB):
                        SetInPlace(newString(quoteShell(InPlace.s)))
                elif (popAttr("xml") != VNULL):
                    SetInPlace(newString(xmltree.escape(InPlace.s)))
                else:
                    SetInPlace(newString(strutils.escape(InPlace.s)))
            else:
                if (popAttr("json") != VNULL):
                    push(newString(escapeJsonUnquoted(x.s)))
                elif (popAttr("regex") != VNULL):
                    when not defined(WEB):
                        push(newString(re.escapeRe(x.s)))
                elif (popAttr("shell") != VNULL):
                    when not defined(WEB):
                        push(newString(quoteShell(x.s)))
                elif (popAttr("xml") != VNULL):
                    push(newString(xmltree.escape(x.s)))
                else:
                    push(newString(strutils.escape(x.s)))

    builtin "indent",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "indent each line of given text",
        args        = {
            "text"  : {String,Literal}
        },
        attrs       = {
            "n"     : ({Integer},"pad by given number of spaces (default: 4)"),
            "with"  : ({String},"use given padding")
        },
        returns     = {String,Nothing},
        example     = """
            str: "one\ntwo\nthree"

            print indent str
            ;     one
            ;     two
            ;     three

            print indent .n:10 .with:"#" str
            ; ##########one
            ; ##########two
            ; ##########three
        """:
            ##########################################################
            var count = 4
            var padding = " "

            if (let aN = popAttr("n"); aN != VNULL):
                count = aN.i

            if (let aWith = popAttr("with"); aWith != VNULL):
                padding = aWith.s

            if x.kind==Literal:
                SetInPlace(newString(indent(InPlace.s, count, padding)))
            else:
                push(newString(indent(x.s, count, padding)))            

    builtin "join",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "join collection of values into string",
        args        = {
            "collection"    : {Block,Literal}
        },
        attrs       = {
            "with"  : ({String},"use given separator"),
            "path"  : ({Boolean},"join as path components")
        },
        returns     = {String,Nothing},
        example     = """
            arr: ["one" "two" "three"]
            print join arr
            ; onetwothree
            
            print join.with:"," arr
            ; one,two,three
            
            join 'arr
            ; arr: "onetwothree"

            print join [`H` `e` `l` `l` `o` `!`]
            ; Hello!

            print join @["1 + 2 = " 1+2]
            ; 1 + 2 = 3
        """:
            ##########################################################
            if (popAttr("path") != VNULL):
                if x.kind==Literal:
                    SetInPlace(newString(joinPath(InPlace.a.map(proc (v:Value):string = $(v)))))
                else:
                    push(newString(joinPath(x.a.map(proc (v:Value):string = $(v)))))
            else:
                var sep = ""
                if (let aWith = popAttr("with"); aWith != VNULL):
                    sep = aWith.s

                if x.kind==Literal:
                    SetInPlace(newString(InPlace.a.map(proc (v:Value):string = $(v)).join(sep)))
                else:
                    push(newString(x.a.map(proc (v:Value):string = $(v)).join(sep)))

    builtin "levenshtein",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "calculate Levenshtein distance between given strings",
        args        = {
            "stringA"   : {String},
            "stringB"   : {String}
        },
        attrs       = NoAttrs,
        returns     = {Integer},
        example     = """
            print levenshtein "for" "fur"         ; 1
            print levenshtein "one" "one"         ; 0
        """:
            push(newInteger(editDistance(x.s,y.s)))

    builtin "lower",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "convert given string to lowercase",
        args        = {
            "string": {String,Literal}
        },
        attrs       = NoAttrs,
        returns     = {String,Nothing},
        example     = """
            print lower "hello World, 你好!"      ; "hello world, 你好!"
            
            str: "hello World, 你好!"
            lower 'str                           ; str: "hello world, 你好!"
        """:
            ##########################################################
            if x.kind==String: push(newString(x.s.toLower()))
            else: InPlace.s = InPlaced.s.toLower()

    builtin "lower?",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "check if given string is lowercase",
        args        = {
            "string": {String}
        },
        attrs       = NoAttrs,
        returns     = {Boolean},
        example     = """
            lower? "ñ"               ; => true
            lower? "X"               ; => false
            lower? "Hello World"     ; => false
            lower? "hello"           ; => true
        """:
            ##########################################################
            var broken = false
            for c in runes(x.s):
                if not c.isLower():
                    push(VFALSE)
                    broken = true
                    break

            if not broken:
                push(VTRUE)

    when not defined(WEB):
        builtin "match",
            alias       = unaliased, 
            rule        = PrefixPrecedence,
            description = "get matches within string, using given regular expression",
            args        = {
                "string": {String},
                "regex" : {String}
            },
            attrs       = NoAttrs,
            returns     = {Block},
            example     = """
                print match "hello" "hello"             ; => ["hello"]
                match "x: 123, y: 456" "[0-9]+"         ; => [123 456]
                match "this is a string" "[0-9]+"       ; => []
            """:
                ##########################################################
                push(newStringBlock(x.s.findAll(re.re(y.s))))

    builtin "numeric?",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "check if given string is numeric",
        args        = {
            "string": {String}
        },
        attrs       = NoAttrs,
        returns     = {Boolean},
        example     = """
            numeric? "hello"           ; => false
            numeric? "3.14"            ; => true
            numeric? "18966"           ; => true
            numeric? "123xxy"          ; => false
        """:
            ##########################################################
            try:
                discard x.s.parseFloat()
                push(VTRUE)
            except ValueError:
                push(VFALSE)

    builtin "outdent",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "outdent each line of given text, by using minimum shared indentation",
        args        = {
            "text"  : {String,Literal}
        },
        attrs       = {
            "n"     : ({Integer},"unpad by given number of spaces"),
            "with"  : ({String},"use given padding")
        },
        returns     = {String,Nothing},
        example     = """
            print outdent {:
                one
                    two
                    three
            :}
            ; one
            ;     two
            ;     three

            print outdent.n:1 {:
                one
                    two
                    three
            :}
            ;  one
            ;      two
            ;      three

        """:
            ##########################################################
            var count = 0
            if x.kind==Literal:
                count = indentation(InPlace.s)
            else:
                count = indentation(x.s)

            var padding = " "

            if (let aN = popAttr("n"); aN != VNULL):
                count = aN.i

            if (let aWith = popAttr("with"); aWith != VNULL):
                padding = aWith.s

            if x.kind==Literal:
                SetInPlace(newString(unindent(InPlaced.s, count, padding)))
            else:
                push(newString(unindent(x.s, count, padding))) 

    builtin "pad",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "check if given string consists only of whitespace",
        args        = {
            "string"    : {String,Literal},
            "padding"   : {Integer}
        },
        attrs       = {
            "center"    : ({Boolean},"add padding to both sides"),
            "right"     : ({Boolean},"add right padding"),
            "with"      : ({Char},"pad with given character")
        },
        returns     = {String},
        example     = """
            pad "good" 10                 ; => "      good"
            pad.right "good" 10           ; => "good      "
            pad.center "good" 10          ; => "   good   "
            
            a: "hello"
            pad 'a 10                     ; a: "     hello"

            pad.with:`0` to :string 123 5   
            ; => 00123
        """:
            ##########################################################
            var padding = ' '.Rune
            if (let aWith = popAttr("with"); aWith != VNULL):
                padding = aWith.c

            if (popAttr("right") != VNULL):
                if x.kind==String: push(newString(unicode.alignLeft(x.s, y.i, padding=padding)))
                else: InPlace.s = unicode.alignLeft(InPlaced.s, y.i, padding=padding)
            elif (popAttr("center") != VNULL):
                if x.kind==String: push(newString(centerUnicode(x.s, y.i, padding=padding)))
                else: InPlace.s = centerUnicode(InPlaced.s, y.i, padding=padding)
            else:
                if x.kind==String: push(newString(unicode.align(x.s, y.i, padding=padding)))
                else: InPlace.s = unicode.align(InPlaced.s, y.i, padding=padding)

    builtin "prefix",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "add given prefix to string",
        args        = {
            "string": {String,Literal},
            "prefix": {String}
        },
        attrs       = NoAttrs,
        returns     = {String,Nothing},
        example     = """
            prefix "ello" "h"                  ; => "hello"
            
            str: "ello"
            prefix 'str                        ; str: "hello"
        """:
            ##########################################################
            if x.kind==String: push(newString(y.s & x.s))
            else: SetInPlace(newString(y.s & InPlace.s))

    builtin "prefix?",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "check if string starts with given prefix",
        args        = {
            "string": {String},
            "prefix": {String}
        },
        attrs       = {
            "regex" : ({Boolean},"match against a regular expression")
        },
        returns     = {Boolean},
        example     = """
            prefix? "hello" "he"          ; => true
            prefix? "boom" "he"           ; => false
        """:
            ##########################################################
            if (popAttr("regex") != VNULL):
                when not defined(WEB):
                    push(newBoolean(re.startsWith(x.s, re.re(y.s))))
            else:
                push(newBoolean(x.s.startsWith(y.s)))

    when not defined(WEB):
        builtin "render",
            alias       = tilde, 
            rule        = PrefixPrecedence,
            description = "render template with |string| interpolation",
            args        = {
                "template"  : {String}
            },
            attrs       = {
                "single"    : ({Boolean},"don't render recursively"),
                "template"  : ({Boolean},"render as a template")
            },
            returns     = {String,Nothing},
            example     = """
                x: 2
                greeting: "hello"
                print ~"|greeting|, your number is |x|"       ; hello, your number is 2
                
                data: #[
                    name: "John"
                    age: 34
                ]
                
                print render.with: data 
                    "Hello, your name is |name| and you are |age| years old"
                
                ; Hello, your name is John and you are 34 years old
            """:
                ##########################################################
                let recursive = not (popAttr("single") != VNULL)
                var res = ""
                if x.kind == Literal:
                    res = InPlace.s
                else:
                    res = x.s

                let Interpolated    = nre.re"\|([^\|]+)\|"
                let Embeddable      = re.re"(?s)(\<\|\|.*?\|\|\>)"

                if (popAttr("template") != VNULL):
                    var keepGoing = true
                    if recursive: 
                        keepGoing = res.contains(Embeddable)

                    while keepGoing:
                        var evaled: Translation

                        if templateStore.hasKey(res):
                            evaled = templateStore[res]
                        else:
                            let initial = res
                            # make necessary substitutions
                            res = "««" & res.replace("<||=","<|| to :string ").multiReplace(
                                ("||>","««"),
                                ("<||","»»")
                            ) & "»»"

                            # parse string template
                            evaled = doEval(doParse(res, isFile=false))
                            templateStore[initial] = evaled

                        # execute/reduce ('array') the resulting block
                        let stop = SP
                        discard execIsolated(evaled)
                        let arr: ValueArray = sTopsFrom(stop)
                        SP = stop

                        # and join the different strings
                        res = ""
                        for i, v in arr:
                            add(res, v.s)

                        # if recursive, check if there's still more embedded tags
                        # otherwise, break out of the loop
                        if recursive: keepGoing = res.contains(Embeddable)
                        else: keepGoing = false
                else:
                    var keepGoing = true
                    if recursive: 
                        keepGoing = res.find(Interpolated).isSome

                    while keepGoing:
                        res = res.replace(Interpolated, proc (match: RegexMatch): string =
                                    discard execBlock(doParse(match.captures[0], isFile=false))
                                    $(pop())
                                )

                        # if recursive, check if there's still more embedded tags
                        # otherwise, break out of the loop
                        if recursive: keepGoing = res.find(Interpolated).isSome
                        else: keepGoing = false

                if x.kind == Literal:
                    InPlaced = newString(res)
                else:
                    push(newString(res))

    builtin "replace",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "add given suffix to string",
        args        = {
            "string"        : {String,Literal},
            "match"         : {String},
            "replacement"   : {String}
        },
        attrs       = {
            "regex" : ({Boolean},"match against a regular expression")
        },
        returns     = {String,Nothing},
        example     = """
            replace "hello" "l" "x"           ; => "hexxo"
            
            str: "hello"
            replace 'str "l" "x"              ; str: "hexxo"
        """:
            ##########################################################
            if (popAttr("regex") != VNULL):
                when not defined(WEB):
                    if x.kind==String: push(newString(x.s.replacef(re.re(y.s), z.s)))
                    else: InPlace.s = InPlaced.s.replacef(re.re(y.s), z.s)
            else:
                if x.kind==String: push(newString(x.s.replace(y.s, z.s)))
                else: InPlace.s = InPlaced.s.replace(y.s, z.s)

    builtin "strip",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "strip whitespace from given string",
        args        = {
            "string": {String,Literal}
        },
        attrs       = {
            "start" : ({Boolean},"strip leading whitespace"),
            "end"   : ({Boolean},"strip trailing whitespace")
        },
        returns     = {String,Nothing},
        example     = """
            str: "     Hello World     "

            print ["strip all:"      ">" strip str       "<"]
            print ["strip leading:"  ">" strip.start str "<"]
            print ["strip trailing:" ">" strip.end str   "<"]

            ; strip all: > Hello World < 
            ; strip leading: > Hello World      < 
            ; strip trailing: >      Hello World <
        """:
            ##########################################################
            var leading = (popAttr("start")!=VNULL)
            var trailing = (popAttr("end")!=VNULL)

            if not leading and not trailing:
                leading = true
                trailing = true

            if x.kind==String: push(newString(strutils.strip(x.s, leading, trailing)))
            else: InPlace.s = strutils.strip(InPlaced.s, leading, trailing) 

    builtin "suffix",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "add given suffix to string",
        args        = {
            "string": {String,Literal},
            "suffix": {String}
        },
        attrs       = NoAttrs,
        returns     = {String,Nothing},
        example     = """
            suffix "hell" "o"                  ; => "hello"
            
            str: "hell"
            suffix 'str                        ; str: "hello"
        """:
            ##########################################################
            if x.kind==String: push(newString(x.s & y.s))
            else: SetInPlace(newString(InPlace.s & y.s))

    builtin "suffix?",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "check if string ends with given suffix",
        args        = {
            "string": {String},
            "suffix": {String}
        },
        attrs       = {
            "regex" : ({Boolean},"match against a regular expression")
        },
        returns     = {Boolean},
        example     = """
            suffix? "hello" "lo"          ; => true
            suffix? "boom" "lo"           ; => false
        """:
            ##########################################################
            if (popAttr("regex") != VNULL):
                when not defined(WEB):
                    push(newBoolean(re.endsWith(x.s, re.re(y.s))))
            else:
                push(newBoolean(x.s.endsWith(y.s)))

    builtin "truncate",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "truncate string at given length",
        args        = {
            "string": {String,Literal},
            "cutoff": {Integer}
        },
        attrs       = {
            "with"      : ({String},"use given filler"),
            "preserve"  : ({Boolean},"preserve word boundaries")
        },
        returns     = {String,Nothing},
        example     = """
            str: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Suspendisse erat quam"

            truncate str 30
            ; => "Lorem ipsum dolor sit amet, con..."

            truncate.preserve str 30
            ; => "Lorem ipsum dolor sit amet,..."

            truncate.with:"---" str 30
            ; => "Lorem ipsum dolor sit amet, con---"

            truncate.preserve.with:"---" str 30
            ; => "Lorem ipsum dolor sit amet,---"
        """: 
            ##########################################################
            var with = "..."
            if (let aWith = popAttr("with"); aWith != VNULL):
                with = aWith.s

            if (popAttr("preserve")!=VNULL):
                if x.kind==String: push(newString(truncatePreserving(x.s, y.i, with)))
                else: InPlace.s = truncatePreserving(InPlaced.s, y.i, with)
            else:
                if x.kind==String: push(newString(truncate(x.s, y.i, with)))
                else: InPlace.s = truncate(InPlaced.s, y.i, with)

    builtin "upper",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "convert given string to uppercase",
        args        = {
            "string": {String,Literal}
        },
        attrs       = NoAttrs,
        returns     = {String,Nothing},
        example     = """
            print upper "hello World, 你好!"       ; "HELLO WORLD, 你好!"
            
            str: "hello World, 你好!"
            upper 'str                           ; str: "HELLO WORLD, 你好!"
        """:
            ##########################################################
            if x.kind==String: push(newString(x.s.toUpper()))
            else: InPlace.s = InPlaced.s.toUpper()

    builtin "upper?",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "check if given string is uppercase",
        args        = {
            "string": {String}
        },
        attrs       = NoAttrs,
        returns     = {Boolean},
        example     = """
            upper? "Ñ"               ; => true
            upper? "x"               ; => false
            upper? "Hello World"     ; => false
            upper? "HELLO"           ; => true
        """:
            ##########################################################
            var broken = false
            for c in runes(x.s):
                if not c.isUpper():
                    push(VFALSE)
                    broken = true
                    break

            if not broken:
                push(VTRUE)

    builtin "whitespace?",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "check if given string consists only of whitespace",
        args        = {
            "string": {String}
        },
        attrs       = NoAttrs,
        returns     = {Boolean},
        example     = """
            whitespace? "hello"           ; => false
            whitespace? " "               ; => true
            whitespace? "\n \n"           ; => true
        """:
            ##########################################################
            push(newBoolean(x.s.isEmptyOrWhitespace()))

#=======================================
# Add Library
#=======================================

Libraries.add(defineSymbols)