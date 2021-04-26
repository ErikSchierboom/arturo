######################################################
# Arturo
# Programming Language + Bytecode VM compiler
# (c) 2019-2021 Yanis Zafirópulos
#
# @file: library/Path.nim
######################################################

#=======================================
# Pragmas
#=======================================

{.used.}

#=======================================
# Libraries
#=======================================

when not defined(WEB):
    import os, sequtils, sugar

    import helpers/path
    import helpers/url

import vm/lib
import vm/[env]
when defined(SAFE):
    import vm/[errors]

#=======================================
# Methods
#=======================================

proc defineSymbols*() =

    when defined(VERBOSE):
        echo "- Importing: Paths"

    when not defined(WEB):

        builtin "extract",
            alias       = unaliased, 
            rule        = PrefixPrecedence,
            description = "extract components from path",
            args        = {
                "path"  : {String}
            },
            attrs       = {
                "directory" : ({Boolean},"get path directory"),
                "basename"  : ({Boolean},"get path basename (filename+extension)"),
                "filename"  : ({Boolean},"get path filename"),
                "extension" : ({Boolean},"get path extension"),
                "scheme"    : ({Boolean},"get scheme field from URL"),
                "host"      : ({Boolean},"get host field from URL"),
                "port"      : ({Boolean},"get port field from URL"),
                "user"      : ({Boolean},"get user field from URL"),
                "password"  : ({Boolean},"get password field from URL"),
                "path"      : ({Boolean},"get path field from URL"),
                "query"     : ({Boolean},"get query field from URL"),
                "anchor"    : ({Boolean},"get anchor field from URL")
            },
            returns     = {String,Dictionary},
            example     = """
                path: "/this/is/some/path.txt"

                print extract.directory path        ; /this/is/some
                print extract.basename path         ; path.txt
                print extract.filename path         ; path
                print extract.extension path        ; .txt

                print extract path 
                ; [directory:/this/is/some basename:path.txt filename:path extension:.txt]

                url: "http://subdomain.website.com:8080/path/to/file.php?q=something#there"

                print extract.scheme url            ; http
                print extract.host url              ; subdomain.website.com
                print extract.port url              ; 8080
                print extract.user url              ; 
                print extract.password url          ;
                print extract.path url              ; /path/to/file.php
                print extract.query url             ; q=something
                print extract.anchor url            ; there

                print extract url
                ; [scheme:http host:subdomain.website.com port:8080 user: password: path:/path/to/file.php query:q=something anchor:there]

            """:
                ##########################################################
                if isUrl(x.s):
                    let details = parseUrlComponents(x.s)

                    if (popAttr("scheme") != VNULL):
                        push(details["scheme"])
                    elif (popAttr("host") != VNULL):
                        push(details["host"])
                    elif (popAttr("port") != VNULL):
                        push(details["port"])
                    elif (popAttr("user") != VNULL):
                        push(details["user"])
                    elif (popAttr("password") != VNULL):
                        push(details["password"])
                    elif (popAttr("path") != VNULL):
                        push(details["path"])
                    elif (popAttr("query") != VNULL):
                        push(details["query"])
                    elif (popAttr("anchor") != VNULL):
                        push(details["anchor"])
                    else:
                        push(newDictionary(details))
                else:
                    let details = parsePathComponents(x.s)

                    if (popAttr("directory") != VNULL):
                        push(details["directory"])
                    elif (popAttr("basename") != VNULL):
                        push(details["basename"])
                    elif (popAttr("filename") != VNULL):
                        push(details["filename"])
                    elif (popAttr("extension") != VNULL):
                        push(details["extension"])
                    else:
                        push(newDictionary(details))

        builtin "list",
            alias       = unaliased, 
            rule        = PrefixPrecedence,
            description = "get files in given path",
            args        = {
                "path"  : {String}
            },
            attrs       = {
                "recursive" : ({Boolean}, "perform recursive search"),
                "relative"  : ({Boolean}, "get relative paths"),
            },
            returns     = {Block},
            example     = """
                loop list "." 'file [
                ___print file
                ]
                
                ; tests
                ; var
                ; data.txt
            """:
                ##########################################################
                when defined(SAFE): RuntimeError_OperationNotPermitted("list")
                let recursive = (popAttr("recursive") != VNULL)
                let relative = (popAttr("relative") != VNULL)
                let path = x.s

                var contents: seq[string]

                if recursive:
                    contents = toSeq(walkDirRec(path, relative = relative))
                else:
                    contents = toSeq(walkDir(path, relative = relative)).map((x) => x[1])

                push(newStringBlock(contents))

        builtin "module",
            alias       = unaliased, 
            rule        = PrefixPrecedence,
            description = "get path for given module name",
            args        = {
                "name"  : {String,Literal}
            },
            attrs       = NoAttrs,
            returns     = {String,Null},
            example     = """
                print module 'html        ; /usr/local/lib/arturo/html.art
                
                do.import module 'html    ; (imports given module)
            """:
                ##########################################################
                push(newString(HomeDir & ".arturo/lib/" & x.s & ".art"))
        
        builtin "normalize",
            alias       = dotslash, 
            rule        = PrefixPrecedence,
            description = "get normalized version of given path",
            args        = {
                "path"  : {String,Literal}
            },
            attrs       = {
                "executable"    : ({Boolean},"treat path as executable"),
                "tilde"         : ({Boolean},"expand tildes in path")
            },
            returns     = {String,Nothing},
            example     = """
                normalize "one/../two/../../three"
                ; => ../three

                normalize "~/one/../two/../../three"
                ; => three

                normalize.tilde "~/one/../two/../../three"
                ; => /Users/three

                normalize.tilde "~/Documents"
                ; => /Users/drkameleon/Documents

                normalize.executable "myscript"
                ; => ./myscript          
            """:
                ##########################################################
                if (popAttr("executable") != VNULL):
                    if x.kind==Literal:
                        if (popAttr("tilde") != VNULL):
                            InPlace.s = InPlaced.s.expandTilde()
                        InPlace.s.normalizeExe()
                    else:
                        var ret: string
                        if (popAttr("tilde") != VNULL):
                            ret = x.s.expandTilde()
                        else:
                            ret = x.s
                        ret.normalizeExe()
                        push(newString(ret))
                else:
                    if x.kind==Literal:
                        if (popAttr("tilde") != VNULL):
                            InPlace.s = InPlaced.s.expandTilde()
                        InPlace.s.normalizePath()
                    else:
                        if (popAttr("tilde") != VNULL):
                            push(newString(normalizedPath(x.s.expandTilde())))
                        else:
                            push(newString(normalizedPath(x.s)))

        constant "path",
            alias       = unaliased,
            description = "common path constants":
                newDictionary(getPathInfo())

        builtin "relative",
            alias       = dotslash, 
            rule        = PrefixPrecedence,
            description = "get relative path for given path, based on current script's location",
            args        = {
                "path"  : {String}
            },
            attrs       = NoAttrs,
            returns     = {String},
            example     = """
                ; we are in folder: /Users/admin/Desktop
                
                print relative "test.txt"
                ; /Users/admin/Desktop/test.txt
            """:
                ##########################################################
                push(newString(joinPath(env.currentPath(),x.s)))

#=======================================
# Add Library
#=======================================

Libraries.add(defineSymbols)