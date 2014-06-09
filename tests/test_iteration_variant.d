import std.variant;
import std.stdio;
import core.exception;


void main() 
{
    string[] arrstr = ["uno", "dos", "tres"];
    int[] arrnum = [1,2,3];
    int x = 3;

    //auto v = Variant(arrstr);
    //auto vi = Variant(arrnum);
    //auto vint = Variant(x);

    //Variant[string] context;
    //context["arrstr"] = v;
    //context["arrnum"] = vi;

    //foreach(string i; v) writeln(i);

    //foreach(Variant i; vi) writeln(i);

    //writeln("suma: ", vi[0]+vi[1]+vi[2]);

    //foreach(Variant x; context) 
        //foreach(Variant y; x)
            //writeln(y);

    //writeln(context["arrstr"].peek!(string[])); // puntero 
    //writeln(context["arrstr"].convertsTo!(int[])); // false

    //// casca en tiempo de ejecucion pero con VariantException:
    //try 
    //{
        //foreach(Variant x; vint) 
            //writeln(x);
    //} catch (VariantException)
        //writeln("No iterable!");

/*    string[] list = ["uno", "dos", "tres"];*/
    //string[string] dict = ["polompos": "p", "juanjo": "j", "pepe": "p"];
    //auto vd = Variant(dict);
    /*auto vlist = Variant(list);*/
    //foreach(k, i; dict) writeln(k, " ", i);

    //writeln("Con variant: ");
    //auto vdict = Variant(dict);
    //writeln(vdict["polompos"]);
    
    //try
    //{
        //writeln(vint["polompos"]);
    //} catch (VariantException)
        //writeln("No indexable!");

    //foreach(Variant i, Variant k; vdict) {}

    //float j = 4.14;
    //auto vf = Variant(j);

    //writeln(j > x);

    
    //string[] list = ["uno", "dos", "tres", "cuatro"];
    //int[] list2 = [1, 2, 3, 4, 5];
    //int[string] dict = ["uno": 1, "dos": 2, "tres": 3, "cuatro": 4];
    //auto vdict = Variant(dict);
    //string[int] dictnumindex = [1: "uno", 2: "dos", 3: "tres"];
    //auto vdict3 = Variant(dictnumindex);
    //Variant[] twolevellist = [Variant(list), Variant(list2)];
    //Variant[string] context = ["int": Variant(3), "string": Variant("pok"), "strlist": Variant(list), "intlist": Variant(list2), "dict": Variant(dict)];

    //writeln("nota" in context);

    //auto i = Variant(3);
    //auto s = Variant("3");

    //writeln("peek i como entero: ", *(i.peek!int));
    //writeln("peek s como entero: ", s.peek!int);
    //writeln("typeid(i) es int?: ", i.type == typeid(int));
    //writeln("typeid(s) es int?: ", s.type == typeid(int)); // FALSE
    //writeln("i.convertsTo int?: ", i.convertsTo!int);
    //writeln("s.convertsTo int?: ", s.convertsTo!int); // FALSE
    //writeln("s.coerce!int: ", s.coerce!int);
    
    //auto realdict = [1:1, 2:2, 3:3];
    //auto variantdir = Variant(realdict);

    //writeln("In real: ", (1 in realdict));
    //writeln("In variant: ", (1 in variantdir));

    string[] lines = ["En un lugar de la mancha", " de cuyo nombre no quiero acordarme", " no ha mucho que vivía"];
    string[] linesref = lines[0][3..$] ~ lines[1..$-2] ~ lines[$-1][0..$-3];
    writeln("XXX linesref: ", linesref);
}
