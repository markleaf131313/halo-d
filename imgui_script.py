import argparse
import regex

parser = argparse.ArgumentParser()
parser.add_argument('files', metavar='file', type=str, nargs='+')

args = parser.parse_args()


def replaceMatchesVec2(m):
    return m.group(1) + '{' + m.group(2)[1:-1] + '}' + (m.group(3) if len(m.groups()) >= 3 else '')
def replaceMatchesVec4(m):
    return 'ImVec4{' + m.group(2)[1:-1] + '}'

for fileName in args.files:
    data = open(fileName, "r").read()

    data = regex.sub(r'(ImVec2)(\((?:[^()]++|(?2))*\))', replaceMatchesVec2, data)
    data = regex.sub(r'(ImVec4)(\((?:[^()]++|(?2))*\))', replaceMatchesVec2, data)

    data = regex.sub(r'(ImVec2[\s][\w]+)(\((?:[^()]++|(?2))*\))(;)', replaceMatchesVec2, data)
    data = regex.sub(r'(ImVec4[\s][\w]+)(\((?:[^()]++|(?2))*\))(;)', replaceMatchesVec2, data)

    open("out_" + fileName, "w").write(data)


