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
    public void Say(string message) { }
    public void Sep(char separator) { }
    public void Each(Action<int> action) { }
    public void Ordr(Comparison<int> comparison) { }
    public int Fold(Func<int, int, int> folder) => 0;
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
