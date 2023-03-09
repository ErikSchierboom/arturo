#=======================================================
# Arturo
# Programming Language + Bytecode VM compiler
# (c) 2019-2023 Yanis Zafirópulos
#
# @file: vm/values/types.nim
#=======================================================

## The main type definitions for the VM.

#=======================================
# Libraries
#=======================================

import std/[tables, times, unicode, setutils]

when not defined(NOSQLITE):
    import db_sqlite as sqlite

when defined(WEB):
    import std/jsbigints

when not defined(NOGMP):
    import helpers/bignums

import vm/opcodes
import vm/values/custom/[vbinary, vcolor, vcomplex, vlogical, vquantity, vrange, vrational, vregex, vsocket, vsymbol, vversion]
import vm/values/flags

#=======================================
# Types
#=======================================

type
    ValueArray* = seq[Value]

    ValueDictObj*   = OrderedTable[string, Value]
    ValueDict*      = OrderedTableRef[string, Value]

    SymTable*   = Table[string, Value]

    Translation* = ref object
        constants*: ValueArray
        instructions*: VBinary

    IntArray*   = seq[int]

    BuiltinAction* = proc ()

    # TODO(VM/values/types) add new `:matrix` type?
    #  this would normally go with a separate Linear Algebra-related stdlib module
    #  labels: vm, values, enhancement, open discussion

    # TODO(VM/values/types) add new `:typeset` type?
    #  or... could this be encapsulated in our existing `:type` values?
    #  labels: vm, values, enhancement, open discussion

    # TODO(Vm/values/types) add new `:exception` type?
    #  this could work well with a new potential `try?`/`catch` syntax, 
    #  or a `throw` method
    #  labels: vm, values, enhancement, open discussion

    ValueKind* = enum
        Null            = 0
        Logical         = 1
        Integer         = 2
        Floating        = 3
        Complex         = 4
        Rational        = 5
        Version         = 6
        Type            = 7
        Char            = 8
        String          = 9
        Word            = 10
        Literal         = 11
        Label           = 12
        Attribute       = 13
        AttributeLabel  = 14
        Path            = 15
        PathLabel       = 16
        Symbol          = 17
        SymbolLiteral   = 18

        Quantity        = 19
        Regex           = 20
        Color           = 21
        Date            = 22
        Binary          = 23
        Dictionary      = 24
        Object          = 25
        Store           = 26
        Function        = 27
        Inline          = 28
        Block           = 29
        Range           = 30
        Database        = 31
        Socket          = 32    
        Bytecode        = 33

        Nothing         = 34
        Any             = 35

    ValueSpec* = set[ValueKind]

    IntegerKind* = enum
        NormalInteger
        BigInteger

    FunctionKind* = enum
        UserFunction
        BuiltinFunction

    StoreKind* = enum
        NativeStore
        JsonStore
        SqliteStore
        UndefinedStore

    TypeKind* = enum
        UserType
        BuiltinType

    DatabaseKind* = enum
        SqliteDatabase
        MysqlDatabase

    PrecedenceKind* = enum
        InfixPrecedence
        PrefixPrecedence
        PostfixPrecedence

    AliasBinding* = object
        precedence*: PrecedenceKind
        name*:       Value

    Prototype* = ref object
        name*       : string
        fields*     : ValueArray
        methods*    : ValueDict
        doInit*     : proc (v:Value)
        doPrint*    : proc (v:Value): string
        doCompare*  : proc (a,b:Value): int
        inherits*   : Prototype

    SymbolDict*   = OrderedTable[VSymbol,AliasBinding]

    ValueInfo* = ref object
        descr*          : string
        module*         : string

        when defined(DOCGEN):
            line*       : int

        case kind*: ValueKind:
            of Function:
                args*       : OrderedTable[string,ValueSpec]
                attrs*      : OrderedTable[string,(ValueSpec,string)]
                returns*    : ValueSpec
                when defined(DOCGEN):
                    example*    : string
            else:
                discard

    VFunction* = ref object
        arity*  : int8

        case fnKind*: FunctionKind:
            of UserFunction:
                params*     : seq[string]
                main*       : Value
                imports*    : Value
                exports*    : Value
                memoize*    : bool
                inline*     : bool
                bcode*      : Value
            of BuiltinFunction:
                op*         : OpCode
                action*     : BuiltinAction

    VStore* = ref object
        data*       : ValueDict     # the actual data
        path*       : string        # the path to the store

        global*     : bool          # whether the store is global (saved in the main ~/.arturo/stores folder) or not
        loaded*     : bool          # has the store been loaded (=read from disk) yet?
        autosave*   : bool          # should the store be saved automatically after every change?
        pending*    : bool          # are there pending changes to be saved?
        
        forceLoad*  : proc(store:VStore)    # ensureLoaded wrapped as a field proc

        case kind*: StoreKind:
            of SqliteStore:
                when not defined(NOSQLITE):
                    db* : sqlite.DbConn
            else:
                discard

    Value* {.final,acyclic.} = ref object
        when not defined(PORTABLE):
            info*   : ValueInfo

        ln*     : uint32
        flags*  : ValueFlags

        case kind*: ValueKind:
            of Null,
               Nothing,
               Any,
               Logical:
                   discard
            of Integer:
                case iKind*: IntegerKind:
                    # TODO(VM/values/types) Wrap Normal and BigInteger in one type
                    #  Perhaps, we could do that via class inheritance, with the two types inheriting a new `Integer` type, provided that it's properly benchmarked first.
                    #  labels: vm, values, enhancement, benchmark, open discussion
                    of NormalInteger:   i*  : int
                    of BigInteger:
                        when defined(WEB):
                            bi* : JsBigInt
                        elif not defined(NOGMP):
                            bi* : Int
                        else:
                            discard
            of Floating: f*: float
            of Complex:     z*  : VComplex
            of Rational:    rat*  : VRational
            of Version:
                version*: VVersion
            of Type:
                t*  : ValueKind
                case tpKind*: TypeKind:
                    of UserType:    ts* : Prototype
                    of BuiltinType: discard
            of Char:        c*  : Rune
            of String,
               Word,
               Literal,
               Label,
               Attribute,
               AttributeLabel:       s*  : string
            of Path,
               PathLabel:   p*  : ValueArray
            of Symbol,
               SymbolLiteral:
                   m*  : VSymbol
            of Regex:       rx* : VRegex
            of Quantity:
                nm*: Value
                unit*: VQuantity
            of Color:       l*  : VColor
            of Date:
                e*     : ValueDict
                eobj*  : ref DateTime
            of Binary:      n*  : VBinary
            of Inline,
               Block:
                   a*       : ValueArray
                   data*    : Value
            of Range:
                    rng*    : VRange
            of Dictionary:  d*  : ValueDict
            of Object:
                o*: ValueDict   # fields
                proto*: Prototype # custom type pointer
            of Store:
                sto*: VStore
            of Function:
                funcType*: VFunction
            of Database:
                case dbKind*: DatabaseKind:
                    of SqliteDatabase:
                        when not defined(NOSQLITE):
                            sqlitedb*: sqlite.DbConn
                    of MysqlDatabase: discard
                    #mysqldb*: mysql.DbConn
            of Socket:
                when not defined(WEB):
                    sock*: VSocket
            of Bytecode:
                trans*: Translation

    ValueObj = typeof(Value()[])
    FuncObj = typeof(VFunction()[])

# Benchmarking
{.hints: on.} # Apparently we cannot disable just `Name` hints?
{.hint: "Value's inner type is currently " & $sizeof(ValueObj) & ".".}
{.hint: "Function's inner type is currently " & $sizeof(FuncObj) & ".".}
{.hints: off.}

when sizeof(ValueObj) > 72: # At time of writing it was '72', 8 - 64 bit integers seems like a good warning site? Can always go smaller
    {.warning: "'Value's inner object is large which will impact performance".}

#=======================================
# Accessors
#=======================================

# Flags

template readonly*(val: Value): bool = IsReadOnly in val.flags
template `readonly=`*(val: Value, newVal: bool) = val.flags[IsReadOnly] = newVal

template dynamic*(val: Value): bool = IsDynamic in val.flags
template `dynamic=`*(val: Value, newVal: bool) = val.flags[IsDynamic] = newVal

template b*(val: Value): VLogical = VLogical(val.flags - NonLogicalF)
template `b=`*(val: Value, newVal: VLogical) = val.flags = val.flags - LogicalF + newVal

template makeAccessor(field, subfield: untyped) =
    template subfield*(val: Value): typeof(val.field.subfield) =
        val.field.subfield

    template `subfield=`*(val: Value, newVal: typeof(val.field.subfield)) =
        val.field.subfield = newVal

# Info

makeAccessor(info, descr)
makeAccessor(info, module)
makeAccessor(info, args)
makeAccessor(info, attrs)
makeAccessor(info, returns)
when defined(DOCGEN):
    makeAccessor(info, example)

# Version

makeAccessor(version, major)
makeAccessor(version, minor)
makeAccessor(version, patch)
makeAccessor(version, extra)

# Function

makeAccessor(funcType, arity)
makeAccessor(funcType, fnKind)
makeAccessor(funcType, params)
makeAccessor(funcType, main)
makeAccessor(funcType, imports)
makeAccessor(funcType, exports)
makeAccessor(funcType, memoize)
makeAccessor(funcType, bcode)
makeAccessor(funcType, inline)
makeAccessor(funcType, action)
makeAccessor(funcType, op)
