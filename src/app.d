import std.stdio;

import std.algorithm;
import std.array;
import std.range;
import std.typecons;


template isDiffNode(T)
{
    enum bool isDiffNode = __traits(compiles, {
        T node;
        auto l = node.label();
        auto c = node.children();
        foreach (cc; c) {}
    });
}

struct Operation(T) if (isDiffNode!T)
{
    alias Node = Rebindable!(const(T));
    enum Type : ubyte
    {
        NOTHING,
        INSERT,
        MOVE,
        DELETE,
    }

    static struct NodeInfo
    {
        bool original = true;
        Node parent;
        Node node;
    }

    Type type = Type.NOTHING;
    NodeInfo to;
    NodeInfo from;
}

auto diff(T)(const T orig, const T dest) if (isDiffNode!T)
{
    alias Node = const(T);
    alias LabelType = typeof(T.init.label());
    alias NodePair = Tuple!(Node, Node);
    alias NodeArray = NodePair[];
    alias Oper = Operation!Node;

    class ResultTree
    {
        Rebindable!Node orig;
        Rebindable!Node dest;
        ResultTree parent;
        Rebindable!Node[] children;
    }

    auto score(Node a, Node b)
    {
        auto sa = map!(a => a.label)(a.children());
        auto sb = map!(a => a.label)(b.children());
        return walkLength(setIntersection(sa, sb));
    }

    void toMap(Node a, Node parent, ref NodeArray[string] mp)
    {

        mp[a.label()] ~= NodePair(a, parent);
        foreach (c; a.children())
        {
            toMap(c, a, mp);
        }
    }

    Oper computeAction(Node b, Node parent, ref NodeArray[string] mp, ResultTree tree)
    {
        NodeArray* p = b.label in mp;
        string pl = (parent is null) ? "root" : parent.label;
        if (p is null)
        {
            tree.dest = b;
            Oper op1;
            op1.type = Oper.Type.INSERT;
            op1.from.original = false;
            op1.from.node = b;
            if (tree.parent !is null)
            {
                op1.to.original = tree.parent.dest is null;
                op1.to.node = (op1.to.original ? tree.parent.orig : tree.parent.dest);
            }
            return op1;
        }
        else
        {
            auto maxScore = minPos!((a1, a2) => score(a1[0], b) < score(a2[0], b))(*p);
            assert(maxScore.length > 0);
            auto pair = maxScore[0];
            *p = remove(*p, (*p).length - maxScore.length);
            tree.orig = pair[0];
            if (tree.parent !is null) {
                if (tree.parent.orig is pair[1]) {
                    return Oper();
                }
            } else {
                if (pair[1] is null) {
                    return Oper();
                }
            }
            Oper op;
            op.type = op.Type.MOVE;
            op.from.original = true;
            op.from.node = pair[0];
            op.from.parent = pair[1] is null ? null : pair[1];
            if (tree.parent is null)
            {
                op.to.node = null;
            }
            else
            {
                op.to.original = tree.parent.dest is null;
                op.to.node = (op.to.original ? tree.parent.orig : tree.parent.dest);
            }
            return op;
        }
    }

    Oper[] recurseAction(const Node b, const Node parent, ref NodeArray[string] mp, ResultTree tree)
    {
        Oper[] res;
        auto op = computeAction(b, parent, mp, tree);
        if (op.type != op.Type.NOTHING)
        {
            res ~= op;
        }
        foreach (c; b.children())
        {
            auto resNode = new ResultTree;
            resNode.parent = tree;
            res ~= recurseAction(c, b, mp, resNode);
        }
        return res;
    }

    NodeArray[string] mp;
    toMap(orig, null, mp);

    auto tree = new ResultTree;

    auto res = recurseAction(dest, null, mp, tree);
    foreach (arr; mp)
    {
        foreach (np; arr)
        {
            Oper op;
            op.type = op.type.DELETE;
            op.from.original = true;
            op.from.node = np[0];
            op.from.parent = np[1];
            res ~= op;
        }
    }
    return res;
}

void main()
{

}

unittest
{
    class Node
    {
        string m_label;
        int m_type;
        Node[] m_childs;

        auto label() const
        {
            return m_label;
        }

        auto children() const
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

        int opCmp(const Node b) const
        {
            return cmp(m_label, b.m_label);
        }

        override string toString()
        {
            return m_label ~ " childs: " ~ map!(a => a.label)(m_childs).join(",") ~ "\n" ~ map!(a => a.toString())(m_childs).join("\n");
        }
    }

    auto a = new Node("a");
    auto b = new Node("b");
    auto c = new Node("c");
    auto d = new Node("d");
    auto e = new Node("e");
    auto f = new Node("f");
    auto g = new Node("g");
    auto h = new Node("h");

    a.add(b);
    a.add(c);
    c.add(d);
    c.add(e);
    e.add(f);
    f.add(g);

    auto ops = diff(a, c);

    assert(ops.length == 3);
    assert(ops.canFind!(op => (op.type == op.type.MOVE && op.from.node is c && op.to.node is null)));
    assert(ops.canFind!(op => (op.type == op.type.DELETE && op.from.node is a && op.from.parent is null)));
    assert(ops.canFind!(op => (op.type == op.type.DELETE && op.from.node is b && op.from.parent is a)));

    auto zz = new Node("z");
    auto zc = new Node("c");
    auto zd = new Node("d");
    auto ze = new Node("e");
    auto zf = new Node("f");
    auto zg = new Node("g");
    auto zh = new Node("h");

    zz.add(zc);
    zc.add(ze);
    ze.add(zd);
    zc.add(zf);
    zf.add(zg);

    ops = diff(a, zz);

    assert(ops.length == 6);
    assert(ops.canFind!(op => (op.type == op.type.INSERT && op.from.node is zz && op.to.node is null)));
    assert(ops.canFind!(op => (op.type == op.type.MOVE && op.from.node is c && op.to.node is zz)));
    assert(ops.canFind!(op => (op.type == op.type.MOVE && op.from.node is d && op.to.node is e)));
    assert(ops.canFind!(op => (op.type == op.type.MOVE && op.from.node is f && op.to.node is c)));
    assert(ops.canFind!(op => (op.type == op.type.DELETE && op.from.node is a && op.from.parent is null)));
    assert(ops.canFind!(op => (op.type == op.type.DELETE && op.from.node is b && op.from.parent is a)));


}
