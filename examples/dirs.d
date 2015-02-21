import triff;
import std.file;
import std.path;
import std.algorithm;
import std.stdio;

void printUsage(string appName)
{
    writeln("Usage:\n  " ~ appName ~ " DIR_SRC DIR_DST\n"
      ~ "  Compares two directories and returns list of"
      ~ " operations to transform DIR_SRC into DIR_DST.");
}

class PathNode
{
    bool m_isFile;
    string m_name;
    PathNode[] m_children;

    this(string name, bool isFile = true)
    {
        m_name = name;
        m_isFile = isFile;
    }

    void markAsFile(bool value = true)
    {
        m_isFile = value;
    }

    string label() const
    {
        return m_name ~ (m_isFile ? "f" : "");
    }

    string name() const
    {
        return m_name;
    }

    auto children() const
    {
        return m_children;
    }

    PathNode add(PathNode n)
    {
        m_children ~= n;
        return n;
    }

    PathNode getChild(string name, bool file = false)
    {
        auto cr = m_children.find!((a, b) => (a.name() == b))(name);
        return cr.length ? cr[0] : add(new PathNode(name, file));
    }

    void print(int depth = 0)
    {
        foreach (i; 0..depth)
        {
            write(" - ");
        }
        writeln(name);
        foreach (c; m_children)
        {
            c.print(depth + 1);
        }
    }

    static assert(isDiffNode!PathNode, "should be DiffNode");
}

PathNode scanPath(string path)
{
    import std.conv;
    auto root = new PathNode(path, false);
    foreach (de; filter!(e => e.isFile)(dirEntries(path, SpanMode.breadth, false)))
    {
        auto node = root;
        foreach (part; pathSplitter(de.name))
        {
            node = node.getChild(to!string(part));
        }
        node.markAsFile();
    }
    return root;
}



int main(string[] args)
{
    if (args.length != 3)
    {
        printUsage(args[0]);
        return 1;
    }

    string srcDir = args[1];
    string dstDir = args[2];

    auto srcRootNode = scanPath(srcDir);
    auto dstRootNode = scanPath(dstDir);

    auto operations = diff(srcRootNode, dstRootNode);

    writeln("Operations: ", operations.length);

    void printOperation(Operation!(const(PathNode)) op)
    {
        writeln(op);
        return;
        final switch (op.type)
        {
            case op.type.DELETE:
            {
                writeln("rm ", buildPath(srcRootNode.name(), op.from.node.name()));
                break;
            }
            case op.type.INSERT:
            {
                writeln("cp ", buildPath(dstRootNode.name(), op.from.node.name()), " ",
                               buildPath(srcRootNode.name(), op.to.node.name()));
                break;
            }
            case op.type.MOVE:
            {
                writeln("mv ", buildPath(dstRootNode.name(), op.from.node.name()), " ",
                               buildPath(srcRootNode.name(), op.to.node.name()));
                break;
            }
            case op.type.NOTHING:
            {
                throw new Exception("unexpected operation type");
            }
        }
    }

    foreach (op; operations)
    {
        printOperation(op);
    }


    return 0;
}
