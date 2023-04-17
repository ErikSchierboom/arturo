#=======================================================
# Arturo
# Programming Language + Bytecode VM compiler
# (c) 2019-2023 Yanis Zafirópulos
#
# @file: vm/values/custom/vquantity.nim
#=======================================================

## The internal `:quantity` type

#=======================================
# Libraries
#=======================================

import macros, parseutils, nre, strutils, tables

include vquantity/preprocessor

#=======================================
# Core definitions
#=======================================

static:
    #----------------------------------------------------------------------------------------------------
    # Quantities
    #----------------------------------------------------------------------------------------------------
    #              name                     signatures
    #----------------------------------------------------------------------------------------------------
    defineQuantity "Acceleration",          -39
    defineQuantity "Activity",              3_199_980
    defineQuantity "Angle",                 512_000_000_000
    defineQuantity "Angular Momentum",      7981
    defineQuantity "Angular Velocity",      511_999_999_980
    defineQuantity "Area",                  2
    defineQuantity "Area Density",          7998
    defineQuantity "Capacitance",           312_078
    defineQuantity "Charge",                160_020
    defineQuantity "Conductance",           312_058
    defineQuantity "Currency",              1_280_000_000
    defineQuantity "Current",               160_000
    defineQuantity "Density",               7997
    defineQuantity "Elastance",             312_078
    defineQuantity "Energy",                7962
    defineQuantity "Force",                 7961
    defineQuantity "Frequency",             20
    defineQuantity "Illuminance",           63_999_998
    defineQuantity "Inductance",            312_038
    defineQuantity "Information",           25_600_000_000
    defineQuantity "Jolt",                  59
    defineQuantity "Length",                1
    defineQuantity "Luminosity",            64_000_000
    defineQuantity "Magnetism",             -152_040, -152_038, 159_999
    defineQuantity "Mass",                  8000
    defineQuantity "Molar Concentration",   3_199_997
    defineQuantity "Momentum",              7981
    defineQuantity "Potential",             -152_058
    defineQuantity "Power",                 7942
    defineQuantity "Pressure",              7959
    defineQuantity "Radiation",             -38
    defineQuantity "Radiation Exposure",    152_020
    defineQuantity "Resistance",            -312_058
    defineQuantity "Specific Volume",       -7997
    defineQuantity "Speed",                 -19
    defineQuantity "Snap",                  -79
    defineQuantity "Substance",             3_200_000
    defineQuantity "Temperature",           400
    defineQuantity "Time",                  20
    defineQuantity "Unitless",              0
    defineQuantity "Viscosity",             -18, 7979
    defineQuantity "Volume",                3
    defineQuantity "Volumetric Flow",       -17
    defineQuantity "Wave Number",           -1
    defineQuantity "Yank",                  7941

    #----------------------------------------------------------------------------------------------------
    # Prefixes
    #----------------------------------------------------------------------------------------------------
    #            name       symbol      definition 
    #----------------------------------------------------------------------------------------------------
    definePrefix "a",       "a",        "1e-18"
    definePrefix "f",       "f",        "1e-15"
    definePrefix "p",       "p",        "1e-12"
    definePrefix "n",       "n",        "1e-9"
    definePrefix "u",       "μ",        "1e-6"
    definePrefix "m",       "m",        "1e-3"
    definePrefix "c",       "c",        "1e-2"
    definePrefix "d",       "d",        "1e-1"
    definePrefix "no",      "",         "1"
    definePrefix "da",      "da",       "1e1"
    definePrefix "h",       "h",        "1e2"
    definePrefix "k",       "k",        "1e3"
    definePrefix "M",       "M",        "1e6"
    definePrefix "G",       "G",        "1e9"
    definePrefix "T",       "T",        "1e12"
    definePrefix "P",       "P",        "1e15"
    definePrefix "E",       "E",        "1e18"

    #---------------------------------------------------------------------------------------------------------------------------
    # Base units
    #---------------------------------------------------------------------------------------------------------------------------
    #      name         symbol      prefix?     unit kind                   aliases
    #---------------------------------------------------------------------------------------------------------------------------
    define "m",         "m",        true,       "Length",                   "meter", "metre", "meters", "metres"
    define "s",         "s",        true,       "Time",                     "second", "seconds"
    define "K",         "K",        true,       "Temperature",              "kelvin", "kelvins"
    define "g",         "g",        true,       "Mass",                     "gram", "grams"
    define "A",         "A",        true,       "Current",                  "amp", "amps", "ampere", "amperes"
    define "mol",       "mol",      true,       "Substance",                "mole", "moles"
    define "cd",        "cd",       true,       "Luminosity",               "candela", "candelas"
    define "usd",       "usd",      false,      "Currency",                 "dollar", "dollars"
    define "B",         "B",        true,       "Information",              "byte", "bytes"
    define "rad",       "rad",      false,      "Angle",                    "radian", "radians"

    #---------------------------------------------------------------------------------------------------------------------------
    # Length units (base: m)
    #---------------------------------------------------------------------------------------------------------------------------
    #      name         symbol      prefix?     definition                  aliases
    #---------------------------------------------------------------------------------------------------------------------------
    define "in",        "in",       false,      "127/5000 m",               "inch", "inches"
    define "ft",        "ft",       false,      "12 in",                    "foot", "feet"
    define "yd",        "yd",       false,      "3 ft",                     "yard", "yards"
    define "ftm",       "ftm",      false,      "1 yd",                     "fathom", "fathoms"
    define "rod",       "rod",      false,      "5.5 yd",                   "rods"
    define "mi",        "mi",       false,      "5280 ft",                  "mile", "miles"
    define "fur",       "fur",      false,      "1/8 mi",                   "furlong", "furlongs"
    define "nmi",       "nmi",      false,      "1852 m",                   "nauticalMile", "nauticalMiles"
    define "ang",       "Å",        false,      "1e-10 m",                  "angstrom", "angstroms"
    define "au",        "au",       false,      "149597870700 m",           "astronomicalUnit", "astronomicalUnits"
    define "ly",        "ly",       false,      "9460730472580800 m",       "lightYear", "lightYears"
    define "pc",        "pc",       false,      "3.26156 ly",               "parsec", "parsecs"

    #---------------------------------------------------------------------------------------------------------------------------
    # Area units (base: m^2)
    #---------------------------------------------------------------------------------------------------------------------------
    #      name         symbol      prefix?     definition                  aliases
    #---------------------------------------------------------------------------------------------------------------------------
    define "ac",        "ac",       false,      "4840 yd2",                 "acre", "acres"
    define "are",       "are",      false,      "100 m2",                   "are", "ares"
    define "ha",        "ha",       false,      "100 are",                  "hectare", "hectares"

    #---------------------------------------------------------------------------------------------------------------------------
    # Volume units (base: m^3)
    #---------------------------------------------------------------------------------------------------------------------------
    #      name         symbol      prefix?     definition                  aliases
    #---------------------------------------------------------------------------------------------------------------------------
    define "L",         "L",        true,       "1000 cm3",                 "l", "liter", "liters"
    define "tsp",       "tsp",      false,      "5 mL",                     "teaspoon", "teaspoons"
    define "tbsp",      "tbsp",     false,      "3 tsp",                    "tablespoon", "tablespoons"
    define "floz",      "floz",     false,      "2 tbsp",                   "fluidOunce", "fluidOunces"
    define "cup",       "cup",      false,      "8 floz",                   "cup", "cups"
    define "pt",        "pt",       false,      "2 cup",                    "pint", "pints"
    define "qt",        "qt",       false,      "2 pt",                     "quart", "quarts"
    define "gal",       "gal",      false,      "4 qt",                     "gallon", "gallons"
    define "bbl",       "bbl",      false,      "42 gal",                   "barrel", "barrels"
    
    #---------------------------------------------------------------------------------------------------------------------------
    # Time units (base: s)
    #---------------------------------------------------------------------------------------------------------------------------
    #      name         symbol      prefix?     definition                  aliases
    #---------------------------------------------------------------------------------------------------------------------------
    define "min",       "min",      false,      "60 s",                     "minute", "minutes"
    define "hr",        "hr",       false,      "60 min",                   "hour", "hours"
    define "day",       "day",      false,      "24 hours",                 "day", "days"
    define "wk",        "wk",       false,      "7 days",                   "week", "weeks"
    define "mo",        "mo",       false,      "2629746 s",                "month", "months"
    define "yr",        "yr",       false,      "31556952 s",               "year", "years"

    #---------------------------------------------------------------------------------------------------------------------------
    # Mass units (base: g)
    #---------------------------------------------------------------------------------------------------------------------------
    #      name         symbol      prefix?     definition                  aliases
    #---------------------------------------------------------------------------------------------------------------------------
    define "lb",        "lb",       false,      "45359237/100000000 g",     "pound", "pounds"
    define "oz",        "oz",       false,      "1/16 lb",                  "ounce", "ounces"
    define "ct",        "ct",       false,      "1/5 g",                    "carat", "carats"
    define "ton",       "ton",      false,      "2000 lb",                  "ton", "tons"
    define "st",        "st",       false,      "14 lb",                    "stone", "stones"
    
    #---------------------------------------------------------------------------------------------------------------------------
    # Speed units (base: m/s)
    #---------------------------------------------------------------------------------------------------------------------------
    #      name         symbol      prefix?     definition                  aliases
    #---------------------------------------------------------------------------------------------------------------------------
    define "mps",       "m/s",      false,      "1 m/s",                    "meterPerSecond", "metersPerSecond"
    define "kph",       "km/h",     false,      "1000/3600 m/s",            "kilometerPerHour", "kilometersPerHour"
    define "mph",       "mph",      false,      "5280/3600 ft/s",           "milePerHour", "milesPerHour"
    define "kn",        "kn",       false,      "1852/3600 m/s",            "knot", "knots"
    define "fps",       "ft/s",     false,      "1/3600 ft/s",              "footPerSecond", "feetPerSecond"
    define "mach",      "mach",     false,      "340.29 m/s",               "mach", "machs"

    #---------------------------------------------------------------------------------------------------------------------------
    # Force units (base: N = 1 kg.m/s2)
    #---------------------------------------------------------------------------------------------------------------------------
    #      name         symbol      prefix?     definition                  aliases
    #---------------------------------------------------------------------------------------------------------------------------
    define "N",         "N",        true,       "1 kg.m/s2",                "newton", "newtons"
    define "dyn",       "dyn",      false,      "1e-5 N",                   "dyne", "dynes"
    define "lbf",       "lbf",      false,      "4.44822 N",                "poundsForce"
    define "kgf",       "kgf",      false,      "9.80665 N",                "kilogramsForce"
    define "pdl",       "pdl",      false,      "1 lb.ft/s2",               "poundal", "poundals"

    #---------------------------------------------------------------------------------------------------------------------------
    # Pressure units (base: Pa = 1 N/m2)
    #---------------------------------------------------------------------------------------------------------------------------
    #      name         symbol      prefix?     definition                  aliases
    #---------------------------------------------------------------------------------------------------------------------------
    define "Pa",        "Pa",       true,       "1 N/m2",                   "pascal", "pascals"
    define "atm",       "atm",      false,      "101325 Pa",                "atmosphere", "atmospheres"
    define "bar",       "bar",      true,       "100000 Pa",                "bar", "bars"
    define "mmHg",      "mmHg",     false,      "133.3223684 Pa",           "millimeterOfMercury", "millimetersOfMercury"
    define "psi",       "psi",      false,      "6894.757293 Pa",           "poundPerSquareInch", "poundsPerSquareInch"
    define "Torr",      "Torr",     false,      "133.3223684 Pa",           "torr", "torrs"

    #---------------------------------------------------------------------------------------------------------------------------
    # Energy units (base: J = 1 N.m)
    #---------------------------------------------------------------------------------------------------------------------------
    #      name         symbol      prefix?     definition                  aliases
    #---------------------------------------------------------------------------------------------------------------------------
    define "J",         "J",        true,       "1 N.m",                    "joule", "joules"
    define "cal",       "cal",      true,       "4.184 J",                  "calorie", "calories"
    define "BTU",       "BTU",      false,      "1055.05585262 J",          "britishThermalUnit", "britishThermalUnits"
    define "eV",        "eV",       true,       "1.602176565e-19 J",        "electronVolt", "electronVolts"
    define "erg",       "erg",      false,      "1e-7 J",                   "erg", "ergs"

    #---------------------------------------------------------------------------------------------------------------------------
    # Power units (base: W = 1 J/s)
    #---------------------------------------------------------------------------------------------------------------------------
    #      name         symbol      prefix?     definition                  aliases
    #---------------------------------------------------------------------------------------------------------------------------
    define "W",         "W",        true,       "1 J/s",                    "watt", "watts"
    define "hp",        "hp",       false,      "745.69987158227 W",        "horsepower"

    #---------------------------------------------------------------------------------------------------------------------------
    # Potential units (base: V = 1 W/A)
    #---------------------------------------------------------------------------------------------------------------------------
    #      name         symbol      prefix?     definition                  aliases
    #---------------------------------------------------------------------------------------------------------------------------
    define "V",         "V",        true,       "1 W/A",                    "volt", "volts"

    #---------------------------------------------------------------------------------------------------------------------------
    # Resistance units (base: Ohm = 1 V/A)
    #---------------------------------------------------------------------------------------------------------------------------
    #      name         symbol      prefix?     definition                  aliases
    #---------------------------------------------------------------------------------------------------------------------------
    define "Ohm",       "Ω",        true,       "1 V/A",                    "ohm", "ohms"

    #---------------------------------------------------------------------------------------------------------------------------
    # Conductance units (base: S = 1 A/V)
    #---------------------------------------------------------------------------------------------------------------------------
    #      name         symbol      prefix?     definition                  aliases
    #---------------------------------------------------------------------------------------------------------------------------
    define "S",         "S",        true,       "1 A/V",                    "siemens"

    #---------------------------------------------------------------------------------------------------------------------------
    # Charge units (base: C = 1 A.s)
    #---------------------------------------------------------------------------------------------------------------------------
    #      name         symbol      prefix?     definition                  aliases
    #---------------------------------------------------------------------------------------------------------------------------
    define "C",         "C",        true,       "1 A.s",                    "coulomb", "coulombs"

    #---------------------------------------------------------------------------------------------------------------------------
    # Capacitance units (base: F = 1 C/V)
    #---------------------------------------------------------------------------------------------------------------------------
    #      name         symbol      prefix?     definition                  aliases
    #---------------------------------------------------------------------------------------------------------------------------
    define "F",         "F",        true,       "1 C/V",                    "farad", "farads"

    #---------------------------------------------------------------------------------------------------------------------------
    # Inductance units (base: H = 1 V.s/A)
    #---------------------------------------------------------------------------------------------------------------------------
    #      name         symbol      prefix?     definition                  aliases
    #---------------------------------------------------------------------------------------------------------------------------
    define "H",         "H",        true,       "1 V.s/A",                  "henry", "henrys"

    #---------------------------------------------------------------------------------------------------------------------------
    # Magnetic flux units (base: Wb = 1 V.s)
    #---------------------------------------------------------------------------------------------------------------------------
    #      name         symbol      prefix?     definition                  aliases
    #---------------------------------------------------------------------------------------------------------------------------
    define "Wb",        "Wb",       true,       "1 V.s",                    "weber", "webers"
    define "Mx",        "Mx",       true,       "1e-8 Wb",                  "maxwell", "maxwells"

    #---------------------------------------------------------------------------------------------------------------------------
    # Magnetic flux density units (base: T = 1 Wb/m2)
    #---------------------------------------------------------------------------------------------------------------------------
    #      name         symbol      prefix?     definition                  aliases
    #---------------------------------------------------------------------------------------------------------------------------
    define "T",         "T",        true,       "1 Wb/m2",                  "tesla", "teslas"
    define "G",         "G",        true,       "1e-4 T",                   "gauss", "gauss"

    #---------------------------------------------------------------------------------------------------------------------------
    # Temperature units (base: K)
    #---------------------------------------------------------------------------------------------------------------------------
    #      name         symbol      prefix?     definition                  aliases
    #---------------------------------------------------------------------------------------------------------------------------
    define "degC",      "°C",       false,      "",                         "celsius"
    define "degF",      "°F",       false,      "",                         "fahrenheit"
    define "degR",      "°R",       false,      "",                         "rankine"

    #---------------------------------------------------------------------------------------------------------------------------
    # Information units (base: B)
    #---------------------------------------------------------------------------------------------------------------------------
    #      name         symbol      prefix?     definition                  aliases
    #---------------------------------------------------------------------------------------------------------------------------
    define "b",         "b",      true,       "1/8 B",                    "bit", "bits"

    #---------------------------------------------------------------------------------------------------------------------------
    # Angle units (base: rad)
    #---------------------------------------------------------------------------------------------------------------------------
    #      name         symbol      prefix?     definition                  aliases
    #---------------------------------------------------------------------------------------------------------------------------
    define "deg",       "°",        false,      "pi/180 rad",               "degree", "degrees"
    define "grad",      "grad",     false,      "pi/200 rad",               "gradian", "gradians"
    define "arcmin",    "'",        false,      "pi/10800 rad",             "arcminute", "arcminutes"
    define "arcsec",    "''",       false,      "pi/648000 rad",            "arcsecond", "arcseconds"

    #---------------------------------------------------------------------------------------------------------------------------
    # Catalytic activity units (base: mol/s)
    #---------------------------------------------------------------------------------------------------------------------------
    #      name         symbol      prefix?     definition                  aliases
    #---------------------------------------------------------------------------------------------------------------------------
    define "kat",       "kat",      true,       "1 mol/s",                  "katal", "katals"

    #---------------------------------------------------------------------------------------------------------------------------
    # Frequency units (base: Hz = 1/s)
    #---------------------------------------------------------------------------------------------------------------------------
    #      name         symbol      prefix?     definition                  aliases
    #---------------------------------------------------------------------------------------------------------------------------
    define "Hz",        "Hz",       true,       "1 1/s",                    "hertz"

    #---------------------------------------------------------------------------------------------------------------------------
    # Radiation units (base: Bq = 1/s)
    #---------------------------------------------------------------------------------------------------------------------------
    #      name         symbol      prefix?     definition                  aliases
    #---------------------------------------------------------------------------------------------------------------------------
    define "Bq",        "Bq",       true,       "1 1/s",                    "becquerel", "becquerels"
    define "Ci",        "Ci",       true,       "3.7e10 Bq",                "curie", "curies"

    #---------------------------------------------------------------------------------------------------------------------------
    # Radiation exposure units (base: Gy = J/kg)
    #---------------------------------------------------------------------------------------------------------------------------
    #      name         symbol      prefix?     definition                  aliases
    #---------------------------------------------------------------------------------------------------------------------------
    define "Gy",        "Gy",       true,       "1 J/kg",                   "gray", "grays"
    define "Sv",        "Sv",       true,       "1 J/kg",                   "sievert", "sieverts"
    define "R",         "R",        true,       "1e-2 Gy",                  "roentgen", "roentgens"

    #---------------------------------------------------------------------------------------------------------------------------
    # Viscosity units (base: Pa.s)
    #---------------------------------------------------------------------------------------------------------------------------
    #      name         symbol      prefix?     definition                  aliases
    #---------------------------------------------------------------------------------------------------------------------------
    define "P",         "P",        true,       "1 dPa.s",                  "poise", "poises"

    #---------------------------------------------------------------------------------------------------------------------------
    # Illuminance units (base: lx = cd/m2)
    #---------------------------------------------------------------------------------------------------------------------------
    #      name         symbol      prefix?     definition                  aliases
    #---------------------------------------------------------------------------------------------------------------------------
    define "lx",        "lx",       true,       "1 cd/m2",                  "lux", "luxes"

#=======================================
# Types
#=======================================

type
    Unit            = getUnits()

    PrefixKind      = getPrefixKinds()
    UnitKind        = getUnitKinds()
    QuantityKind    = getQuantityKinds()

    QuantitySignature = int64

    UnitArray = seq[Unit]
    Units = tuple
        n: UnitArray        # numerator
        d: UnitArray        # denominator

    Quantity = tuple
        original: float     # the original value
        value: float        # the value after conversion to base units
        tp: QuantityKind    # the quantity kind
        units: Units        # the units
        base: bool          # whether the value is a base value

#=======================================
# Constants
#=======================================

const
    BaseUnits = getBaseUnits()
    QuantitySignatures: Table[QuantitySignature, QuantityKind] = getQuantitySignatures()
    Parsables: Table[string, (PrefixKind, Unit)] = getParsables()

    KnownQuantities* = getKnownQuantities()

    # Definitions: Table[(PrefixKind, Unit), Quantity] = getDefinitions()

#=======================================
# Parsers
#=======================================

# func getQuantityType(units: Units): QuantityKind =
#     var vector = newSeq[int64](ord(UnitKind.high) + 1)
#     for unit in units.n:
#         vector[ord(UnitKind[unit])] += 1
#     for unit in units.d:
#         vector[ord(UnitKind[unit])] -= 1

#     for index, item in vector:
#         vector[index] = item * (int(pow(float(20),float(index))))

#     QuantitySignatures.getOrDefault(signature, TUnknown)
#     return getTypeBySignature(vector.foldl(a + b, int64(0)))

# proc newQuantity(v: float, n: UnitArray, d: UnitArray): Quantity =
#     result.original = v
#     result.value = v
#     result.units.n = n
#     result.units.d = d
#     result.base = false

#     var sig = 0
#     for u in n:
#         sig += u.signature
#     for u in d:
#         sig -= u.signature

#     result.tp = QuantitySignatures[sig]

proc parseQuantity(str: string): Quantity =
    proc parsePart(s: string): UnitArray =
        let individ = s.split(".")
        for ind in individ:
            let capts = toSeq(ind.match(re"([A-Za-z]+)(\d+)?").get.captures)

            var reps = 1
            if capts.len > 1 and not capts[1].isNone:
                reps = parseInt(capts[1].get())

            let (prefix, unit) = Parsables[capts[0].get()]
            for i in 0 ..< reps:
                result.add(unit)


    var parts = str.split(" ")
    var num = parts[0]
    var numVal: float
    var units = parts[1]

    echo "HERE"

    # parse the value
    if num.contains("/"):
        let frac = num.split("/")
        numVal = parseFloat(frac[0]) / parseFloat(frac[1])
    else:
        numVal = parseFloat(num)

    # parse the units
    let subparts = units.split("/")
    let numUnits = subparts[0]
    var numUnitsArr, denUnitsArr: UnitArray
    numUnitsArr = parsePart(numUnits)
    echo "zere"
    if subparts.len == 2:
        let denUnits = subparts[1]
        denUnitsArr = parsePart(denUnits)


    (
        original: numVal,
        value: numVal,
        tp: Error_Q,
        units: (numUnitsArr, denUnitsArr),
        base: false
    )


when isMainModule:
    # for i in items(Unit):
    #     echo $i

    # for i in items(UnitKind):
    #     echo $i

    # for i in items(QuantityKind):
    #     echo $i

    # for i in items(PrefixKind):
    #     echo $i

    # echo $(BaseUnits)
    # echo $(QuantitySignatures)
    # echo $(Parsables)

    echo $parseQuantity("1 m")
    echo $parseQuantity("2 m2")
    echo $parseQuantity("3 m/s2")
    echo $parseQuantity("4/5 m/s2")

    echo $(KnownQuantities)