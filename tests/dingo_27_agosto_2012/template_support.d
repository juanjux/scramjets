import std.variant;
import std.array;
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
    bool hasContext = false;

    this(TemplateFunc postf, bool hascontext = false) 
    {
        func = postf;
        hasContext = hascontext;
    }
}


class TemplateLib
{
    string name;
    TemplateCommand[string] libCommands;
}

