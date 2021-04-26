######################################################
# Arturo
# Programming Language + Bytecode VM compiler
# (c) 2019-2021 Yanis Zafirópulos
#
# @file: library/Files.nim
######################################################

#=======================================
# Pragmas
#=======================================

{.used.}

#=======================================
# Libraries
#=======================================

when not defined(WEB):

    import os, sequtils

    when not defined(NOPARSERS):
        import sugar
        import extras/miniz
        
        import helpers/html
        import helpers/markdown
        import helpers/toml

    import helpers/csv
    import helpers/datasource
    import helpers/jsonobject

import vm/lib
when defined(SAFE):
    import vm/[errors]

#=======================================
# Methods
#=======================================

proc defineSymbols*() =

    when defined(VERBOSE):
        echo "- Importing: Files"

    when not defined(WEB):

        builtin "copy",
            alias       = unaliased, 
            rule        = PrefixPrecedence,
            description = "copy file at path to given destination",
            args        = {
                "file"          : {String},
                "destination"   : {String}
            },
            attrs       = {
                "directory" : ({Boolean},"path is a directory")
            },
            returns     = {Nothing},
            example     = """
                copy "testscript.art" normalize.tilde "~/Desktop/testscript.art"
                ; copied file

                copy "testfolder" normalize.tilde "~/Desktop/testfolder"
                ; copied whole folder
            """:
                ##########################################################
                when defined(SAFE): RuntimeError_OperationNotPermitted("copy")

                var target = y.s
                if (popAttr("directory") != VNULL): 
                    try:
                        copyDirWithPermissions(x.s, move target)
                    except OSError:
                        discard
                else: 
                    try:
                        copyFileWithPermissions(x.s, move target)
                    except OSError:
                        discard

        builtin "delete",
            alias       = unaliased, 
            rule        = PrefixPrecedence,
            description = "delete file at given path",
            args        = {
                "file"  : {String}
            },
            attrs       = {
                "directory" : ({Boolean},"path is a directory")
            },
            returns     = {Nothing},
            example     = """
                delete "testscript.art"
                ; file deleted
            """:
                ##########################################################
                when defined(SAFE): RuntimeError_OperationNotPermitted("delete")
                
                if (popAttr("directory") != VNULL): 
                    try:
                        removeDir(x.s)
                    except OSError:
                        discard
                else: 
                    discard tryRemoveFile(x.s)

        builtin "exists?",
            alias       = unaliased, 
            rule        = PrefixPrecedence,
            description = "check if given file exists",
            args        = {
                "file"  : {String}
            },
            attrs       = {
                "directory" : ({Boolean},"check for directory")
            },
            returns     = {Boolean},
            example     = """
                if exists? "somefile.txt" [ 
                    print "file exists!" 
                ]
            """:
                ##########################################################
                if (popAttr("directory") != VNULL): 
                    push(newBoolean(dirExists(x.s)))
                else: 
                    push(newBoolean(fileExists(x.s)))

        builtin "permissions",
            alias       = unaliased, 
            rule        = PrefixPrecedence,
            description = "check permissions of given file",
            args        = {
                "file"  : {String}
            },
            attrs       = {
                "set"   : ({Dictionary},"set using given file permissions")
            },
            returns     = {Dictionary,Null},
            example     = """
                inspect permissions "bin/arturo"
                ; [ :dictionary
                ;     user    :	[ :dictionary
                ;         read     :		true :boolean
                ;         write    :		true :boolean
                ;         execute  :		true :boolean
                ;     ]
                ;     group   :	[ :dictionary
                ;         read     :		true :boolean
                ;         write    :		false :boolean
                ;         execute  :		true :boolean
                ;     ]
                ;     others  :	[ :dictionary
                ;         read     :		true :boolean
                ;         write    :		false :boolean
                ;         execute  :		true :boolean
                ;     ]
                ; ]

                permissions.set:#[others:#[write:true]] "bin/arturo"
                ; gave write permission to 'others'
            """:
                ##########################################################
                when defined(SAFE): RuntimeError_OperationNotPermitted("permissions")
                try:
                    if (popAttr("set") != VNULL):
                        var source = x.s
                        var perms: set[FilePermission]

                        if x.d.hasKey("user") and x.d["user"].d.hasKey("read"): perms.incl(fpUserRead)
                        if x.d.hasKey("user") and x.d["user"].d.hasKey("write"): perms.incl(fpUserWrite)
                        if x.d.hasKey("user") and x.d["user"].d.hasKey("execute"): perms.incl(fpUserExec)

                        if x.d.hasKey("group") and x.d["group"].d.hasKey("read"): perms.incl(fpGroupRead)
                        if x.d.hasKey("group") and x.d["group"].d.hasKey("write"): perms.incl(fpGroupWrite)
                        if x.d.hasKey("group") and x.d["group"].d.hasKey("execute"): perms.incl(fpGroupExec)

                        if x.d.hasKey("others") and x.d["others"].d.hasKey("read"): perms.incl(fpOthersRead)
                        if x.d.hasKey("others") and x.d["others"].d.hasKey("write"): perms.incl(fpOthersWrite)
                        if x.d.hasKey("others") and x.d["others"].d.hasKey("execute"): perms.incl(fpOthersExec)

                        setFilePermissions(move source, move perms)
                    else:
                        let perms = getFilePermissions(x.s)
                        var permsDict: ValueDict = {
                            "user": newDictionary({
                                "read"      : newBoolean(fpUserRead in perms),
                                "write"     : newBoolean(fpUserWrite in perms),
                                "execute"   : newBoolean(fpUserExec in perms)
                            }.toOrderedTable),
                            "group": newDictionary({
                                "read"      : newBoolean(fpGroupRead in perms),
                                "write"     : newBoolean(fpGroupWrite in perms),
                                "execute"   : newBoolean(fpGroupExec in perms)
                            }.toOrderedTable),
                            "others": newDictionary({
                                "read"      : newBoolean(fpOthersRead in perms),
                                "write"     : newBoolean(fpOthersWrite in perms),
                                "execute"   : newBoolean(fpOthersExec in perms)
                            }.toOrderedTable)
                        }.toOrderedTable

                        push(newDictionary(permsDict))

                except OSError:
                    push(VNULL)

        builtin "read",
            alias       = doublearrowleft, 
            rule        = PrefixPrecedence,
            description = "read file from given path",
            args        = {
                "file"  : {String}
            },
            attrs       = 
                when not defined(NOPARSERS): 
                    {
                        "lines"         : ({Boolean},"read file lines into block"),
                        "json"          : ({Boolean},"read Json into value"),
                        "csv"           : ({Boolean},"read CSV file into a block of rows"),
                        "withHeaders"   : ({Boolean},"read CSV headers"),
                        "html"          : ({Boolean},"read HTML file into node dictionary"),
                        "markdown"      : ({Boolean},"read Markdown and convert to HTML"),
                        "toml"          : ({Boolean},"read TOML into value"),
                        "binary"        : ({Boolean},"read as binary")
                    }
                else:
                    {
                        "lines"         : ({Boolean},"read file lines into block"),
                        "json"          : ({Boolean},"read Json into value"),
                        "csv"           : ({Boolean},"read CSV file into a block of rows"),
                        "withHeaders"   : ({Boolean},"read CSV headers"),
                        "binary"        : ({Boolean},"read as binary")
                    },
            returns     = {String,Block,Binary},
            example     = """
                ; reading a simple local file
                str: read "somefile.txt"

                ; also works with remote urls
                page: read "http://www.somewebsite.com/page.html"

                ; we can also "read" JSON data as an object
                data: read.json "mydata.json"

                ; or even convert Markdown to HTML on-the-fly
                html: read.markdown "## Hello"     ; "<h2>Hello</h2>"
            """:
                ##########################################################
                if (popAttr("binary") != VNULL):
                    var f: File
                    discard f.open(x.s)
                    var b: seq[byte] = newSeq[byte](f.getFileSize())
                    discard f.readBytes(b, 0, f.getFileSize())

                    f.close()

                    push(newBinary(b))
                else:
                    let (src, _{.inject.}) = getSource(x.s)

                    if (popAttr("lines") != VNULL):
                        push(newStringBlock(src.splitLines()))
                    elif (popAttr("json") != VNULL):
                        push(valueFromJson(src))
                    elif (popAttr("csv") != VNULL):
                        push(parseCsvInput(src, withHeaders=(popAttr("withHeaders")!=VNULL)))
                    else:
                        when not defined(NOPARSERS):
                            if (popAttr("toml") != VNULL):
                                push(parseTomlString(src))
                            elif (popAttr("markdown") != VNULL):
                                push(parseMarkdownInput(src))
                            elif (popAttr("html") != VNULL):
                                push(parseHtmlInput(src))
                            else:
                                push(newString(src))
                        else:
                            push(newString(src))
                            
                    # elif attrs.hasKey("xml"):
                    #     push(parseXmlNode(parseXml(action(x.s))))

        builtin "rename",
            alias       = unaliased, 
            rule        = PrefixPrecedence,
            description = "rename file at path using given new path name",
            args        = {
                "file"  : {String},
                "name"  : {String}
            },
            attrs       = {
                "directory" : ({Boolean},"path is a directory")
            },
            returns     = {Nothing},
            example     = """
                rename "README.md" "READIT.md"
                ; file renamed
            """:
                ##########################################################
                when defined(SAFE): RuntimeError_OperationNotPermitted("rename")
                var source = x.s
                var target = y.s
                if (popAttr("directory") != VNULL): 
                    try:
                        moveDir(move source, move target)
                    except OSError:
                        discard
                else: 
                    try:
                        moveFile(move source, move target)
                    except OSError:
                        discard

        builtin "symlink",
            alias       = unaliased, 
            rule        = PrefixPrecedence,
            description = "create symbolic link of file to given destination",
            args        = {
                "file"          : {String},
                "destination"   : {String}
            },
            attrs       = {
                "hard"  : ({Boolean},"create a hard link")
            },
            returns     = {Nothing},
            example     = """
                symlink relative "arturo/README.md" 
                        "/Users/drkameleon/Desktop/gotoREADME.md"
                ; creates a symbolic link to our readme file
                ; in our desktop

                symlink.hard relative "arturo/README.md" 
                        "/Users/drkameleon/Desktop/gotoREADME.md"
                ; hard-links (effectively copies) our readme file
                ; to our desktop
            """:
                ##########################################################
                when defined(SAFE): RuntimeError_OperationNotPermitted("symlink")
                var source = x.s
                var target = y.s
                try:
                    if (popAttr("hard") != VNULL):
                        createHardlink(move source, move target)
                    else:
                        createSymlink(move source, move target)
                except OSError:
                    discard
                        
        when not defined(NOUNZIP):
            builtin "unzip",
                alias       = unaliased, 
                rule        = PrefixPrecedence,
                description = "unzip given archive to destination",
                args        = {
                    "destination"   : {String},
                    "original"      : {String}
                },
                attrs       = NoAttrs,
                returns     = {Nothing},
                example     = """
                    unzip "folder" "archive.zip"
                """:
                    ##########################################################
                    miniz.unzip(y.s, x.s)

        builtin "write",
            alias       = doublearrowright, 
            rule        = PrefixPrecedence,
            description = "write content to file at given path",
            args        = {
                "file"      : {String,Null},
                "content"   : {Any}
            },
            attrs       = {
                "directory"     : ({Boolean},"create directory at path"),
                "json"          : ({Boolean},"write value as Json"),
                "binary"        : ({Boolean},"write as binary")
            },
            returns     = {Nothing},
            example     = """
                ; write some string data to given file path
                write "somefile.txt" "Hello world!"

                ; we can also write any type of data as JSON
                write.json "data.json" myData
            """:
                ##########################################################
                when defined(SAFE): RuntimeError_OperationNotPermitted("write")
                if (popAttr("directory") != VNULL):
                    createDir(x.s)
                else:
                    if (popAttr("binary") != VNULL):
                        var f: File
                        discard f.open(x.s, mode=fmWrite)
                        discard f.writeBytes(y.n, 0, y.n.len)

                        f.close()
                    else:
                        if (popAttr("json") != VNULL):
                            let rez = jsonFromValue(y)
                            if x.kind==String:
                                writeFile(x.s, rez)
                            else:
                                push(newString(rez))
                        else:
                            writeFile(x.s, y.s)

        when not defined(NOUNZIP):
            builtin "zip",
                alias       = unaliased, 
                rule        = PrefixPrecedence,
                description = "zip given files to file at destination",
                args        = {
                    "destination"   : {String},
                    "files"         : {Block}
                },
                attrs       = NoAttrs,
                returns     = {Nothing},
                example     = """
                    zip "dest.zip" ["file1.txt" "img.png"]
                """:
                    ##########################################################
                    let files: seq[string] = y.a.map((z)=>z.s)
                    miniz.zip(files, x.s)

#=======================================
# Add Library
#=======================================

Libraries.add(defineSymbols)