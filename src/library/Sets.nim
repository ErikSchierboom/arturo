######################################################
# Arturo
# Programming Language + Bytecode VM compiler
# (c) 2019-2022 Yanis Zafirópulos
#
# @file: library/Sets.nim
######################################################

#=======================================
# Pragmas
#=======================================

{.used.}

#=======================================
# Libraries
#=======================================

import sequtils, std/sets, sugar

import helpers/arrays

import vm/lib

#=======================================
# Methods
#=======================================

proc defineSymbols*() =

    when defined(VERBOSE):
        echo "- Importing: Sets"

    # TODO(Sets) more potential built-in function candidates?
    #  we could also have functions/constants returning pre-defined sets, e.g. what `alphabet` does
    #  labels: library, enhancement, open discussion

    builtin "difference",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "return the difference of given sets",
        args        = {
            "setA"  : {Block,Literal},
            "setB"  : {Block}
        },
        attrs       = {
            "symmetric" : ({Logical},"get the symmetric difference")
        },
        returns     = {Block,Nothing},
        example     = """
            print difference [1 2 3 4] [3 4 5 6]
            ; 1 2
            ..........
            a: [1 2 3 4]
            b: [3 4 5 6]
            difference 'a b
            ; a: [1 2]
            ..........
            print difference.symmetric [1 2 3 4] [3 4 5 6]
            ; 1 2 5 6
        """:
            ##########################################################
            if (hadAttr("symmetric")):
                if x.kind==Literal:
                    SetInPlace(newBlock(toSeq(symmetricDifference(toHashSet(cleanedBlock(InPlace.a)), toHashSet(cleanedBlock(y.a))))))
                else:
                    push(newBlock(toSeq(symmetricDifference(toHashSet(cleanedBlock(x.a)), toHashSet(cleanedBlock(y.a))))))
            else:
                if x.kind==Literal:
                    SetInPlace(newBlock(toSeq(difference(toHashSet(cleanedBlock(InPlace.a)), toHashSet(cleanedBlock(y.a))))))
                else:
                    push(newBlock(toSeq(difference(toHashSet(cleanedBlock(x.a)), toHashSet(cleanedBlock(y.a))))))

    builtin "intersection",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "return the intersection of given sets",
        args        = {
            "setA"  : {Block,Literal},
            "setB"  : {Block}
        },
        attrs       = NoAttrs,
        returns     = {Block,Nothing},
        example     = """
            print intersection [1 2 3 4] [3 4 5 6]
            ; 3 4
            ..........
            a: [1 2 3 4]
            b: [3 4 5 6]
            intersection 'a b
            ; a: [3 4]
        """:
            ##########################################################
            if x.kind==Literal:
                SetInPlace(newBlock(toSeq(intersection(toHashSet(cleanedBlock(InPlace.a)), toHashSet(cleanedBlock(y.a))))))
            else:
                push(newBlock(toSeq(intersection(toHashSet(cleanedBlock(x.a)), toHashSet(cleanedBlock(y.a))))))

    builtin "powerset",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "return the powerset of given set",
        args        = {
            "set"   : {Block,Literal}
        },
        attrs       = NoAttrs,
        returns     = {Block,Nothing},
        example     = """
            powerset [1 2 3]
            ;  [[] [1] [2] [1 3] [3] [1 2] [2 3] [1 2 3]]
        """:
            ##########################################################
            if x.kind==Literal:
                SetInPlace(newBlock(toSeq(powerset(toHashSet(cleanedBlock(InPlace.a)))).map((hs) => newBlock(toSeq(hs)))))
            else:
                push(newBlock(toSeq(powerset(toHashSet(cleanedBlock(x.a))).map((hs) => newBlock(toSeq(hs))))))

    builtin "subset?",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "check if given set is a subset of second set",
        args        = {
            "setA"  : {Block},
            "setB"  : {Block}
        },
        attrs       = {
            "proper": ({Logical},"check if proper subset")
        },
        returns     = {Logical},
        example     = """
            subset? [1 3] [1 2 3 4]
            ; => true

            subset?.proper [1 3] [1 2 3 4]
            ; => true

            subset? [1 3] [3 5 6]
            ; => false

            subset? [1 3] [1 3]
            ; => true

            subset?.proper [1 3] [1 3]
            ; => false
        """:
            ##########################################################
            if (hadAttr("proper")):
                if x == y: 
                    push(newLogical(false))
                else:
                    var contains = true
                    let xblk = cleanedBlock(x.a)
                    let yblk = cleanedBlock(y.a)
                    for item in xblk:
                        if item notin yblk:
                            contains = false
                            break

                    push(newLogical(contains))
            else:
                if x == y:
                    push(VTRUE)
                else:
                    var contains = true
                    let xblk = cleanedBlock(x.a)
                    let yblk = cleanedBlock(y.a)
                    for item in xblk:
                        if item notin yblk:
                            contains = false
                            break

                    push(newLogical(contains))

    builtin "superset?",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "check if given set is a superset of second set",
        args        = {
            "setA"  : {Block},
            "setB"  : {Block}
        },
        attrs       = {
            "proper": ({Logical},"check if proper superset")
        },
        returns     = {Logical},
        example     = """
            superset? [1 2 3 4] [1 3]
            ; => true

            superset?.proper [1 2 3 4] [1 3]
            ; => true

            superset? [3 5 6] [1 3]
            ; => false

            superset? [1 3] [1 3]
            ; => true

            superset?.proper [1 3] [1 3]
            ; => false
        """:
            ##########################################################
            if (hadAttr("proper")):
                if x == y: 
                    push(newLogical(false))
                else:
                    var contains = true
                    let xblk = cleanedBlock(x.a)
                    let yblk = cleanedBlock(y.a)
                    for item in yblk:
                        if item notin xblk:
                            contains = false
                            break

                    push(newLogical(contains))
            else:
                if x == y:
                    push(VTRUE)
                else:
                    var contains = true
                    let xblk = cleanedBlock(x.a)
                    let yblk = cleanedBlock(y.a)
                    for item in yblk:
                        if item notin xblk:
                            contains = false
                            break

                    push(newLogical(contains))

    builtin "union",
        alias       = unaliased, 
        rule        = PrefixPrecedence,
        description = "return the union of given sets",
        args        = {
            "setA"  : {Block,Literal},
            "setB"  : {Block}
        },
        attrs       = NoAttrs,
        returns     = {Block,Nothing},
        example     = """
            print union [1 2 3 4] [3 4 5 6]
            ; 1 2 3 4 5 6
            ..........
            a: [1 2 3 4]
            b: [3 4 5 6]
            union 'a b
            ; a: [1 2 3 4 5 6]
        """:
            ##########################################################
            if x.kind==Literal:
                SetInPlace(newBlock(toSeq(union(toHashSet(cleanedBlock(InPlace.a)), toHashSet(cleanedBlock(y.a))))))
            else:
                push(newBlock(toSeq(union(toHashSet(cleanedBlock(x.a)), toHashSet(cleanedBlock(y.a))))))

#=======================================
# Add Library
#=======================================

Libraries.add(defineSymbols)