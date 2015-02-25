import std.stdio;
import std.json;
import std.file;
import std.conv;

import triff;

void printUsage(string appName)
{
    writeln("Usage:\n  " ~ appName ~ " JSON_SRC JSON_DST\n"
      ~ "  Compares two json files and returns list of"
      ~ " operations to transform JSON_SRC into JSON_DST.");
}

class JsonNode
{
    enum Type
    {
        NO_TYPE = 0,
        VALUE,
        OBJECT,
        ARRAY,
    }

    Type _type;
    string _path;
    string _data;
    JsonNode[] _children;

    string label() const
    {
        return to!string(_type) ~ _data;
    }

    auto children() const
    {
        return _children;
    }

    void print(int depth = 0) const
    {
        foreach (i; 0..depth)
        {
            write(" - ");
        }
        writeln(_path ~ " : " ~ _data);
        foreach (c; _children)
        {
            c.print(depth + 1);
        }
    }

}

void makeRecursive(JsonNode node, string path, string name, const(JSONValue) v)
{
    node._path = path;
    node._data = name;
    if (v.type() == v.type().ARRAY)
    {
        node._type = node._type.ARRAY;
        auto arr = v.array();
        foreach (i, a; arr)
        {
            auto c = new JsonNode;
            node._children ~= c;
            makeRecursive(c, path ~ "[" ~ to!string(i) ~ "]", to!string(i), a);
        }
    } 
    else if (v.type() == v.type().OBJECT)
    {
        node._type = node._type.OBJECT;
        auto obj = v.object();
        foreach (k, v; obj)
        {
            auto c = new JsonNode;
            node._children ~= c;
            makeRecursive(c, path ~ "->" ~ k, k, v);
        }
    }
    else
    {
        node._type = node._type.VALUE;
        auto c = new JsonNode;
        node._children ~= c;
        c._data = v.toString();
        c._path = path;
        c._type =  c._type.VALUE;
    }
}

auto makeTree(const(JSONValue) v)
{
    auto res = new JsonNode;
    makeRecursive(res, "root", "root", v);
    return res;
}

void printOperation(Operation!(const(JsonNode)) op)
{
    final switch (op.type)
    {
        case op.type.DELETE:
        {
            writeln("DELETE NODE ", op.from.node._path, " WITH VALUE ", op.from.node._data);
            break;
        }
        case op.type.INSERT:
        {
            writeln("INSERT NODE TO ", op.from.node._path, " WITH VALUE ", op.from.node._data);
            break;
        }
        case op.type.MOVE:
        {
            write("MOVE NODE FROM ", op.from.node._path, " WITH DATA ", op.from.node._data, " TO ");
            if (op.to.node is null)
            {
                writeln("root");
            } else
            {
                writeln(op.to.node._path);
            }
            break;
        }
        case op.type.NOTHING:
        {
            throw new Exception("unexpected operation type");
        }
    }
}

int main(string[] args)
{
    if (args.length != 3)
    {
        printUsage(args[0]);
        return 1;
    }

    string srcJsonPath = args[1];
    string dstJsonPath = args[2];

    auto srcJsonRoot = parseJSON(readText(srcJsonPath));
    auto dstJsonRoot = parseJSON(readText(dstJsonPath));

    auto srcRootNode = makeTree(srcJsonRoot);
    auto dstRootNode = makeTree(dstJsonRoot);

    auto ops = diff(srcRootNode, dstRootNode);

    foreach (op; ops)
    {
        printOperation(op);
    }

    return 0;
}
