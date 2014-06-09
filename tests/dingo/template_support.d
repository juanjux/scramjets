import std.variant;
import std.array;
import std.typecons;
import parse_template;

class CommandInfo
{
    string name;
    string parameters;
    string text;
    string[] unproc_lines;
    // Indices over the processed output:
    size_t start;

    // Indices over the unprocessed input (some commands want it)
    size_t start_unproc_line;
    size_t start_unproc_col;

    bool processed = false;

    this(string namearg, string parametersarg)
    {
        name = namearg;
        parameters = parametersarg;
    }
}

alias string function(CommandInfo cinfo, ref DJTemplateParser parser) TemplateFunc;

struct TemplateCommand
{
    TemplateFunc func;
    Flag!"HasContext" hasContext;

    this(TemplateFunc postf, Flag!"HasContext" hascontext_) 
    {
        func = postf;
        hasContext = hascontext_;
    }
}


class TemplateLib
{
    string name;
    TemplateCommand[string] libCommands;
}


struct ContextValue
{
    bool escaped = false;
    Variant value;

    this(string strvalue, bool escaped_ = false) 
    {
        value = Variant(strvalue);
        escaped = escaped_;
    }

    this(Variant varvalue, bool escaped_ = false) 
    {
        value = varvalue;
        escaped = escaped_;
    }
    string toString()
    {
        return value.toString();
    }
}

