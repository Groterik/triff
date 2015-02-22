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
    string m_label;
    PathNode[] m_children;

    this(string name, string label, bool isFile = true)
    {
        m_name = name;
        m_label = label.length ? label : (name ~ (isFile ? "f" : ""));
        m_isFile = isFile;
    }

    void markAsFile(bool value = true)
    {
        m_isFile = value;
    }

    string label() const
    {
        return m_label;
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
        return cr.length ? cr[0] : add(new PathNode(name, null, file));
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
    auto root = new PathNode(path, "root", false);
    foreach (de; filter!(e => e.isFile)(dirEntries(path, SpanMode.breadth, false)))
    {
        auto node = root;
        assert(de.name.startsWith(path));
        import std.array : array;
        foreach (part; array(pathSplitter(de.name))[array(pathSplitter(path)).length..$])
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

    void printOperation(Operation!(const(PathNode)) op)
    {
        final switch (op.type)
        {
            case op.type.DELETE:
            {
                writeln("rm ", buildPath(srcRootNode.name(), op.from.node.name()));
                break;
            }
            case op.type.INSERT:
            {
                write("cp ", buildPath(dstRootNode.name(), op.from.node.name()), " ");
                if (op.to.node is srcRootNode)
                {
                    writeln(srcRootNode.name());
                }
                else
                {
                    writeln(buildPath(srcRootNode.name(), op.to.node.name()));
                }
                break;
            }
            case op.type.MOVE:
            {
                writeln("mv ", buildPath(srcRootNode.name(), op.from.node.name()), " ",
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
