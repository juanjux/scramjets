import std.stdio;
import std.variant;


void main() {

    auto a = Variant(42);
    writeln("Convierte 42 a float?", a.convertsTo!float);
    writeln("Convierte 42 a string?", a.convertsTo!string);
    writeln("Tipo a: ", a.type);

    writeln("Es int?", a.type  == typeid(int));
    writeln("Es string?", a.type == typeid(string));

    auto b = Variant(50);
    if (a != b) writeln("comparable");

    writeln("Tipos iguales?", a.type == b.type);
    auto c = Variant("polompos");
    writeln("Tipos iguales con c?", a.type == c.type);

    writeln("Obteniendo 42 como string: ", a.get!string);
}
