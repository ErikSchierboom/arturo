#=======================================================
# Arturo
# Programming Language + Bytecode VM compiler
# (c) 2019-2023 Yanis Zafirópulos
#
# @file: vm/values/operators.nim
#=======================================================

## Arithmetic & logical operators for Value objects.

#=======================================
# Libraries
#=======================================

import lenientops, macros, math, strutils

when defined(WEB):
    import std/jsbigints

when not defined(NOGMP):
    import helpers/bignums as BignumsHelper

import helpers/intrinsics

import vm/errors

import vm/values/types
import vm/values/value
import vm/values/printable

import vm/values/custom/[vbinary, vcolor, vcomplex, vlogical, vquantity, vrange, vrational, vversion]

#=======================================
# Constants
#=======================================

const
    GMP = not defined(NOGMP)

#=======================================
# Pragmas
#=======================================

#{.push overflowChecks: on.}

#=======================================
# Forward declarations
#=======================================

proc `+`*(x: Value, y: Value): Value
proc `-`*(x: Value, y: Value): Value
proc `*`*(x: Value, y: Value): Value
proc `/`*(x: Value, y: Value): Value
proc `//`*(x: Value, y: Value): Value

#=======================================
# Macros
#=======================================

macro generateOperationA*(name: static[string], op: untyped, inplaceOp: untyped): untyped =
    ## generates the code necessary for arithmetic operations
    ## that only require one operand, e.g. `inc`
    let normalInteger =  ident("normalInteger" & ($name).capitalizeAscii())
    let normalIntegerI = ident("normalInteger" & ($name).capitalizeAscii() & "I")

    result = quote do:
        if xKind==Literal : 
            ensureInPlace()
            if normalIntegerOperation(inPlace=true):
                `normalIntegerI`(InPlaced)
            else:
                `inplaceOp`(InPlaced)
        elif normalIntegerOperation():
            push(`normalInteger`(x.i))
        else:
            push(`op`(x))

macro generateOperationB*(name: static[string], op: untyped, inplaceOp: untyped): untyped =
    ## generates the code necessary for arithmetic operations
    ## that require two operands, e.g. `add`
    let normalInteger =  ident("normalInteger" & ($name).capitalizeAscii())
    let normalIntegerI = ident("normalInteger" & ($name).capitalizeAscii() & "I")

    result = quote do:
        if xKind==Literal : 
            ensureInPlace()
            if normalIntegerOperation(inPlace=true):
                `normalIntegerI`(InPlaced, y.i)
            else:
                `inplaceOp`(InPlaced, y)
        elif normalIntegerOperation():
            push(`normalInteger`(x.i, y.i))
        else:
            push(`op`(x,y))

#=======================================
# Helpers
#=======================================

template toBig(v: untyped): untyped =
    when defined(WEB):
        big(v)
    else:
        v

template toNewBig(v: untyped): untyped =
    when defined(WEB):
        big(v)
    else:
        newInt(v)

template notZero(v: untyped): untyped =
    when v is VRational:
        if unlikely(isZero(v)):
            RuntimeError_DivisionByZero()
    elif v is VComplex:
        if unlikely(v.re==0 and v.im==0):
            RuntimeError_DivisionByZero()
    else:
        if unlikely(v==0):
            RuntimeError_DivisionByZero()
    v

proc invalidOperation(op: string, x: Value, y: Value = nil): Value =
    when not defined(WEB):
        if y.isNil:
            RuntimeError_InvalidOperation(op, valueKind(x, withBigInfo=true), "")
        else:
            RuntimeError_InvalidOperation(op, valueKind(x, withBigInfo=true), valueKind(y, withBigInfo=true))
    VNULL

template invalidOperation(op: string): untyped =
    when declared(y):
        invalidOperation(op, x, y)
    else:
        invalidOperation(op, x)

#=======================================
# Templates
#=======================================

template normalIntegerOperation*(inPlace=false): bool =
    ## check if both operands (x,y) are Integers, but not GMP-style BigNums
    when inPlace:
        let xKind {.inject.} = InPlaced.kind
        when declared(y):
            let yKind {.inject.} = y.kind
    else:
        when not declared(xKind):
            let xKind {.inject.} = x.kind
            when declared(y):
                let yKind {.inject.} = y.kind

    when inPlace:
        when declared(y):
            likely(xKind==Integer) and likely(InPlaced.iKind==NormalInteger) and likely(yKind==Integer) and likely(y.iKind==NormalInteger)
        else:
            likely(xKind==Integer) and likely(InPlaced.iKind==NormalInteger)
    else:
        when declared(y):
            likely(xKind==Integer) and likely(x.iKind==NormalInteger) and likely(yKind==Integer) and likely(y.iKind==NormalInteger)
        else:
            likely(xKind==Integer) and likely(x.iKind==NormalInteger)

template normalIntegerAdd*(x, y: int): untyped =
    ## add two normal Integer values, checking for overflow
    ## and return result
    var res: int
    if unlikely(addIntWithOverflow(x, y, res)):
        when not defined(NOGMP):
            newInteger(toNewBig(x) + toBig(y))
        else:
            RuntimeError_IntegerOperationOverflow("add", $x, $y)
            VNULL
    else:
        newInteger(res)

template normalIntegerAddI*(x: var Value, y: int): untyped =
    ## add two normal Integer values, checking for overflow
    ## and set result in-place
    if unlikely(addIntWithOverflow(x.i, y, x.i)):
        when not defined(NOGMP):
            x = newInteger(toNewBig(x.i) + toBig(y))
        else:
            RuntimeError_IntegerOperationOverflow("add", $x.i, $y)

template normalIntegerInc*(x: int): untyped =
    ## increment a normal Integer value by 1, checking for overflow
    ## and return result
    var res: int
    if unlikely(addIntWithOverflow(x, 1, res)):
        when not defined(NOGMP):
            newInteger(toNewBig(x) + toBig(1))
        else:
            RuntimeError_IntegerOperationOverflow("inc", $x, "")
            VNULL
    else:
        newInteger(res)

template normalIntegerIncI*(x: var Value): untyped =
    ## increment a normal Integer value by 1, checking for overflow
    ## and set result in-place
    if unlikely(addIntWithOverflow(x.i, 1, x.i)):
        when not defined(NOGMP):
            x = newInteger(toNewBig(x.i) + toBig(1))
        else:
            RuntimeError_IntegerOperationOverflow("inc", $x.i, "")

template normalIntegerSub*(x, y: int): untyped =
    ## subtract two normal Integer values, checking for overflow
    ## and return result
    var res: int
    if unlikely(subIntWithOverflow(x, y, res)):
        when not defined(NOGMP):
            newInteger(toNewBig(x) - toBig(y))
        else:
            RuntimeError_IntegerOperationOverflow("sub", $x, $y)
            VNULL
    else:
        newInteger(res)

template normalIntegerSubI*(x: var Value, y: int): untyped =
    ## subtract two normal Integer values, checking for overflow
    ## and set result in-place
    if unlikely(subIntWithOverflow(x.i, y, x.i)):
        when not defined(NOGMP):
            x = newInteger(toNewBig(x.i) - toBig(y))
        else:
            RuntimeError_IntegerOperationOverflow("sub", $x.i, $y)

template normalIntegerDec*(x: int): untyped =
    ## decrement a normal Integer value by 1, checking for overflow
    ## and return result
    var res: int
    if unlikely(subIntWithOverflow(x, 1, res)):
        when not defined(NOGMP):
            newInteger(toNewBig(x) - toBig(1))
        else:
            RuntimeError_IntegerOperationOverflow("dec", $x, "")
            VNULL
    else:
        newInteger(res)

template normalIntegerDecI*(x: var Value): untyped =
    ## decrement a normal Integer value by 1, checking for overflow
    ## and set result in-place
    if unlikely(subIntWithOverflow(x.i, 1, x.i)):
        when not defined(NOGMP):
            x = newInteger(toNewBig(x.i) - toBig(1))
        else:
            RuntimeError_IntegerOperationOverflow("dec", $x.i, "")

template normalIntegerMul*(x, y: int): untyped =
    ## multiply two normal Integer values, checking for overflow
    ## and return result
    var res: int
    if unlikely(mulIntWithOverflow(x, y, res)):
        when not defined(NOGMP):
            newInteger(toNewBig(x) * toBig(y))
        else:
            RuntimeError_IntegerOperationOverflow("mul", $x, $y)
            VNULL
    else:
        newInteger(res)

template normalIntegerMulI*(x: var Value, y: int): untyped =
    ## multiply two normal Integer values, checking for overflow
    ## and set result in-place
    if unlikely(mulIntWithOverflow(x.i, y, x.i)):
        when not defined(NOGMP):
            x = newInteger(toNewBig(x.i) * toBig(y))
        else:
            RuntimeError_IntegerOperationOverflow("mul", $x.i, $y)

template normalIntegerNeg*(x: int): untyped =
    ## negate a normal Integer value, checking for overflow
    ## and return result
    var res: int
    if unlikely(mulIntWithOverflow(x, -1, res)):
        when not defined(NOGMP):
            newInteger(toNewBig(x) * toBig(-1))
        else:
            RuntimeError_IntegerOperationOverflow("neg", $x, "")
            VNULL
    else:
        newInteger(res)

template normalIntegerNegI*(x: var Value): untyped =
    ## negate a normal Integer value, checking for overflow
    ## and set result in-place
    if unlikely(mulIntWithOverflow(x.i, -1, x.i)):
        when not defined(NOGMP):
            x = newInteger(toNewBig(x.i) + toBig(-1))
        else:
            RuntimeError_IntegerOperationOverflow("neg", $x.i, "")

template normalIntegerDiv*(x, y: int): untyped =
    ## divide (integer division) two normal Integer values, checking for DivisionByZero
    ## and return result
    newInteger(x div notZero(y))

template normalIntegerDivI*(x: var Value, y: int): untyped =
    ## divide (integer division) two normal Integer values, checking for DivisionByZero
    ## and set result in-place
    x = newInteger(x.i div notZero(y))

template normalIntegerFDiv*(x, y: int): untyped =
    ## divide (floating-point division) two normal Integer values, checking for DivisionByZero
    ## and return result
    newFloating(x / notZero(y))

template normalIntegerFDivI*(x: var Value, y: int): untyped =
    ## divide (floating-point division) two normal Integer values, checking for DivisionByZero
    ## and set result in-place
    x = newFloating(x.i / notZero(y))

template normalIntegerMod*(x, y: int): untyped =
    ## modulo two normal Integer values, checking for DivisionByZero
    ## and return result
    newInteger(x mod notZero(y))

template normalIntegerModI*(x: var Value, y: int): untyped =
    ## divide (floating-point division) two normal Integer values, checking for DivisionByZero
    ## and set result in-place
    x = newInteger(x.i mod notZero(y))

template normalIntegerDivMod*(x, y: int): untyped =
    ## divide+modulo (integer division) two normal Integer values, checking for DivisionByZero
    ## and return result
    let dm = divmod(x, notZero(y))
    newBlock(@[newInteger(dm[0]), newInteger(dm[1])])

template normalIntegerDivModI*(x: var Value, y: int): untyped =
    ## divide+modulo (integer division) two normal Integer values, checking for DivisionByZero
    ## and set result in-place
    let dm = divmod(x.i, notZero(y))
    x = newBlock(@[newInteger(dm[0]), newInteger(dm[1])])

template normalIntegerPow*(x, y: int): untyped =
    ## get the power of two normal Integer values, checking for overflow
    ## and return result
    if likely(y >= 0):
        var res: int
        if unlikely(powIntWithOverflow(x, y, res)):
            when not defined(NOGMP):
                when defined(WEB):
                    newInteger(big(x) ** big(y))
                else:
                    newInteger(pow(x, culong(y)))
            else:
                RuntimeError_IntegerOperationOverflow("pow", $x, $y)
                VNULL
        else:
            newInteger(res)
    else:
        newFloating(pow(float(x), float(y)))

template normalIntegerPowI*(x: var Value, y: int): untyped =
    ## get the power of two normal Integer values, checking for overflow
    ## and set result in-place
    if likely(y >= 0):
        if unlikely(powIntWithOverflow(x.i, y, x.i)):
            when not defined(NOGMP):
                when defined(WEB):
                    x = newInteger(big(x.i) ** big(y))
                else:
                    x = newInteger(pow(x.i, culong(y)))
            else:
                RuntimeError_IntegerOperationOverflow("pow", $x.i, $y)
    else:
        x = newFloating(pow(float(x.i), float(y)))

template normalIntegerAnd*(x, y: int): untyped =
    ## bitwise AND two normal Integer values
    ## and return result
    newInteger(x and y)

template normalIntegerAndI*(x: var Value, y: int): untyped =
    ## bitwise AND two normal Integer values
    ## and set result in-place
    x.i = x.i and y

template normalIntegerOr*(x, y: int): untyped =
    ## bitwise OR two normal Integer values
    ## and return result
    newInteger(x or y)

template normalIntegerOrI*(x: var Value, y: int): untyped =
    ## bitwise OR two normal Integer values
    ## and set result in-place
    x.i = x.i or y

template normalIntegerXor*(x, y: int): untyped =
    ## bitwise XOR two normal Integer values
    ## and return result
    newInteger(x xor y)

template normalIntegerXorI*(x: var Value, y: int): untyped =
    ## bitwise XOR two normal Integer values
    ## and set result in-place
    x.i = x.i xor y

template normalIntegerNot*(x: int): untyped =
    ## bitwise NOT of a normal Integer value
    ## and return result
    newInteger(not x)

template normalIntegerNotI*(x: var Value): untyped =
    ## bitwise NOT of a normal Integer value
    ## and set result in-place
    x.i = not x.i

template normalIntegerShl*(x, y: int): untyped =
    ## bitwise shift-left two normal Integer values
    ## and return result
    newInteger(x shl y)

template normalIntegerShlI*(x: var Value, y: int): untyped =
    ## bitwise shift-left two normal Integer values
    ## and set result in-place
    x.i = x.i shl y

template normalIntegerShr*(x, y: int): untyped =
    ## bitwise shift-right two normal Integer values
    ## and return result
    newInteger(x shr y)

template normalIntegerShrI*(x: var Value, y: int): untyped =
    ## bitwise shift-right two normal Integer values
    ## and set result in-place
    x.i = x.i shr y

#=======================================
# Methods
#=======================================

# proc convertToTemperatureUnit*(v: Value, src: UnitName, tgt: UnitName): Value =
#     ## convert given temperature value ``v`` from ``src`` unit to ``tgt``
#     case src:
#         of C:
#             if tgt==F: return v * newFloating(9/5) + newInteger(32)
#             elif tgt==K: return v + newFloating(273.15)
#             else: return v * newFloating(9/5) + newFloating(491.67)
#         of F:
#             if tgt==C: return (v - newInteger(32)) * newFloating(5/9)
#             elif tgt==K: return (v - newInteger(32)) * newFloating(5/9) + newFloating(273.15)
#             else: return v + newFloating(459.67)
#         of K: 
#             if tgt==C: return v - newFloating(273.15)
#             elif tgt==F: return (v-newFloating(273.15)) * newFloating(9/5) + newInteger(32)
#             else: return v * newFloating(1.8)
#         of R:
#             if tgt==C: return (v - newFloating(491.67)) * newFloating(5/9)
#             elif tgt==F: return v - newFloating(459.67)
#             else: return v * newFloating(5/9)

#         else: discard

# proc convertQuantityValue*(nm: Value, fromU: UnitName, toU: UnitName, fromKind = NoUnit, toKind = NoUnit, op = ""): Value =
#     ## convert given quantity value ``nm`` from ``fromU`` unit to ``toU`` 
#     var fromK = fromKind
#     var toK = toKind
#     if fromK==NoUnit: fromK = quantityKindForName(fromU)
#     if toK==NoUnit: toK = quantityKindForName(toU)

#     if unlikely(fromK!=toK):
#         when not defined(WEB):
#             RuntimeError_CannotConvertQuantity($(nm), stringify(fromU), stringify(fromK), stringify(toU), stringify(toK))
    
#     if toK == TemperatureUnit:
#         return convertToTemperatureUnit(nm, fromU, toU)
#     else:
#         let fmultiplier = getQuantityMultiplier(fromU, toU, isCurrency=fromK==CurrencyUnit)
#         if fmultiplier == 1.0:
#             return nm
#         else:
#             return nm * newFloating(fmultiplier)

#=======================================
# Overloads
#=======================================

proc `+`*(x: Value, y: Value): Value =
    ## add given values and return the result

    let pair = getValuePair()
    case pair:
        of Integer    || Integer        :   return normalIntegerAdd(x.i, y.i)
        of Integer    || BigInteger     :   (when GMP: return newInteger(toBig(x.i) + y.bi))
        of BigInteger || Integer        :   (when GMP: return newInteger(x.bi + toBig(y.i)))
        of BigInteger || BigInteger     :   (when GMP: return newInteger(x.bi + y.bi))
        of Integer    || Floating       :   return newFloating(x.i + y.f)
        of BigInteger || Floating       :   (when GMP: return newFloating(x.bi + y.f))
        of Integer    || Rational       :   return newRational(x.i + y.rat)
        of BigInteger || Rational       :   (when GMP: return newRational(x.bi + y.rat))
        of Integer    || Complex        :   return newComplex(float(x.i) + y.z)

        of Floating   || Integer        :   return newFloating(x.f + float(y.i))
        of Floating   || BigInteger     :   (when GMP: return newFloating(x.f + y.bi))
        of Floating   || Floating       :   return newFloating(x.f + y.f)
        of Floating   || Rational       :   return newRational(toRational(x.f) + y.rat)
        of Floating   || Complex        :   return newComplex(x.f + y.z)

        of Rational   || Integer        :   return newRational(x.rat + y.i)
        of Rational   || BigInteger     :   (when GMP: return newRational(x.rat + y.bi))
        of Rational   || Floating       :   return newRational(x.rat + toRational(y.f))
        of Rational   || Rational       :   return newRational(x.rat + y.rat)

        of Complex    || Integer        :   return newComplex(x.z + float(y.i))
        of Complex    || Floating       :   return newComplex(x.z + y.f)
        of Complex    || Rational       :   return newComplex(x.z + toFloat(y.rat))
        of Complex    || Complex        :   return newComplex(x.z + y.z)
        
        of Color      || Color          :   return newColor(x.l + y.l)
        of Quantity   || Integer        :   return newQuantity(x.q + y.i)
        of Quantity   || BigInteger     :   (when GMP: return newQuantity(x.q + y.bi))
        of Quantity   || Floating       :   return newQuantity(x.q + y.f)
        of Quantity   || Rational       :   return newQuantity(x.q + y.rat)
        of Quantity   || Quantity       :   return newQuantity(x.q + y.q)
        else:
            return invalidOperation("add")

proc `+=`*(x: var Value, y: Value) =
    ## add given values
    ## and store the result in the first value
    ## 
    ## **Hint:** In-place, mutating operation

    let pair = getValuePair()
    case pair:
        of Integer    || Integer        :   normalIntegerAddI(x, y.i)
        of Integer    || BigInteger     :   (when GMP: x = newInteger(toBig(x.i) + y.bi))
        of BigInteger || Integer        :   (when GMP: x.bi += toBig(y.i))
        of BigInteger || BigInteger     :   (when GMP: x.bi += y.bi)
        of Integer    || Floating       :   x = newFloating(x.i + y.f)
        of BigInteger || Floating       :   (when GMP: x = newFloating(x.bi + y.f))
        of Integer    || Rational       :   x = newRational(x.i + y.rat)
        of BigInteger || Rational       :   (when GMP: x = newRational(x.bi + y.rat))
        of Integer    || Complex        :   x = newComplex(float(x.i) + y.z)

        of Floating   || Integer        :   x.f += float(y.i)
        of Floating   || BigInteger     :   (when GMP: x = newFloating(x.f + y.bi))
        of Floating   || Floating       :   x.f += y.f
        of Floating   || Rational       :   x = newRational(toRational(x.f) + y.rat)
        of Floating   || Complex        :   x = newComplex(x.f + y.z)

        of Rational   || Integer        :   x.rat += y.i
        of Rational   || BigInteger     :   (when GMP: x.rat += y.bi)
        of Rational   || Floating       :   x.rat += toRational(y.f)
        of Rational   || Rational       :   x.rat += y.rat

        of Complex    || Integer        :   x.z += float(y.i)
        of Complex    || Floating       :   x.z += y.f
        of Complex    || Rational       :   x.z += toFloat(y.rat)
        of Complex    || Complex        :   x.z += y.z
        
        of Color      || Color          :   x.l += y.l
        of Quantity   || Integer        :   x.q += y.i
        of Quantity   || BigInteger     :   (when GMP: x.q += y.bi)
        of Quantity   || Floating       :   x.q += y.f
        of Quantity   || Rational       :   x.q += y.rat
        of Quantity   || Quantity       :   x.q += y.q
        else:
            discard invalidOperation("add")

proc inc*(x: Value): Value =
    ## increment given value and return the result

    case x.kind:
        of Integer:
            if x.iKind==NormalInteger: return normalIntegerInc(x.i)
            else: (when GMP: return newInteger(x.bi+toBig(1)))
        of Floating: return newFloating(x.f+1.0)
        of Rational: return newRational(x.rat+1)
        of Complex: return newComplex(x.z+1.0)
        of Quantity: return newQuantity(x.q + 1)
        else:
            return invalidOperation("inc")

proc incI*(x: var Value) =
    ## increment given value
    ## and store back the result
    ## 
    ## **Hint:** In-place, mutating operation

    case x.kind:
        of Integer:
            if x.iKind==NormalInteger: normalIntegerIncI(x)
            else: (when GMP: inc(x.bi, 1))
        of Floating: x.f += 1.0
        of Rational: x.rat += 1
        of Complex: x.z = x.z + 1.0
        of Quantity: x.q += 1
        else:
            discard invalidOperation("inc")

proc `-`*(x: Value, y: Value): Value = 
    ## subtract given values and return the result

    let pair = getValuePair()
    case pair:
        of Integer    || Integer        :   return normalIntegerSub(x.i, y.i)
        of Integer    || BigInteger     :   (when GMP: return newInteger(toBig(x.i) - y.bi))
        of BigInteger || Integer        :   (when GMP: return newInteger(x.bi - toBig(y.i)))
        of BigInteger || BigInteger     :   (when GMP: return newInteger(x.bi - y.bi))
        of Integer    || Floating       :   return newFloating(x.i - y.f)
        of BigInteger || Floating       :   (when GMP: return newFloating(x.bi - y.f))
        of Integer    || Rational       :   return newRational(x.i - y.rat)
        of BigInteger || Rational       :   (when GMP: return newRational(x.bi - y.rat))
        of Integer    || Complex        :   return newComplex(float(x.i) - y.z)

        of Floating   || Integer        :   return newFloating(x.f - float(y.i))
        of Floating   || BigInteger     :   (when GMP: return newFloating(x.f - y.bi))
        of Floating   || Floating       :   return newFloating(x.f - y.f)
        of Floating   || Rational       :   return newRational(toRational(x.f) - y.rat)
        of Floating   || Complex        :   return newComplex(x.f - y.z)

        of Rational   || Integer        :   return newRational(x.rat - y.i)
        of Rational   || BigInteger     :   (when GMP: return newRational(x.rat - y.bi))
        of Rational   || Floating       :   return newRational(x.rat - toRational(y.f))
        of Rational   || Rational       :   return newRational(x.rat - y.rat)

        of Complex    || Integer        :   return newComplex(x.z - float(y.i))
        of Complex    || Floating       :   return newComplex(x.z - y.f)
        of Complex    || Rational       :   return newComplex(x.z - toFloat(y.rat))
        of Complex    || Complex        :   return newComplex(x.z - y.z)
        
        of Color      || Color          :   return newColor(x.l - y.l)
        of Quantity   || Integer        :   return newQuantity(x.q - y.i)
        of Quantity   || BigInteger     :   (when GMP: return newQuantity(x.q - y.bi))
        of Quantity   || Floating       :   return newQuantity(x.q - y.f)
        of Quantity   || Rational       :   return newQuantity(x.q - y.rat)
        of Quantity   || Quantity       :   return newQuantity(x.q - y.q)
        else:
            return invalidOperation("sub")

proc `-=`*(x: var Value, y: Value) = 
    ## subtract given values
    ## and store the result in the first value
    ## 
    ## **Hint:** In-place, mutating operation

    let pair = getValuePair()
    case pair:
        of Integer    || Integer        :   normalIntegerSubI(x, y.i)
        of Integer    || BigInteger     :   (when GMP: x = newInteger(toBig(x.i) - y.bi))
        of BigInteger || Integer        :   (when GMP: x.bi -= toBig(y.i))
        of BigInteger || BigInteger     :   (when GMP: x.bi -= y.bi)
        of Integer    || Floating       :   x = newFloating(x.i - y.f)
        of BigInteger || Floating       :   (when GMP: x = newFloating(x.bi - y.f))
        of Integer    || Rational       :   x = newRational(x.i - y.rat)
        of BigInteger || Rational       :   (when GMP: x = newRational(x.bi - y.rat))
        of Integer    || Complex        :   x = newComplex(float(x.i) - y.z)

        of Floating   || Integer        :   x.f -= float(y.i)
        of Floating   || BigInteger     :   (when GMP: x = newFloating(x.f - y.bi))
        of Floating   || Floating       :   x.f -= y.f
        of Floating   || Rational       :   x = newRational(toRational(x.f) - y.rat)
        of Floating   || Complex        :   x = newComplex(x.f - y.z)

        of Rational   || Integer        :   x.rat -= y.i
        of Rational   || BigInteger     :   (when GMP: x.rat -= y.bi)
        of Rational   || Floating       :   x.rat -= toRational(y.f)
        of Rational   || Rational       :   x.rat -= y.rat

        of Complex    || Integer        :   x.z -= float(y.i)
        of Complex    || Floating       :   x.z -= y.f
        of Complex    || Rational       :   x.z -= toFloat(y.rat)
        of Complex    || Complex        :   x.z -= y.z
        
        of Color      || Color          :   x.l -= y.l
        of Quantity   || Integer        :   x.q -= y.i
        of Quantity   || BigInteger     :   (when GMP: x.q -= y.bi)
        of Quantity   || Floating       :   x.q -= y.f
        of Quantity   || Rational       :   x.q -= y.rat
        of Quantity   || Quantity       :   x.q -= y.q
        else:
            discard invalidOperation("sub")

proc dec*(x: Value): Value =
    ## decrement given value and return the result

    case x.kind:
        of Integer:
            if x.iKind==NormalInteger: return normalIntegerDec(x.i)
            else: (when GMP: return newInteger(x.bi-toBig(1)))
        of Floating: return newFloating(x.f-1.0)
        of Rational: return newRational(x.rat-1)
        of Complex: return newComplex(x.z-1.0)
        of Quantity: return newQuantity(x.q - 1)
        else:
            return invalidOperation("dec")

proc decI*(x: var Value) =
    ## increment given value
    ## and store back the result
    ## 
    ## **Hint:** In-place, mutating operation

    case x.kind:
        of Integer:
            if x.iKind==NormalInteger: normalIntegerDecI(x)
            else: (when GMP: dec(x.bi, 1))
        of Floating: x.f -= 1.0
        of Rational: x.rat -= 1
        of Complex: x.z = x.z - 1.0
        of Quantity: x.q -= 1
        else:
            discard invalidOperation("dec")

proc `*`*(x: Value, y: Value): Value =
    ## multiply given values and return the result
    
    let pair = getValuePair()
    case pair:
        of Integer    || Integer        :   return normalIntegerMul(x.i, y.i)
        of Integer    || BigInteger     :   (when GMP: return newInteger(toBig(x.i) * y.bi))
        of BigInteger || Integer        :   (when GMP: return newInteger(x.bi * toBig(y.i)))
        of BigInteger || BigInteger     :   (when GMP: return newInteger(x.bi * y.bi))
        of Integer    || Floating       :   return newFloating(x.i * y.f)
        of BigInteger || Floating       :   (when GMP: return newFloating(x.bi * y.f))
        of Integer    || Rational       :   return newRational(x.i * y.rat)
        of BigInteger || Rational       :   (when GMP: return newRational(x.bi * y.rat))
        of Integer    || Complex        :   return newComplex(float(x.i) * y.z)
        of Integer    || Quantity       :   return newQuantity(x.i * y.q)
        of BigInteger || Quantity       :   (when GMP: return newQuantity(x.bi * y.q))
        of Integer    || Unit           :   return newQuantity(x, y.u)
        of BigInteger || Unit           :   (when GMP: return newQuantity(x, y.u))

        of Floating   || Integer        :   return newFloating(x.f * float(y.i))
        of Floating   || BigInteger     :   (when GMP: return newFloating(x.f * y.bi))
        of Floating   || Floating       :   return newFloating(x.f * y.f)
        of Floating   || Rational       :   return newRational(toRational(x.f) * y.rat)
        of Floating   || Complex        :   return newComplex(x.f * y.z)
        of Floating   || Quantity       :   return newQuantity(x.f * y.q)
        of Floating   || Unit           :   return newQuantity(x, y.u)

        of Rational   || Integer        :   return newRational(x.rat * y.i)
        of Rational   || BigInteger     :   (when GMP: return newRational(x.rat * y.bi))
        of Rational   || Floating       :   return newRational(x.rat * toRational(y.f))
        of Rational   || Rational       :   return newRational(x.rat * y.rat)
        of Rational   || Quantity       :   return newQuantity(x.rat * y.q)
        of Rational   || Unit           :   return newQuantity(x, y.u)

        of Complex    || Integer        :   return newComplex(x.z * float(y.i))
        of Complex    || Floating       :   return newComplex(x.z * y.f)
        of Complex    || Rational       :   return newComplex(x.z * toFloat(y.rat))
        of Complex    || Complex        :   return newComplex(x.z * y.z)
        
        of Quantity   || Integer        :   return newQuantity(x.q * y.i)
        of Quantity   || BigInteger     :   (when GMP: return newQuantity(x.q * y.bi))
        of Quantity   || Floating       :   return newQuantity(x.q * y.f)
        of Quantity   || Rational       :   return newQuantity(x.q * y.rat)
        of Quantity   || Quantity       :   return newQuantity(x.q * y.q)

        of Unit       || Integer        :   return newQuantity(y, x.u)
        of Unit       || BigInteger     :   (when GMP: return newQuantity(y, x.u))
        of Unit       || Floating       :   return newQuantity(y, x.u)
        of Unit       || Rational       :   return newQuantity(y, x.u)
        of Unit       || Quantity       :   return newQuantity(y, x.u)
        of Unit       || Unit           :   return newUnit(flatten(x.u & y.u))

        else:
            return invalidOperation("mul")

proc `*=`*(x: var Value, y: Value) =
    ## multiply given values
    ## and store the result in the first one
    ## 
    ## **Hint:** In-place, mutating operation
    
    let pair = getValuePair()
    case pair:
        of Integer    || Integer        :   normalIntegerMulI(x, y.i)
        of Integer    || BigInteger     :   (when GMP: x = newInteger(toBig(x.i) * y.bi))
        of BigInteger || Integer        :   (when GMP: x.bi *= toBig(y.i))
        of BigInteger || BigInteger     :   (when GMP: x.bi *= y.bi)
        of Integer    || Floating       :   x = newFloating(x.i * y.f)
        of BigInteger || Floating       :   (when GMP: x = newFloating(x.bi * y.f))
        of Integer    || Rational       :   x = newRational(x.i * y.rat)
        of BigInteger || Rational       :   (when GMP: x = newRational(x.bi * y.rat))
        of Integer    || Complex        :   x = newComplex(float(x.i) * y.z)
        of Integer    || Quantity       :   x = newQuantity(x.i * y.q)
        of BigInteger || Quantity       :   (when GMP: x = newQuantity(x.bi * y.q))
        of Integer    || Unit           :   x = newQuantity(x, y.u)
        of BigInteger || Unit           :   (when GMP: x = newQuantity(x, y.u))

        of Floating   || Integer        :   x.f *= float(y.i)
        of Floating   || BigInteger     :   (when GMP: x = newFloating(x.f * y.bi))
        of Floating   || Floating       :   x.f *= y.f
        of Floating   || Rational       :   x = newRational(toRational(x.f) * y.rat)
        of Floating   || Complex        :   x = newComplex(x.f * y.z)
        of Floating   || Quantity       :   x = newQuantity(x.f * y.q)
        of Floating   || Unit           :   x = newQuantity(x, y.u)

        of Rational   || Integer        :   x.rat *= y.i
        of Rational   || BigInteger     :   (when GMP: x.rat *= y.bi)
        of Rational   || Floating       :   x.rat *= toRational(y.f)
        of Rational   || Rational       :   x.rat *= y.rat
        of Rational   || Quantity       :   x = newQuantity(x.rat * y.q)
        of Rational   || Unit           :   x = newQuantity(x, y.u)

        of Complex    || Integer        :   x.z *= float(y.i)
        of Complex    || Floating       :   x.z *= y.f
        of Complex    || Rational       :   x.z *= toFloat(y.rat)
        of Complex    || Complex        :   x.z *= y.z
        
        of Quantity   || Integer        :   x.q *= y.i
        of Quantity   || BigInteger     :   (when GMP: x.q *= y.bi)
        of Quantity   || Floating       :   x.q *= y.f
        of Quantity   || Rational       :   x.q *= y.rat
        of Quantity   || Quantity       :   x.q *= y.q

        of Unit       || Integer        :   x = newQuantity(y, x.u)
        of Unit       || BigInteger     :   (when GMP: x = newQuantity(y, x.u))
        of Unit       || Floating       :   x = newQuantity(y, x.u)
        of Unit       || Rational       :   x = newQuantity(y, x.u)
        of Unit       || Quantity       :   x = newQuantity(y, x.u)
        of Unit       || Unit           :   x.u = flatten(x.u & y.u)

        else:
            discard invalidOperation("mul")

proc neg*(x: Value): Value =
    ## negate given value and return the result

    case x.kind:
        of Integer:
            if x.iKind==NormalInteger: return normalIntegerNeg(x.i)
            else: (when GMP: return newInteger(neg(x.bi)))
        of Floating: return newFloating(x.f*(-1.0))
        of Rational: return newRational(neg(x.rat))
        of Complex: return newComplex(x.z*(-1.0))
        of Quantity: return newQuantity(x.q*(-1))
        else:
            return invalidOperation("neg")

proc negI*(x: var Value) =
    ## negate given value
    ## and store back the result
    ## 
    ## **Hint:** In-place, mutating operation

    case x.kind:
        of Integer:
            if x.iKind==NormalInteger: normalIntegerNegI(x)
            else: (when GMP: negI(x.bi))
        of Floating: x.f *= -1.0
        of Rational: x.rat *= -1
        of Complex: x.z *= -1.0
        of Quantity: x.q *= -1
        else:
            discard invalidOperation("neg")

proc `/`*(x: Value, y: Value): Value =
    ## divide (integer division) given values and return the result

    let pair = getValuePair()
    case pair:
        of Integer    || Integer        :   return normalIntegerDiv(x.i, y.i)
        of Integer    || BigInteger     :   (when GMP: return newInteger(toBig(x.i) div notZero(y.bi)))
        of BigInteger || Integer        :   (when GMP: return newInteger(x.bi div toBig(notZero(y.i))))
        of BigInteger || BigInteger     :   (when GMP: return newInteger(x.bi div notZero(y.bi)))
        of Integer    || Floating       :   return newFloating(x.i / notZero(y.f))
        of BigInteger || Floating       :   (when GMP: return newFloating(x.bi / notZero(y.f)))
        of Integer    || Rational       :   return newInteger(toRational(x.i) div notZero(y.rat))
        of BigInteger || Rational       :   (when GMP: return newInteger(toRational(x.bi) div notZero(y.rat)))
        of Integer    || Complex        :   return newComplex(float(x.i) / notZero(y.z))

        of Floating   || Integer        :   return newFloating(x.f / float(notZero(y.i)))
        of Floating   || BigInteger     :   (when GMP: return newFloating(x.f / notZero(y.bi)))
        of Floating   || Floating       :   return newFloating(x.f / notZero(y.f))
        of Floating   || Rational       :   return newInteger(toRational(x.f) div notZero(y.rat))
        of Floating   || Complex        :   return newComplex(x.f / notZero(y.z))

        of Rational   || Integer        :   return newRational(x.rat / toRational(notZero(y.i)))
        of Rational   || BigInteger     :   (when GMP: return newRational(x.rat / toRational(notZero(y.bi))))
        of Rational   || Floating       :   return newRational(x.rat / toRational(notZero(y.f)))
        of Rational   || Rational       :   return newRational(x.rat / notZero(y.rat))

        of Complex    || Integer        :   return newComplex(x.z / float(notZero(y.i)))
        of Complex    || Floating       :   return newComplex(x.z / notZero(y.f))
        of Complex    || Rational       :   return newComplex(x.z / toFloat(notZero(y.rat)))
        of Complex    || Complex        :   return newComplex(x.z / notZero(y.z))
        
        of Quantity   || Integer        :   return newQuantity(x.q / y.i)
        of Quantity   || BigInteger     :   (when GMP: return newQuantity(x.q / y.bi))
        of Quantity   || Floating       :   return newQuantity(x.q / y.f)
        of Quantity   || Rational       :   return newQuantity(x.q / y.rat)
        of Quantity   || Quantity       :   return newQuantity(x.q / y.q)
        else:
            return invalidOperation("div")

proc `/=`*(x: var Value, y: Value) =
    ## divide (integer division) given values
    ## and store the result in the first one 
    ## 
    ## **Hint:** In-place, mutating operation

    let pair = getValuePair()
    case pair:
        of Integer    || Integer        :   normalIntegerDivI(x, y.i)
        of Integer    || BigInteger     :   (when GMP: x = newInteger(toBig(x.i) div notZero(y.bi)))
        of BigInteger || Integer        :   (when GMP: divI(x.bi, notZero(y.i)))
        of BigInteger || BigInteger     :   (when GMP: divI(x.bi, notZero(y.bi)))
        of Integer    || Floating       :   x = newFloating(x.i / notZero(y.f))
        of BigInteger || Floating       :   (when GMP: x = newFloating(x.bi / notZero(y.f)))
        of Integer    || Rational       :   x = newInteger(toRational(x.i) div notZero(y.rat))
        of BigInteger || Rational       :   (when GMP: x = newInteger(toRational(x.bi) div notZero(y.rat)))
        of Integer    || Complex        :   x = newComplex(float(x.i) / notZero(y.z))

        of Floating   || Integer        :   x.f /= float(notZero(y.i))
        of Floating   || BigInteger     :   (when GMP: x = newFloating(x.f / notZero(y.bi)))
        of Floating   || Floating       :   x.f /= notZero(y.f)
        of Floating   || Rational       :   x = newInteger(toRational(x.f) div notZero(y.rat))
        of Floating   || Complex        :   x = newComplex(x.f / notZero(y.z))

        of Rational   || Integer        :   x.rat /= toRational(notZero(y.i))
        of Rational   || BigInteger     :   (when GMP: x = newRational(x.rat / toRational(notZero(y.bi))))
        of Rational   || Floating       :   x.rat /= toRational(notZero(y.f))
        of Rational   || Rational       :   x.rat /= notZero(y.rat)

        of Complex    || Integer        :   x.z /= float(notZero(y.i))
        of Complex    || Floating       :   x.z /= notZero(y.f)
        of Complex    || Rational       :   x.z /= toFloat(notZero(y.rat))
        of Complex    || Complex        :   x.z /= notZero(y.z)
        
        of Quantity   || Integer        :   x.q /= y.i
        of Quantity   || BigInteger     :   (when GMP: x.q /= y.bi)
        of Quantity   || Floating       :   x.q /= y.f
        of Quantity   || Rational       :   x.q /= y.rat
        of Quantity   || Quantity       :   x.q /= y.q
        else:
            discard invalidOperation("div")

proc `//`*(x: Value, y: Value): Value =
    ## divide (floating-point division) given values and return the result
    
    let pair = getValuePair()
    case pair:
        of Integer    || Integer        :   return normalIntegerFDiv(x.i, y.i)
        of Integer    || BigInteger     :   (when GMP: return newInteger(x.i // notZero(y.bi)))
        of Integer    || Floating       :   return newFloating(float(x.i) / notZero(y.f))
        of BigInteger || Floating       :   (when GMP: return newFloating(x.bi / notZero(y.f)))
        of Integer    || Rational       :   return newRational(x.i / notZero(y.rat))
        of BigInteger || Rational       :   (when GMP: return newRational(x.bi / notZero(y.rat)))

        of Floating   || Integer        :   return newFloating(x.f / float(notZero(y.i)))
        of Floating   || BigInteger     :   (when GMP: return newFloating(x.f / notZero(y.bi)))
        of Floating   || Floating       :   return newFloating(x.f / notZero(y.f))
        of Floating   || Rational       :   return newRational(toRational(x.f) / notZero(y.rat))

        of Rational   || Integer        :   return newRational(x.rat / notZero(y.i))
        of Rational   || BigInteger     :   (when GMP: return newRational(x.rat / toRational(notZero(y.bi))))
        of Rational   || Floating       :   return newRational(x.rat / toRational(notZero(y.f)))
        of Rational   || Rational       :   return newRational(x.rat / notZero(y.rat))
        
        of Quantity   || Integer        :   return newQuantity(x.q // y.i)
        of Quantity   || BigInteger     :   (when GMP: return newQuantity(x.q // y.bi))
        of Quantity   || Floating       :   return newQuantity(x.q // y.f)
        of Quantity   || Rational       :   return newQuantity(x.q // y.rat)
        of Quantity   || Quantity       :   return newQuantity(x.q // y.q)
        else:
            return invalidOperation("fdiv")

proc `//=`*(x: var Value, y: Value) =
    ## divide (floating-point division) given values
    ## and store the result in the first one 
    ## 
    ## **Hint:** In-place, mutating operation
    
    let pair = getValuePair()
    case pair:
        of Integer    || Integer        :   normalIntegerFDivI(x, y.i)
        of Integer    || BigInteger     :   (when GMP: x = newInteger(x.i // notZero(y.bi)))
        of Integer    || Floating       :   x = newFloating(float(x.i) / notZero(y.f))
        of BigInteger || Floating       :   (when GMP: x = newFloating(x.bi / notZero(y.f)))
        of Integer    || Rational       :   x = newRational(x.i / notZero(y.rat))
        of BigInteger || Rational       :   (when GMP: x = newRational(x.bi / notZero(y.rat)))

        of Floating   || Integer        :   x.f /= float(notZero(y.i))
        of Floating   || BigInteger     :   (when GMP: x = newFloating(x.f / notZero(y.bi)))
        of Floating   || Floating       :   x.f /= notZero(y.f)
        of Floating   || Rational       :   x = newRational(toRational(x.f) / notZero(y.rat))

        of Rational   || Integer        :   x.rat /= notZero(y.i)
        of Rational   || BigInteger     :   (when GMP: x = newRational(x.rat / toRational(notZero(y.bi))))
        of Rational   || Floating       :   x.rat /= toRational(notZero(y.f))
        of Rational   || Rational       :   x.rat /= notZero(y.rat)
        
        of Quantity   || Integer        :   x.q //= y.i
        of Quantity   || BigInteger     :   (when GMP: x.q //= y.bi)
        of Quantity   || Floating       :   x.q //= y.f
        of Quantity   || Rational       :   x.q //= y.rat
        of Quantity   || Quantity       :   x.q //= y.q
        else:
            discard invalidOperation("fdiv")

proc `%`*(x: Value, y: Value): Value =
    ## perform the modulo operation between given values and return the result

    let pair = getValuePair()
    case pair:
        of Integer    || Integer        :   return normalIntegerMod(x.i, y.i)
        of Integer    || BigInteger     :   (when GMP: return newInteger(toBig(x.i) mod notZero(y.bi)))
        of BigInteger || Integer        :   (when GMP: return newInteger(x.bi mod toBig(notZero(y.i))))
        of BigInteger || BigInteger     :   (when GMP: return newInteger(x.bi mod notZero(y.bi)))
        of Integer    || Floating       :   return newFloating(float(x.i) mod notZero(y.f))
        of Integer    || Rational       :   return newRational(toRational(x.i) mod notZero(y.rat))
        of BigInteger || Rational       :   (when GMP: return newRational(toRational(x.bi) mod notZero(y.rat)))

        of Floating   || Integer        :   return newFloating(x.f mod float(notZero(y.i)))
        of Floating   || Floating       :   return newFloating(x.f mod notZero(y.f))
        of Floating   || Rational       :   return newRational(toRational(x.f) mod notZero(y.rat))

        of Rational   || Integer        :   return newRational(x.rat mod toRational(notZero(y.i)))
        of Rational   || BigInteger     :   (when GMP: return newRational(x.rat mod toRational(notZero(y.bi))))
        of Rational   || Floating       :   return newRational(x.rat mod toRational(notZero(y.f)))
        of Rational   || Rational       :   return newRational(x.rat mod notZero(y.rat))
        
        # of Quantity   || Integer        :   return newQuantity(x.q % y.i)
        # of Quantity   || BigInteger     :   (when GMP: return newQuantity(x.q % y.bi))
        # of Quantity   || Floating       :   return newQuantity(x.q % y.f)
        # of Quantity   || Rational       :   return newQuantity(x.q % y.rat)
        # of Quantity   || Quantity       :   return newQuantity(x.q % y.q)
        else:
            return invalidOperation("mod")

proc `%=`*(x: var Value, y: Value) =
    ## perform the modulo operation between given values
    ## and store the result in the first one
    ## 
    ## **Hint:** In-place, mutating operation

    let pair = getValuePair()
    case pair:
        of Integer    || Integer        :   normalIntegerModI(x, y.i)
        of Integer    || BigInteger     :   (when GMP: x = newInteger(toBig(x.i) mod notZero(y.bi)))
        of BigInteger || Integer        :   (when GMP: modI(x.bi, toBig(notZero(y.i))))
        of BigInteger || BigInteger     :   (when GMP: modI(x.bi, notZero(y.bi)))
        of Integer    || Floating       :   x = newFloating(float(x.i) mod notZero(y.f))
        of Integer    || Rational       :   x = newRational(toRational(x.i) mod notZero(y.rat))
        of BigInteger || Rational       :   (when GMP: x = newRational(toRational(x.bi) mod notZero(y.rat)))

        of Floating   || Integer        :   x.f = x.f mod float(notZero(y.i))
        of Floating   || Floating       :   x.f = x.f mod notZero(y.f)
        of Floating   || Rational       :   x = newRational(toRational(x.f) mod notZero(y.rat))

        of Rational   || Integer        :   x.rat = x.rat mod toRational(notZero(y.i))
        of Rational   || BigInteger     :   (when GMP: x.rat = x.rat mod toRational(notZero(y.bi)))
        of Rational   || Floating       :   x.rat = x.rat mod toRational(notZero(y.f))
        of Rational   || Rational       :   x.rat = x.rat mod notZero(y.rat)
        
        # of Quantity   || Integer        :   x.q %= y.i
        # of Quantity   || Floating       :   x.q %= y.f
        # of Quantity   || Rational       :   x.q %= y.rat
        # of Quantity   || Quantity       :   x.q %= y.q
        else:
            discard invalidOperation("mod")

proc `/%`*(x: Value, y: Value): Value =
    ## perform the divmod operation between given values
    ## and return the result as a *tuple* Block value
    let pair = getValuePair()
    case pair:
        of Integer    || Integer        :   return normalIntegerDivMod(x.i, y.i)
        of Integer    || BigInteger     :   
            when GMP: 
                let dm=divmod(x.i, notZero(y.bi))
                return newBlock(@[newInteger(dm[0]), newInteger(dm[1])])
        of BigInteger || Integer        :   
            when GMP: 
                let dm=divmod(x.bi, notZero(y.i))
                return newBlock(@[newInteger(dm[0]), newInteger(dm[1])])
        of BigInteger || BigInteger     :   
            when GMP: 
                let dm=divmod(x.bi, notZero(y.bi))
                return newBlock(@[newInteger(dm[0]), newInteger(dm[1])])
        of Integer    || Floating       :   return newBlock(@[x/y, x%y])
        of BigInteger || Floating       :   return newBlock(@[x/y, x%y])
        of Integer    || Rational       :   return newBlock(@[x/y, x%y])
        of BigInteger || Rational       :   return newBlock(@[x/y, x%y])

        of Floating   || Integer        :   return newBlock(@[x/y, x%y])
        of Floating   || Floating       :   return newBlock(@[x/y, x%y])
        of Floating   || Rational       :   return newBlock(@[x/y, x%y])

        of Rational   || Integer        :   return newBlock(@[x/y, x%y])
        of Rational   || BigInteger     :   return newBlock(@[x/y, x%y])
        of Rational   || Floating       :   return newBlock(@[x/y, x%y])
        of Rational   || Rational       :   return newBlock(@[x/y, x%y])
        
        # of Quantity   || Integer        :   return newBlock(@[x/y, x%y])
        # of Quantity   || BigInteger     :   return newBlock(@[x/y, x%y])
        # of Quantity   || Floating       :   return newBlock(@[x/y, x%y])
        # of Quantity   || Rational       :   return newBlock(@[x/y, x%y])
        # of Quantity   || Quantity       :   return newBlock(@[x/y, x%y])
        else:
            return invalidOperation("divmod")

proc `/%=`*(x: var Value, y: Value) =
    ## perform the divmod operation between given values
    ## and store the result in the first one
    ## 
    ## **Hint:** In-place, mutating operation
    
    x = x /% y

proc `^`*(x: Value, y: Value): Value =
    ## perform the power operation between given values and return the result
    
    let pair = getValuePair()
    case pair:
        of Integer    || Integer        :   return normalIntegerPow(x.i, y.i)
        of BigInteger || Integer        :   (when GMP: return newInteger(pow(x.bi, culong(y.i))))
        of Integer    || Floating       :   return newFloating(pow(float(x.i), y.f))
        of BigInteger || Floating       :   (when GMP: return newFloating(pow(x.bi, y.f)))
        of Integer    || Rational       :   return newRational(pow(float(x.i), toFloat(y.rat)))
        of BigInteger || Rational       :   (when GMP: return newRational(pow(x.bi, toFloat(y.rat))))

        of Floating   || Integer        :   return newFloating(pow(x.f, float(y.i)))
        of Floating   || BigInteger     :   (when GMP: return newFloating(pow(x.f, y.bi)))
        of Floating   || Floating       :   return newFloating(pow(x.f, y.f))

        of Rational   || Integer        :   return newRational(x.rat ^ y.i)
        of Rational   || Floating       :   discard notZero(x.rat); return newRational(x.rat ^ y.f)

        of Complex    || Integer        :   return newComplex(pow(x.z, float(y.i)))
        of Complex    || Floating       :   return newComplex(pow(x.z, y.f))
        of Complex    || Complex        :   return newComplex(pow(x.z, y.z))
        
        of Quantity   || Integer        :   return newQuantity(x.q ^ y.i)
        # of Quantity   || BigInteger     :   return newQuantity(x.q ^ y.bi)
        # of Quantity   || Floating       :   return newQuantity(x.q ^ y.f)
        # of Quantity   || Rational       :   return newQuantity(x.q ^ y.rat)
        # of Quantity   || Quantity       :   return newQuantity(x.q ^ y.q)
        else:
            return invalidOperation("pow")

proc `^=`*(x: var Value, y: Value) =
    ## perform the power operation between given values
    ## and store the result in the first value
    ## 
    ## **Hint:** In-place, mutation operation
    
    let pair = getValuePair()
    case pair:
        of Integer    || Integer        :   normalIntegerPowI(x, y.i)
        of BigInteger || Integer        :   (when GMP: powI(x.bi, culong(y.i)))
        of Integer    || Floating       :   x = newFloating(pow(float(x.i), y.f))
        of BigInteger || Floating       :   (when GMP: x = newFloating(pow(x.bi, y.f)))
        of Integer    || Rational       :   x = newRational(pow(float(x.i), toFloat(y.rat)))
        of BigInteger || Rational       :   (when GMP: x = newRational(pow(x.bi, toFloat(y.rat))))

        of Floating   || Integer        :   x.f = pow(x.f, float(y.i))
        of Floating   || BigInteger     :   (when GMP: x = newFloating(pow(x.f, y.bi)))
        of Floating   || Floating       :   x.f = pow(x.f, y.f)

        of Rational   || Integer        :   x = newRational(x.rat ^ y.i)
        of Rational   || Floating       :   x = newRational(x.rat ^ y.f)

        of Complex    || Integer        :   x.z = pow(x.z, float(y.i))
        of Complex    || Floating       :   x.z = pow(x.z, y.f)
        of Complex    || Complex        :   x.z = pow(x.z, y.z)
        
        of Quantity   || Integer        :   x.q ^= y.i
        # of Quantity   || BigInteger     :   x.q ^= y.bi
        # of Quantity   || Floating       :   x.q ^= y.f
        # of Quantity   || Rational       :   x.q ^= y.rat
        # of Quantity   || Quantity       :   x.q ^= y.q
        else:
            discard invalidOperation("pow")

proc `&&`*(x: Value, y: Value): Value =
    ## perform binary-AND between given values and return the result
    
    let pair = getValuePair()
    case pair:
        of Integer    || Integer        :   return normalIntegerAnd(x.i, y.i)
        of Integer    || BigInteger     :   (when GMP: return newInteger(toBig(x.i) and y.bi))
        of BigInteger || Integer        :   (when GMP: return newInteger(x.bi and toBig(y.i)))
        of BigInteger || BigInteger     :   (when GMP: return newInteger(x.bi and y.bi))
        of Integer    || Binary         :   return newBinary(numberToBinary(x.i) and y.n)

        of Binary     || Integer        :   return newBinary(x.n and numberToBinary(y.i))
        of Binary     || Binary         :   return newBinary(x.n and y.n)

        else:
            return invalidOperation("and")

proc `&&=`*(x: var Value, y: Value) =
    ## perform binary-AND between given values
    ## and store the result in the first value
    ## 
    ## **Hint:** In-place, mutation operation
    
    let pair = getValuePair()
    case pair:
        of Integer    || Integer        :   normalIntegerAndI(x, y.i)
        of Integer    || BigInteger     :   (when GMP: x = newInteger(toBig(x.i) and y.bi))
        of BigInteger || Integer        :   (when GMP: andI(x.bi, toBig(y.i)))
        of BigInteger || BigInteger     :   (when GMP: andI(x.bi, y.bi))
        of Integer    || Binary         :   x = newBinary(numberToBinary(x.i) and y.n)

        of Binary     || Integer        :   x.n = x.n and numberToBinary(y.i)
        of Binary     || Binary         :   x.n = x.n and y.n

        else:
            discard invalidOperation("and")

proc `||`*(x: Value, y: Value): Value =
    ## perform binary-OR between given values and return the result
    
    let pair = getValuePair()
    case pair:
        of Integer    || Integer        :   return normalIntegerOr(x.i, y.i)
        of Integer    || BigInteger     :   (when GMP: return newInteger(toBig(x.i) or y.bi))
        of BigInteger || Integer        :   (when GMP: return newInteger(x.bi or toBig(y.i)))
        of BigInteger || BigInteger     :   (when GMP: return newInteger(x.bi or y.bi))
        of Integer    || Binary         :   return newBinary(numberToBinary(x.i) or y.n)

        of Binary     || Integer        :   return newBinary(x.n or numberToBinary(y.i))
        of Binary     || Binary         :   return newBinary(x.n or y.n)

        else:
            return invalidOperation("or")

proc `||=`*(x: var Value, y: Value) =
    ## perform binary-OR between given values
    ## and store the result in the first value
    ## 
    ## **Hint:** In-place, mutation operation
    
    let pair = getValuePair()
    case pair:
        of Integer    || Integer        :   normalIntegerOrI(x, y.i)
        of Integer    || BigInteger     :   (when GMP: x = newInteger(toBig(x.i) or y.bi))
        of BigInteger || Integer        :   (when GMP: orI(x.bi, toBig(y.i)))
        of BigInteger || BigInteger     :   (when GMP: orI(x.bi, y.bi))
        of Integer    || Binary         :   x = newBinary(numberToBinary(x.i) or y.n)

        of Binary     || Integer        :   x.n = x.n or numberToBinary(y.i)
        of Binary     || Binary         :   x.n = x.n or y.n

        else:
            discard invalidOperation("or")

proc `^^`*(x: Value, y: Value): Value =
    ## perform binary-XOR between given values and return the result
    
    let pair = getValuePair()
    case pair:
        of Integer    || Integer        :   return normalIntegerXor(x.i, y.i)
        of Integer    || BigInteger     :   (when GMP: return newInteger(toBig(x.i) xor y.bi))
        of BigInteger || Integer        :   (when GMP: return newInteger(x.bi xor toBig(y.i)))
        of BigInteger || BigInteger     :   (when GMP: return newInteger(x.bi xor y.bi))
        of Integer    || Binary         :   return newBinary(numberToBinary(x.i) xor y.n)

        of Binary     || Integer        :   return newBinary(x.n xor numberToBinary(y.i))
        of Binary     || Binary         :   return newBinary(x.n xor y.n)

        else:
            return invalidOperation("xor")

proc `^^=`*(x: var Value, y: Value) =
    ## perform binary-XOR between given values
    ## and store the result in the first value
    ## 
    ## **Hint:** In-place, mutation operation
    
    let pair = getValuePair()
    case pair:
        of Integer    || Integer        :   normalIntegerXorI(x, y.i)
        of Integer    || BigInteger     :   (when GMP: x = newInteger(toBig(x.i) xor y.bi))
        of BigInteger || Integer        :   (when GMP: xorI(x.bi, toBig(y.i)))
        of BigInteger || BigInteger     :   (when GMP: xorI(x.bi, y.bi))
        of Integer    || Binary         :   x = newBinary(numberToBinary(x.i) xor y.n)

        of Binary     || Integer        :   x.n = x.n xor numberToBinary(y.i)
        of Binary     || Binary         :   x.n = x.n xor y.n

        else:
            discard invalidOperation("xor")

proc `!!`*(x: Value): Value =
    ## perform binary-NOT on given value and return the result

    case x.kind:
        of Integer:
            if x.iKind==NormalInteger: return normalIntegerNot(x.i)
            else: (when GMP: return newInteger(not x.bi))
        of Binary: return newBinary(not x.n)
        else:
            return invalidOperation("not")

proc `!!=`*(x: var Value) =
    ## perform binary-NOT on given value
    ## and store back the result
    ## 
    ## **Hint:** In-place, mutating operation

    case x.kind:
        of Integer:
            if x.iKind==NormalInteger: normalIntegerNotI(x)
            else: (when GMP: notI(x.bi))
        of Binary: x.n = not x.n
        else:
            discard invalidOperation("not")

proc `<<`*(x: Value, y: Value): Value =
    ## perform binary left-shift between given values and return the result

    let pair = getValuePair()
    case pair:
        of Integer    || Integer        :   return normalIntegerShl(x.i, y.i)
        of BigInteger || Integer        :   (when GMP: return newInteger(x.bi shl culong(y.i)))
        else:
            return invalidOperation("shl")

proc `<<=`*(x: var Value, y: Value) =
    ## perform binary left-shift between given values
    ## and store the result in the first value
    ## 
    ## **Hint:** In-place, mutation operation

    let pair = getValuePair()
    case pair:
        of Integer    || Integer        :   normalIntegerShlI(x, y.i)
        of BigInteger || Integer        :   (when GMP: shlI(x.bi, culong(y.i)))
        else:
            discard invalidOperation("shl")
    
proc `>>`*(x: Value, y: Value): Value =
    ## perform binary right-shift between given values and return the result

    let pair = getValuePair()
    case pair:
        of Integer    || Integer        :   return normalIntegerShr(x.i, y.i)
        of BigInteger || Integer        :   (when GMP: return newInteger(x.bi shr culong(y.i)))
        else:
            return invalidOperation("shr")

proc `>>=`*(x: var Value, y: Value) =
    ## perform binary right-shift between given values
    ## and store the result in the first value
    ## 
    ## **Hint:** In-place, mutation operation

    let pair = getValuePair()
    case pair:
        of Integer    || Integer        :   normalIntegerShrI(x, y.i)
        of BigInteger || Integer        :   (when GMP: shrI(x.bi, culong(y.i)))
        else:
            discard invalidOperation("shl")
