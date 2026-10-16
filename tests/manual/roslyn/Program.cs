using System;
using System.Collections.Generic;
using System.Linq;

class Foo
{
    public Foo() { }
    public void Zero() { }
    public void One(int a) { }
    public void Over() { }
    public void Over(int a) { }
    public int Gen<T>() => 0;
}
class Bar { public Bar(int x) { } }
class Baz { }
static class Ext
{
    public static void ExtZero(this Foo f) { }
    public static void ExtOne(this Foo f, int a) { }
}
class P
{
    static void Main() { }
    static void M()
    {
        var f = new Foo();
        var l = new List<int>();
        // PROBES
    }
}
