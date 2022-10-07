######################################################
# Arturo
# Programming Language + Bytecode VM compiler
# (c) 2019-2022 Yanis Zafirópulos
#
# @file: vm/exec.nim
######################################################

# TODO(VM/exec) General cleanup needed
#  labels: vm, execution, enhancement, cleanup

#=======================================
# Libraries
#=======================================

import hashes, sugar, tables

when defined(VERBOSE):
    import strformat
    import helpers/debug

import vm/[
    bytecode, 
    errors, 
    eval, 
    globals, 
    parse, 
    profiler, 
    stack, 
    values/logic, 
    values/value
]

#=======================================
# Types
#=======================================

type
    MemoizerKey = (string, Hash)

#=======================================
# Variables
#=======================================

var
    Memoizer*: OrderedTable[MemoizerKey,Value]
    CurrentDump*: Translation = nil

#=======================================
# Forward Declarations
#=======================================

proc doExec*(cnst: ValueArray, it: ByteArray, args: Value = nil): ValueDict

#=======================================
# Helpers
#=======================================

proc setFunctionArity*(funName: string, fun: Value) {.inline,enforceNoRaises.} =
    Arities[funName] = 
        if fun.fnKind==BuiltinFunction:
            fun.arity
        else:
            fun.params.a.len

template doExec*(input: Translation, args: Value = nil): ValueDict =
    doExec(input.constants, input.instructions, args)

template pushByIndex(idx: int):untyped =
    stack.push(cnst[idx])

proc storeByIndex(cnst: ValueArray, idx: int, doPop: static bool = true) {.inline,enforceNoRaises.}=
    hookProcProfiler("exec/storeByIndex"):
        if unlikely(stack.peek(0).kind==Function):
            Arities[cnst[idx].s] = 
                if stack.peek(0).fnKind==BuiltinFunction:
                    stack.peek(0).arity
                else:
                    stack.peek(0).params.a.len

        Syms[cnst[idx].s] =
            when doPop:
                move stack.pop()
            else:
                stack.peek(0)

template loadByIndex(idx: int):untyped =
    hookProcProfiler("exec/loadByIndex"):
        stack.push(GetSym(cnst[idx].s))

template callFunction*(f: Value, fnName: string = "<closure>"):untyped =
    if f.fnKind==UserFunction:
        hookProcProfiler("exec/callFunction:user"):
            let fArity = f.params.a.len
            
            if unlikely(SP<fArity):
                RuntimeError_NotEnoughArguments(fnName, fArity)

            if unlikely(f.memoize): 
                execBlock(f.main, args=f.params, hasArgs=true, isFuncBlock=true, imports=f.imports, exports=f.exports, exportable=f.exportable, memoized=newString(fnName), isMemoized=true)
            else:
                execBlock(f.main, args=f.params, hasArgs=true, isFuncBlock=true, imports=f.imports, exports=f.exports, exportable=f.exportable)
    else:
        f.action()

template callByName*(symIndx: string):untyped =
    let fun = GetSym(symIndx)
    callFunction(fun, symIndx)

template callByIndex(idx: int):untyped =
    hookProcProfiler("exec/callByIndex"):
        if cnst[idx].kind==Function:
            callFunction(cnst[idx])
        else:
            callByName(cnst[idx].s)

template fetchAttributeByIndex(idx: int):untyped =
    stack.pushAttr(cnst[idx].r, move stack.pop())

####

template execIsolated*(evaled:Translation): untyped =
    doExec(evaled)

template getMemoized*(fn: string, v: Value): Value =
    Memoizer.getOrDefault((fn, value.hash(v)), nil)

template setMemoized*(fn: string, v: Value, res: Value) =
    Memoizer[(fn, value.hash(v))] = res

proc execBlock*(
    blk             : Value, 
    args            : Value = nil, 
    hasArgs         : static bool = false,
    evaluated       : Translation = nil, 
    hasEval         : static bool = false,
    execInParent    : static bool = false, 
    isFuncBlock     : static bool = false, 
    imports         : Value = nil,
    exports         : Value = nil,
    exportable      : bool = false,
    inTryBlock      : static bool = false,
    memoized        : Value = nil,
    isMemoized      : static bool = false
) =
    var newSyms: ValueDict

    when isFuncBlock or ((not isFuncBlock) and (not execInParent)):
        let savedArities = Arities

    when isFuncBlock:
        var savedSyms: OrderedTable[string,Value]

    when isMemoized:
        var passedParams: Value

    try:
        when isFuncBlock:
            when isMemoized:
                passedParams = newBlock()
    
                when hasArgs:
                    var i=0
                    let argsLen = len(args.a)
                    while i < argsLen:
                        passedParams.a.add(stack.peek(i))
                        inc i
                    #passedParams.a.add(stack.peekRange(0, args.a.len-1))

                if (let memd = getMemoized(memoized.s, passedParams); not memd.isNil):
                    when hasArgs:
                        popN args.a.len
                    push memd
                    return
            else:
                when hasArgs:
                    for i, arg in mpairs(args.a):
                    #for i,arg in args.a:          
                        if stack.peek(i).kind==Function:
                            Arities[arg.s] = stack.peek(i).params.a.len
                        else:
                            Arities.del(arg.s)

            if not imports.isNil:
                savedSyms = Syms
                for k,v in pairs(imports.d):
                    Syms[k] = v

        let evaled = 
            when not hasEval:   
                doEval(blk)
            else: 
                evaluated

        when hasArgs:
            newSyms = doExec(evaled, args)
        else:
            newSyms = doExec(evaled)

    except ReturnTriggered:
        when not isFuncBlock:
            raise
        else:
            discard
        
    finally:
        when isFuncBlock:
            when isMemoized:
                setMemoized(memoized.s, passedParams, stack.peek(0))

            if not imports.isNil:
                Syms = savedSyms

            Arities = savedArities
            if not exports.isNil():
                if exportable:
                    Syms = newSyms
                else:
                    for k in exports.a:
                        if (let newSymsKey = newSyms.getOrDefault(k.s, nil); not newSymsKey.isNil):
                            Syms[k.s] = newSymsKey
            else:
                when hasArgs:
                    for arg in args.a:
                        Arities.del(arg.s)

        else:
            when not inTryBlock:
                when execInParent:
                    Syms = newSyms
                else:
                    Arities = savedArities
                    for k, v in mpairs(Syms):
                        if not (v.kind==Function and v.fnKind==BuiltinFunction):
                            if (let newsymV = newSyms.getOrDefault(k, nil); not newsymV.isNil):
                                v = newsymV
            else:
                if getCurrentException().isNil():
                    when execInParent:
                        Syms = newSyms
                    else:
                        Arities = savedArities
                        for k, v in mpairs(Syms):
                            if not (v.kind==Function and v.fnKind==BuiltinFunction):
                                if (let newsymV = newSyms.getOrDefault(k, nil); not newsymV.isNil):
                                    v = newsymV

proc execDictionaryBlock*(blk: Value): ValueDict =
    var newSyms: ValueDict

    try:
        newSyms = doExec(doEval(blk, isDictionary=true))
        
    finally:
        return collect(initOrderedTable()):
            for k, v in pairs(newSyms):
                if (let symV = Syms.getOrDefault(k, nil); symV.isNil or symV != v):
                    {k: v}

template execInternal*(path: string): untyped =
    execBlock(
        doParse(
            static readFile(
                normalizedPath(
                    parentDir(currentSourcePath()) & "/../library/internal/" & path & ".art"
                )
            ),
            isFile = false
        ),
        execInParent = true
    )

template callInternal*(fname: string, getValue: bool, args: varargs[Value]): untyped =
    let fun = Syms[fname]
    for v in args.reversed:
        push(v)

    callFunction(fun)

    when getValue:
        pop()

template handleBranching*(tryDoing, finalize: untyped): untyped =
    try:
        tryDoing
    except BreakTriggered:
        return
    except ContinueTriggered:
        discard
    except Defect as e:
        raise e 
    finally:
        finalize

#=======================================
# Methods
#=======================================

proc doExec*(cnst: ValueArray, it: ByteArray, args: Value = nil): ValueDict = 
    var i = 0
    var op {.register.}: OpCode
    var oldSyms: ValueDict

    oldSyms = Syms

    if not args.isNil:
        for arg in args.a:
            # pop argument and set it
            Syms[arg.s] = move stack.pop()

    while true:
        {.computedGoTo.}

        # if vmBreak:
        #     break

        op = (OpCode)(it[i])

        hookOpProfiler($(op)):

            when defined(VERBOSE):
                echo "exec: " & $(op)

            case op:
                # [0x00-0x1F]
                # push constants 
                of opConstI0            : stack.push(I0)
                of opConstI1            : stack.push(I1)
                of opConstI2            : stack.push(I2)
                of opConstI3            : stack.push(I3)
                of opConstI4            : stack.push(I4)
                of opConstI5            : stack.push(I5)
                of opConstI6            : stack.push(I6)
                of opConstI7            : stack.push(I7)
                of opConstI8            : stack.push(I8)
                of opConstI9            : stack.push(I9)
                of opConstI10           : stack.push(I10)
                of opConstI11           : stack.push(I11)
                of opConstI12           : stack.push(I12)
                of opConstI13           : stack.push(I13)
                of opConstI14           : stack.push(I14)
                of opConstI15           : stack.push(I15)

                of opConstI1M           : stack.push(I1M)           # unused by evaluator

                of opConstF0            : stack.push(F0)
                of opConstF1            : stack.push(F1)
                of opConstF2            : stack.push(F2)

                of opConstF1M           : stack.push(F1M)           # unused by evaluator

                of opConstBT            : stack.push(VTRUE)
                of opConstBF            : stack.push(VFALSE)
                of opConstBM            : stack.push(VMAYBE)

                of opConstS             : stack.push(VEMPTYSTR)
                of opConstA             : stack.push(VEMPTYARR)
                of opConstD             : stack.push(VEMPTYDICT)

                of opConstN             : stack.push(VNULL)

                # lines & error reporting
                of opEol                : 
                    when not defined(NOERRORLINES):
                        i += 1
                        CurrentLine = (int)(it[i])
                    else:
                        discard
                of opEolX               :   
                    when not defined(NOERRORLINES):
                        i += 2
                        CurrentLine = (int)((uint16)(it[i-1]) shl 8 + (byte)(it[i]))
                    else:
                        discard

                of RSRV1                : discard
                of RSRV2                : discard

                # [0x20-0x2F]
                # push values
                of opPush0              : pushByIndex(0)
                of opPush1              : pushByIndex(1)
                of opPush2              : pushByIndex(2)
                of opPush3              : pushByIndex(3)
                of opPush4              : pushByIndex(4)
                of opPush5              : pushByIndex(5)
                of opPush6              : pushByIndex(6)
                of opPush7              : pushByIndex(7)
                of opPush8              : pushByIndex(8)
                of opPush9              : pushByIndex(9)
                of opPush10             : pushByIndex(10)
                of opPush11             : pushByIndex(11)
                of opPush12             : pushByIndex(12)
                of opPush13             : pushByIndex(13)
                #of opPush0..opPush13    : pushByIndex((int)(op)-(int)(opPush0))
                of opPush               : i += 1; pushByIndex((int)(it[i]))
                of opPushX              : i += 2; pushByIndex((int)((uint16)(it[i-1]) shl 8 + (byte)(it[i]))) 

                # [0x30-0x3F]
                # store variables (from <- stack)
                of opStore0             : storeByIndex(cnst, 0)
                of opStore1             : storeByIndex(cnst, 1)
                of opStore2             : storeByIndex(cnst, 2)
                of opStore3             : storeByIndex(cnst, 3)
                of opStore4             : storeByIndex(cnst, 4)
                of opStore5             : storeByIndex(cnst, 5)
                of opStore6             : storeByIndex(cnst, 6)
                of opStore7             : storeByIndex(cnst, 7)
                of opStore8             : storeByIndex(cnst, 8)
                of opStore9             : storeByIndex(cnst, 9)
                of opStore10            : storeByIndex(cnst, 10)
                of opStore11            : storeByIndex(cnst, 11)
                of opStore12            : storeByIndex(cnst, 12)
                of opStore13            : storeByIndex(cnst, 13)
                of opStore              : i += 1; storeByIndex(cnst, (int)(it[i]))   
                of opStoreX             : i += 2; storeByIndex(cnst, (int)((uint16)(it[i-1]) shl 8 + (byte)(it[i])))              

                # [0x40-0x4F]
                # load variables (to -> stack)
                of opLoad0              : loadByIndex(0)
                of opLoad1              : loadByIndex(1)
                of opLoad2              : loadByIndex(2)
                of opLoad3              : loadByIndex(3)
                of opLoad4              : loadByIndex(4)
                of opLoad5              : loadByIndex(5)
                of opLoad6              : loadByIndex(6)
                of opLoad7              : loadByIndex(7)
                of opLoad8              : loadByIndex(8)
                of opLoad9              : loadByIndex(9)
                of opLoad10             : loadByIndex(10)
                of opLoad11             : loadByIndex(11)
                of opLoad12             : loadByIndex(12)
                of opLoad13             : loadByIndex(13)
                of opLoad               : i += 1; loadByIndex((int)(it[i]))
                of opLoadX              : i += 2; loadByIndex((int)((uint16)(it[i-1]) shl 8 + (byte)(it[i]))) 

                # [0x50-0x5F]
                # store-load variables (from <- stack, without popping)
                of opStorl0             : storeByIndex(cnst, 0, doPop=false)
                of opStorl1             : storeByIndex(cnst, 1, doPop=false)
                of opStorl2             : storeByIndex(cnst, 2, doPop=false)
                of opStorl3             : storeByIndex(cnst, 3, doPop=false)
                of opStorl4             : storeByIndex(cnst, 4, doPop=false)
                of opStorl5             : storeByIndex(cnst, 5, doPop=false)
                of opStorl6             : storeByIndex(cnst, 6, doPop=false)
                of opStorl7             : storeByIndex(cnst, 7, doPop=false)
                of opStorl8             : storeByIndex(cnst, 8, doPop=false)
                of opStorl9             : storeByIndex(cnst, 9, doPop=false)
                of opStorl10            : storeByIndex(cnst, 10, doPop=false)
                of opStorl11            : storeByIndex(cnst, 11, doPop=false)
                of opStorl12            : storeByIndex(cnst, 12, doPop=false)
                of opStorl13            : storeByIndex(cnst, 13, doPop=false)
                of opStorl              : i += 1; storeByIndex(cnst, (int)(it[i]), doPop=false)   
                of opStorlX             : i += 2; storeByIndex(cnst, (int)((uint16)(it[i-1]) shl 8 + (byte)(it[i])), doPop=false)              

                # [0x60-0x6F]
                # function calls
                of opCall0              : callByIndex(0)  
                of opCall1              : callByIndex(1)
                of opCall2              : callByIndex(2)
                of opCall3              : callByIndex(3)
                of opCall4              : callByIndex(4)
                of opCall5              : callByIndex(5)
                of opCall6              : callByIndex(6)
                of opCall7              : callByIndex(7)
                of opCall8              : callByIndex(8)
                of opCall9              : callByIndex(9)
                of opCall10             : callByIndex(10)
                of opCall11             : callByIndex(11)
                of opCall12             : callByIndex(12)
                of opCall13             : callByIndex(13)          
                of opCall               : i += 1; callByIndex((int)(it[i]))
                of opCallX              : i += 2; callByIndex((int)((uint16)(it[i-1]) shl 8 + (byte)(it[i]))) 

                # [0x70-0x7F]
                # attributes
                of opAttr0              : fetchAttributeByIndex(0)
                of opAttr1              : fetchAttributeByIndex(1)
                of opAttr2              : fetchAttributeByIndex(2)
                of opAttr3              : fetchAttributeByIndex(3)
                of opAttr4              : fetchAttributeByIndex(4)
                of opAttr5              : fetchAttributeByIndex(5)
                of opAttr6              : fetchAttributeByIndex(6)
                of opAttr7              : fetchAttributeByIndex(7)
                of opAttr8              : fetchAttributeByIndex(8)
                of opAttr9              : fetchAttributeByIndex(9)
                of opAttr10             : fetchAttributeByIndex(10)
                of opAttr11             : fetchAttributeByIndex(11)
                of opAttr12             : fetchAttributeByIndex(12)
                of opAttr13             : fetchAttributeByIndex(13)
                #of opAttr0..opAttr13    : fetchAttributeByIndex((int)(op)-(int)(opAttr0))
                of opAttr               : i += 1; fetchAttributeByIndex((int)(it[i]))
                of opAttrX              : i += 2; fetchAttributeByIndex((int)((uint16)(it[i-1]) shl 8 + (byte)(it[i]))) 

                #---------------------------------
                # OP FUNCTIONS
                #---------------------------------

                # [0x80-0x8F]
                # arithmetic operators
                of opAdd                : AddF.action()
                of opSub                : SubF.action()
                of opMul                : MulF.action()
                of opDiv                : DivF.action()
                of opFdiv               : FdivF.action()
                of opMod                : ModF.action()
                of opPow                : PowF.action()

                of opNeg                : NegF.action()

                # binary operators
                of opBNot               : BNotF.action()
                of opBAnd               : BAndF.action() 
                of opBOr                : BOrF.action()

                of opShl                : ShlF.action()
                of opShr                : ShrF.action()

                # logical operators
                of opNot                : NotF.action()
                of opAnd                : AndF.action()
                of opOr                 : OrF.action()

                # [0x90-0x9F]
                # comparison operators
                of opEq                 : EqF.action()
                of opNe                 : NeF.action()
                of opGt                 : GtF.action()
                of opGe                 : GeF.action()
                of opLt                 : LtF.action()
                of opLe                 : LeF.action()

                # branching
                of opIf                 : IfF.action()
                of opIfE                : IfEF.action()
                of opElse               : ElseF.action()
                of opWhile              : WhileF.action()
                of opReturn             : ReturnF.action()

                # getters/setters
                of opGet                : GetF.action()
                of opSet                : SetF.action()

                # converters
                of opTo                 : ToF.action()
                of opToS                : 
                    stack.push(VSTRINGT)
                    ToF.action()
                of opToI                : 
                    stack.push(VINTEGERT)
                    ToF.action()

                # [0xA0-0xAF]
                # i/o operations
                of opPrint              : PrintF.action()

                # generators          
                of opArray              : ArrayF.action()
                of opDict               : DictF.action()
                of opFunc               : FuncF.action()

                # ranges & iterators
                of opRange              : RangeF.action()
                of opLoop               : LoopF.action()
                of opMap                : MapF.action()
                of opSelect             : SelectF.action()

                # collections
                of opSize               : SizeF.action()
                of opReplace            : ReplaceF.action()
                of opSplit              : SplitF.action()
                of opJoin               : JoinF.action()
                of opReverse            : ReverseF.action()

                # increment/decrement
                of opInc                : IncF.action()
                of opDec                : DecF.action()

                of RSRV3                : discard

                #of RSRV3..RSRV14        : discard

                #---------------------------------
                # LOW-LEVEL OPERATIONS
                #---------------------------------

                # [0xB0-0xBF]
                # no operation
                of opNop                : discard

                # stack operations
                of opPop                : discard stack.pop()
                of opDup                : stack.push(sTop())
                of opOver               : stack.push(stack.peek(1))
                of opSwap               : swap(Stack[SP-1], Stack[SP-2])

                # flow control
                of opJmp                : i = (int)(it[i+1])
                of opJmpX               : i = (int)((uint16)(it[i+1]) shl 8 + (byte)(it[i+2]))
                of opJmpIf              : 
                    if stack.pop().b==True:
                        i = (int)(it[i+1])
                of opJmpIfX             : 
                    if stack.pop().b==True:
                        i = (int)((uint16)(it[i+1]) shl 8 + (byte)(it[i+2]))
                of opJmpIfN             : 
                    if Not(stack.pop().b)==True:
                        i = (int)(it[i+1])
                of opJmpIfNX            : 
                    if Not(stack.pop().b)==True:
                        i = (int)((uint16)(it[i+1]) shl 8 + (byte)(it[i+2]))
                of opRet                : discard
                of opEnd                : break

        i += 1

    result = Syms

    Syms = oldSyms
    