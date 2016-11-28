
import json
import os
import struct

tags = dict()
enums = []
outDir = "../runtime/source/Game/Tags/Generated/"

basicTypeName = {
    "string": "TagString",
    "byte": "byte",
    "short": "short",
    "int": "int",
    "angle": "float",
    "tag": "int",
    "vec2 short": "Vec2s",
    "rect2 short": "short[4]",
    "rgb8": "ColorRgb8",
    "rgba8": "ColorArgb8",
    "float": "float",
    "fraction": "float",
    "point2": "Vec2",
    "point3": "Vec3",
    "vec2": "Vec2",
    "vec3": "Vec3",
    "quat": "Quat",
    "angles2": "float[2]",
    "angles3": "float[3]",
    "plane2": "Plane2",
    "plane3": "Plane3",
    "rgbf": "ColorRgb",
    "rgbaf": "ColorArgb",

    # hsv
    # hsva

    "bound short": "TagBounds!short",
    "bound angle": "TagBounds!float",
    "bound float": "TagBounds!float",
    "bound fraction": "TagBounds!float",
    "index16": "short",
    "index32": "int",

    "tagref": "TagRef",
    "data": "TagData",

    "datum index": "DatumIndex"

}

def TypeStrToInt(type):
    values = [elem.encode("ascii") for elem in type]
    return struct.unpack("I", struct.pack("cccc", *reversed(values)))[0]

def IsCharAny(ch, chars):
    for v in chars:
        if ch == v:
            return True
    return False

def FormatClassVarName(name):
    result = ""
    capitalize = False

    for c in name.lower():
        if IsCharAny(c, " .,=/\"_'[]()-+"):
            if c != "'":
                capitalize = True
        else:
            if capitalize:
                capitalize = False
                result += c.upper()
            else:
                result += c

    if len(result) != 0 and result[0].isnumeric():
        result = "_" + result


    return result

def FormatClassTypeName(name):
    result = FormatClassVarName(name)
    result = result[0].upper() + result[1:]
    return result

def FormatEnumTypeName(name):
    return FormatClassTypeName(name)

def FormatEnumFieldName(name):
    return FormatClassVarName(name)

def PrintFields(out, fields, tabs):
    padCount = 0
    nomadCount = 0
    arrayCount = 0

    fieldNameMap = {}

    for f in fields:
        ftype = f["type"]

        if "name" in f:
            fieldName = FormatClassVarName(f["name"])
        else:
            fieldName = ""

        if len(fieldName) == 0:
            fieldName = "nomad" + str(nomadCount)
            nomadCount += 1
        elif fieldName in fieldNameMap:
            if ftype != "explanation":
                fieldNameMap[fieldName] += 1
                fieldName += str(fieldNameMap[fieldName])
        else:
            fieldNameMap[fieldName] = 0

        if fieldName == "function":
            fieldName = "func"
        elif fieldName == "version":
            fieldName = "ver"

        if "comment" in f:
            out.write(tabs + "@TagField(")
            out.write( json.dumps(f["comment"]))
            out.write(")")
            out.write("\n")


        if ftype == "enum":
            enumName = enums[f["index"]]["name"]

            if enumName[0:4] == "enum":
                typeName = "short"
            else:
                typeName = FormatEnumTypeName(enumName)

            out.write(tabs + typeName + " " + fieldName + ";\n")
        elif ftype == "flag8" or ftype == "flag16" or ftype == "flag32":
            num = int(ftype[4:])

            flags = f["flags"]

            out.write("\n")
            out.write(tabs + "align(1) struct Impl" + FormatClassTypeName(fieldName) + "\n")
            out.write(tabs + "{\n")
            out.write(tabs + "    import std.bitmanip : bitfields;\n")
            out.write(tabs + "    mixin(bitfields!(\n")

            flagNames = {}

            for flag in flags:
                flagName = FormatClassVarName(flag["name"])

                if flagName in flagNames:
                    flagNum = flagNames[flagName]
                    flagNames[flagName] += 1
                    flagName += str(flagNum)
                else:
                    flagNames[flagName] = 1

                out.write(tabs + "        bool, \"" + flagName + "\", 1,\n")

            out.write(tabs + "        int, \"\", " + str(num - len(flags)) + "));\n")
            out.write(tabs + "}\n\n")

            out.write(tabs + "Impl" + FormatClassTypeName(fieldName) + " " + fieldName + ";\n")
        elif ftype == "pad":
            out.write(tabs + "mixin TagPad!" + str(f["size"]) + ";\n")
        elif ftype == "block":
            out.write(tabs + "TagBlock!" + FormatClassTypeName(f["block_name"]) + " " + fieldName + ";\n")
        elif ftype == "explanation":
            continue
        elif ftype == "array":
            out.write(tabs + "struct SubField" + str(arrayCount) + "\n" + tabs + "{\n")

            PrintFields(out, f["fields"], tabs + "    ")

            out.write(tabs + "}\n\n")
            out.write(tabs + "SubField" + str(arrayCount) + "[" + str(f["size"]) + "] " + fieldName + ";\n")

            arrayCount += 1

        elif ftype in basicTypeName:
            out.write(tabs + basicTypeName[ftype] + " " + fieldName + ";\n")
        else:
            raise Exception("Can't format for field type " + ftype + ".")

def PrintBlocks(out, blocks, tag, root = False):
    for b in blocks:
        if root and tag != None and b["name"] == tag["name"]:
            className = "Tag" + FormatClassTypeName(b["name"])
            out.write("struct " + className + "\n{\n")

            if "parent" in tag:
                firstParent = tags[tag["parent"]]
                parentClassName = "Tag" + FormatClassTypeName(firstParent["name"])
                parentVarName   = FormatClassVarName(firstParent["name"])

                out.write("    static assert(" + className + ".sizeof - " + parentClassName + ".sizeof == " + str(b["sizeof"]) + ");\n\n")
                out.write("    alias " + parentVarName + " this;\n\n")
                out.write("    " + parentClassName + " " + parentVarName + ";\n")

            else:
                out.write("    static assert(" + className + ".sizeof == " + str(b["sizeof"]) + ");\n\n")

            out.write("    @disable this();\n")
            out.write("    @disable this(this);\n\n")
            out.write("    static if(is(typeof(Game.Tags.Funcs." + className + "))) mixin Game.Tags.Funcs." + className + ";\n\n")
        elif root == False:
            if tag != None and b["name"] == tag["name"]:
                continue

            className = FormatClassTypeName(b["name"])

            out.write("struct " + className + "\n{\n")
            out.write("    static assert(" + className + ".sizeof == " + str(b["sizeof"]) + ");\n\n")
            out.write("    @disable this();\n")
            out.write("    @disable this(this);\n\n")
            out.write("    static if(is(typeof(Game.Tags.Funcs." + className + "))) mixin Game.Tags.Funcs." + className + ";\n\n")
        else:
            continue

        PrintFields(out, b["fields"], "    ")
        out.write("}\n\n")

# -----------------------------------------------------------------------------

with open("def/enums.json") as file:
    root = json.load(file)
    enums = root["enums"]

    with open(outDir + "Enums.d", "w") as out:
        out.write("module Game.Tags.Generated.Enums;\n\n")

        for e in enums:

            if e["name"][0:4] == "enum":
                continue

            out.write("enum " + FormatEnumTypeName(e["name"]) + " : short\n{\n")

            nomad = 0

            for v in e["values"]:
                name = v["name"]

                if len(name) == 0:
                    out.write("    nomad" + str(nomad) + ",\n")
                    nomad += 1
                else:
                    out.write("    " + FormatEnumFieldName(name) + ",\n")

            out.write("}\n\n")

# -----------------------------------------------------------------------------

for filename in os.listdir(os.getcwd() + "/def/"):
    with open("def/" + filename, "r") as file:
        root = json.load(file)

        if filename == "enums.json":
            continue
        elif filename == "common_blocks.json":
            with open(outDir + "Blocks.d", "w") as out:
                out.write("\nmodule Game.Tags.Generated.Blocks;\n\n")

                out.write("public import Game.Tags.Types;\nimport Game.Tags.Generated.Enums;\n\n")

                PrintBlocks(out, root["blocks"], None)
        else:
            tags[root["type"]] = root

# -----------------------------------------------------------------------------

with open(outDir + "Tags.d", "w") as out:
    out.write("\nmodule Game.Tags.Generated.Tags;\n\n")

    for key, tag in tags.items():
        out.write("public import Game.Tags.Generated." + FormatClassTypeName(tag["name"]) + ";\n")


# -----------------------------------------------------------------------------

for key, tag in tags.items():
    with open(outDir + FormatClassTypeName(tag["name"]) + ".d", "w") as out:
        out.write("\nmodule Game.Tags.Generated." + FormatClassTypeName(tag["name"]) + ";\n\n")

        out.write("import Game.Tags.Generated.Blocks;\n")
        out.write("import Game.Tags.Generated.Enums;\n")
        out.write("import Game.Tags.Types;\n")
        out.write("private static import Game.Tags.Funcs;\n")

        out.write("import Game.Tags.Generated." + FormatClassTypeName(tag["name"]) + "_Blocks;\n\n")

        if "parent" in tag:
            firstParent = tags[tag["parent"]]
            out.write("public import Game.Tags.Generated." + FormatClassTypeName(firstParent["name"]) + ";\n")

        out.write("\n\n")

        PrintBlocks(out, tag["blocks"], tag, True)

    with open(outDir + FormatClassTypeName(tag["name"]) + "_Blocks.d", "w") as out:
        out.write("\nmodule Game.Tags.Generated." + FormatClassTypeName(tag["name"]) + "_Blocks;\n\n")

        out.write("import Game.Tags.Generated.Blocks;\n")
        out.write("import Game.Tags.Generated.Enums;\n")
        out.write("import Game.Tags.Types;\n\n")
        out.write("private static import Game.Tags.Funcs;\n")

        PrintBlocks(out, tag["blocks"], tag)

# -----------------------------------------------------------------------------

with open(outDir + "package.d", "w") as out:
    out.write("\nmodule Game.Tags.Generated;\n\n")
    out.write("public import Game.Tags.Generated.Blocks;\n\n")

    for key, tag in tags.items():
        out.write("public import Game.Tags.Generated." + FormatClassTypeName(tag["name"]) + "_Blocks;\n")

with open(outDir + "Meta.d", "w") as out:
    out.write("\nmodule Game.Tags.Generated.Meta;\n\n")
    out.write("import Game.Core.Misc : multichar;\n\n")
    out.write("enum TagId : uint\n")
    out.write("{\n")

    longestNameLength = 0

    for key, tag in tags.items():
        longestNameLength = max(longestNameLength, len(FormatClassVarName(tag["name"])))

    for tag in sorted(tags.values(), key=lambda x: FormatClassVarName(x["name"]) ):
        formattedName = FormatClassVarName(tag["name"])
        formattedNameLength = len(formattedName)
        out.write("    " + FormatClassVarName(tag["name"]))

        for i in range(0, max(0, longestNameLength - formattedNameLength)):
            out.write(" ")

        out.write(" = multichar!\"" + tag["type"] + "\",\n")

    out.write("}\n")
