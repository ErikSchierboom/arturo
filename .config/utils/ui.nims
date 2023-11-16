
## Internal Functions
## ------------------

func sep(ch: char = '='): string =
    return "".align(80, ch)

## Public Constants
## ----------------

let
    colors*: tuple = (
        gray: grayColor.fg,
        green: greenColor.bold,
        magenta: magentaColor.fg,
        red: redColor.fg
    )

    styles*: tuple = (
        clear: resetColor(),
        bold: bold()
    )

## Public Functions
## ----------------

proc log*(msg: string) =
    for line in msg.splitlines:
        echo colors.gray, "  " & line.dedent, styles.clear

proc warn*(msg: string) =
    echo colors.red, msg.dedent, styles.clear

proc panic*(msg: string = "", exitCode: int = QuitFailure) =
    warn msg
    quit exitCode

proc showLogo*() =
    echo sep()
    echo r"{colors.green}                 _                                     ".fmt
    echo r"                              | |                                    "
    echo r"                     __ _ _ __| |_ _   _ _ __ ___                    "
    echo r"                    / _` | '__| __| | | | '__/ _ \                   "
    echo r"                   | (_| | |  | |_| |_| | | | (_) |                  "
    echo r"                    \__,_|_|   \__|\__,_|_|  \___/                   "
    echo r"{styles.clear}{styles.bold}                                          ".fmt
    echo r"                     Arturo Programming Language{styles.clear}       ".fmt
    echo r"                      (c)2023 Yanis Zafirópulos                      "
    echo r"                                                                     "

proc showHeader*(title: string) =
    echo sep()
    echo fmt" ► {title.toUpperAscii()}"
    echo sep()

proc section*(title: string) =
    echo fmt"{styles.clear}"
    echo sep('-')
    echo fmt" {colors.magenta}●{styles.clear} {title}"
    echo sep('-')

proc showFooter*() =
    echo fmt"{styles.clear}"
    echo sep()
    echo fmt" {colors.magenta}●{styles.clear}{colors.green} Awesome!{styles.clear}"
    echo sep()
    echo "   Arturo has been successfully built & installed!"
    if hostOS != "windows":
        echo ""
        echo "   To be able to run it,"
        echo "   first make sure its in your $PATH:"
        echo ""
        echo "          export PATH=$HOME/.arturo/bin:$PATH"
        echo ""
        echo fmt"   and add it to your {getShellRc()},"
        echo "   so that it's set automatically every time."
    echo ""
    echo "   Rock on! :)"
    echo sep()
    echo fmt"{styles.clear}"

proc showEnvironment*() =
    section "Checking environment..."

    log fmt"os: {hostOS}"
    log fmt"compiler: Nim v{NimVersion}"

proc showBuildInfo*(config: BuildConfig) =
    let
        params = flags.join(" ")
        version = "version/version".staticRead()
        build = "version/build".staticRead()

    section "Building..."
    log fmt"version: {version}/{build}"
    log fmt"config: {config.version}"

    if not config.silentCompilation:
        log fmt"flags: {params}"