######################################################
# Arturo
# Programming Language + Bytecode VM compiler
# (c) 2019-2021 Yanis Zafirópulos
#
# @file: helpers/json.nim
######################################################

#=======================================
# Libraries
#=======================================

import std/json, sequtils, sugar
import tables, unicode

when defined(WEB):
    import jsffi, strutils

import vm/values/[printable, value]

#=======================================
# Helpers
#=======================================

proc generateJsonNode*(n: Value): JsonNode =
    case n.kind
        of Null         : result = newJNull()
        of Boolean      : result = newJBool(n.b)
        of Integer      : result = newJInt(n.i)
        of Floating     : result = newJFloat(n.f)
        of Version      : result = newJString($(n))
        of Type         : result = newJString($(n.t))
        of Char         : result = newJString($(n.c))
        of String,
           Word,
           Literal,
           Label        : result = newJString(n.s)
        of Attribute,
           AttributeLabel: result = newJString(n.r)
        of Path,
           PathLabel    : 
           result = newJArray()
           for v in n.p:
                result.add(generateJsonNode(v))
        of Symbol       : result = newJString($(n.m))
        of Date         : discard
        of Binary       : discard
        of Inline,
           Block        : 
           result = newJArray()
           for v in n.a:
                result.add(generateJsonNode(v))
        of Dictionary   :
            result = newJObject()
            for k,v in pairs(n.d):
                result.add(k, generateJsonNode(v))

        of Function,
           Database,
           Bytecode,
           Nothing,
           Any          : discard

proc parseJsonNode*(n: JsonNode): Value =

    case n.kind
        of JString  : result = newString(n.str)
        of JInt     : result = newInteger(int(n.num))
        of JFloat   : result = newFloating(n.fnum)
        of JBool    : result = newBoolean(n.bval)
        of JNull    : result = VNULL
        of JArray   : result = newBlock(n.elems.map((x) => parseJsonNode(x)))
        of JObject  : 
            var ret: ValueDict = initOrderedTable[string,Value]()
            for k,v in n.fields:
                ret[k] = parseJsonNode(v)

            result = newDictionary(ret)

when defined(WEB):

    proc generateJsObject*(n: Value): JsObject =
        case n.kind
            of Null         : result = toJs(nil)
            of Boolean      : result = toJs(n.b)
            of Integer      : result = toJs(n.i)
            of Floating     : result = toJs(n.f)
            of Version      : result = toJs($(n))
            of Type         : result = toJs($(n.t))
            of Char         : result = toJs($(n.c))
            of String,
               Word,
               Literal,
               Label        : result = toJs(n.s)
            of Attribute,
               AttributeLabel: result = toJs(n.r)
            of Path,
               PathLabel    : 
                var ret: seq[JsObject] = @[]
                for v in n.p:
                    ret.add(generateJsObject(v))
                result = toJs(ret)
            of Symbol       : result = toJs($(n.m))
            of Date         : discard
            of Binary       : discard
            of Inline,
               Block        : 
                var ret: seq[JsObject] = @[]
                for v in n.a:
                    ret.add(generateJsObject(v))
                result = toJs(ret)
            of Dictionary   :
                result = newJsObject()
                for k,v in pairs(n.d):
                    result[k] = generateJsObject(v)
            of Function,
               Database,
               Bytecode,
               Nothing,
               Any          : discard

    proc isArray(x: JsObject): bool {.noSideEffect, importcpp: "(Array.isArray(#))".}
    proc jsonified(x: JsObject): cstring {.noSideEffect, importcpp: "(JSON.stringify(#))".}

    proc parseJsObject*(n: JsObject): Value =
        if n.isNull() or n.isUndefined(): return VNULL
        case $(jsTypeOf(n)):
            of "boolean"    : result = newBoolean($(jsonified(n)))
            of "number"     : 
                let got = $(jsonified(n))
                if got.contains("."):
                    result = newFloating(got)
                else:
                    result = newInteger(got)
            of "string"     : result = newString($(jsonified(n)))
            of "object"     :
                if isArray(n):
                    var ret: ValueArray = @[]
                    for item in items(n):
                        ret.add(parseJsObject(item))
                    result = newBlock(ret)
                else:
                    var ret: ValueDict = initOrderedTable[string,Value]()
                    for key,value in pairs(n):
                        ret[$(key)] = parseJsObject(value)
                    result = newDictionary(ret)

            else            : result = VNULL

#=======================================
# Methods
#=======================================

proc valueFromJson*(src: string): Value =
    parseJsonNode(parseJson(src))

proc jsonFromValue*(val: Value, pretty: bool = true): string =
    let node = generateJsonNode(val)
    if pretty: json.pretty(node, indent=4)
    else: $(node)