import std.stdio;

import std.algorithm;
import std.array;
import std.range;


template isDiffNode(T)
{
    enum bool isDiffNode = __traits(compiles, {
        T node;
        auto l = node.label();
        auto c = node.childs();
        //static assert(std.range.isInputRange!(typeof(c)));
    });
}

struct Operation(T) if (isDiffNode!T)
{
    enum Type : ubyte
    {
        INSERT,
        MOVE,
        DELETE,
    }

    Type type;
    Node* parent;
    Node* node;
    Node* to;
}


class Node
{
    string m_label;
    int m_type;
    Node[] m_childs;

    auto label() const
    {
        return m_label;
    }

    auto childs() const
    {
        return m_childs;
    }

    this(string label, int type = 0)
    {
        this.m_label = label;
        this.m_type = type;
    }

    void add(Node n)
    {
        m_childs ~= n;
    }

    void remove(string label)
    {
        foreach (int i, Node n; m_childs)
        {
            if (n.label == label)
            {
                m_childs = std.algorithm.remove(m_childs, i);
                break;
            }
        }
    }

    int opCmp(const Node b)
    {
        return cmp(m_label, b.m_label);
    }

    override string toString()
    {
        return m_label ~ " childs: " ~ map!(a => a.label)(m_childs).join(",") ~ "\n" ~ map!(a => a.toString())(m_childs).join("\n");
    }
}

auto diff(T)(const ref T orig, const ref T dest) if (isDiffNode!T)
{
    alias Node = T;
    alias NodePtr = const(Node)*;
    alias NodePair = Tuple!(NodePtr, NodePtr);
    alias NodeArray = NodePair[];

    class ResultTree
    {
        NodePtr orig;
        NodePtr dest;
        ResultTree parent;
    }

    auto score(const Node* a, const Node* b)
    {
        auto sa = map!(a => a.label)(a.childs());
        auto sb = map!(a => a.label)(b.childs());
        return walkLength(setIntersection(sa, sb));
    }

    void toMap(const Node a, const Node parent, ref NodeArray[string] mp)
    {

        mp[a.label()] ~= NodePair(&a, &parent);
        foreach (c; a.childs())
        {
            toMap(c, a, mp);
        }
    }

    string computeAction(const Node b, const Node parent, ref NodeArray[string] mp, ResultTree tree)
    {
        NodeArray* p = b.label in mp;
        string pl = (parent is null) ? "root" : parent.label;
        if (p is null)
        {
            tree.dest = &b;
            return "I " ~ pl ~ " " ~ b.label;
        }
        else
        {
            auto maxScore = minPos!((a1, a2) => score(a1[0], &b) < score(a2[0], &b))(*p);
            assert(maxScore.length > 0);
            auto pair = maxScore[0];
            remove(*p, (*p).length - maxScore.length);
            tree.orig = pair[0];
            if (tree.parent !is null) {
                if (tree.parent.orig == pair[1]) {
                    return "";
                }
            } else {
                if (pair[1] !is null) {
                    return "";
                }
            }
            return "M " ~ pl ~ " " ~ b.label;
        }
    }

    string recurseAction(const Node b, const Node parent, ref NodeArray[string] mp, ResultTree tree)
    {
        auto res = computeAction(b, parent, mp, tree) ~ "\n";
        foreach (c; b.childs)
        {
            auto resNode = new ResultTree;
            resNode.parent = tree;
            res ~= recurseAction(c, b, mp, resNode);
        }
        return res;
    }

    string res;
    NodeArray[string] mp;
    toMap(orig, null, mp);

    auto tree = new ResultTree;

    return recurseAction(dest, null, mp, tree);
}

void main()
{
    auto a = new Node("a");
    a.add(new Node("b"));
    auto c = new Node("c");
    c.add(new Node("d"));
    a.add(c);
    writeln(a);
    writeln(diff(a, c));
    writeln("Edit source/app.d to start your project.");
}
