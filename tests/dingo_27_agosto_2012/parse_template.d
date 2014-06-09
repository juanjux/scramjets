import std.stdio;
import std.string;
import std.array;
import std.stream;
import std.file;
import std.path;
import std.conv;
import std.regex;
import std.datetime;
import std.variant;
import std.traits;
import std.algorithm;
import std.ascii;
import core.memory;

// XXX cambiar por la ruta completa
import template_support;
import default_template_lib; 

Regex!char INTERNAL_BLOCK_REGEX;
Regex!char INTERNAL_BLOCK_REGEX_FIRST;
Regex!char VALID_IDENTIFIER_REGEX;
Regex!char EXTENDS_REGEX;

enum COMMAND_OPEN_TAG = "{%";
enum COMMAND_CLOSE_TAG = "%}";
enum ONELINECOMMENT_OPEN_TAG = "{#";
enum ONELINECOMMENT_CLOSE_TAG = "#}";
enum VAR_OPEN_TAG = "{{";
enum VAR_CLOSE_TAG = "}}";

static this()
{
    INTERNAL_BLOCK_REGEX       = regex(r"###\w+###", "g");
    INTERNAL_BLOCK_REGEX_FIRST = regex(r"###\w+###");
    VALID_IDENTIFIER_REGEX     = regex(r"^[^\d\W]\w*$");
    EXTENDS_REGEX              = regex(r"\{%. ?extends. ?[^/?*:;{}\\]+. %\}");
}




pure bool isDigitString(string s) 
{
    foreach(c; s) if (!isDigit(c)) return false;
    return true;
}

// FIXME: TemplateException tiene que estar fuera, común a todas
class TemplateException : Exception 
{
    this(string msg) 
    {
        super(msg);
    }
}


// XXX controlar lo de public, private, protected, etc
class DJTemplateParser
{
    this(string filename, string[] search_paths, ref Variant[string] context, bool load_optimized = true)
    {
        _contextVars = context;
        _curline = 0;
        _curcolumn = 0;

        // FIXME comprobar que el filename es valido
        _filename    = filename;

        // FIXME comprobar que los search paths son validos
        if (search_paths is null || search_paths.length == 0) {
            // FIXME deberia ser la configuracion raiz del proyecto/templates
            _search_paths = ["."];
        } else
            _search_paths = search_paths;

        addTemplateLib(new DefaultTemplateLib());
        _load_optimized = load_optimized;
        loadTemplateFile(); 
    }

    package:
        Variant[string] _contextVars;
        //TemplateLib[] _templateLibs;
        TemplateCommand[string] _templateCommands;
        bool[string] _contextCommands;

        string _extends = null;
        CommandInfo[string] _blocks;

        string[] _lines = null; // all lines
        Appender!string _processed_result;

        size_t _curline; // current line
        size_t _curcolumn; // current column
        bool _optimizing = false;
        bool _load_optimized;

        string _filename;
        string _full_template_path;
        string _cache_file;
        string[] _search_paths;

    public:

    @property string result()            { return _processed_result.data; }
    @property string errorPos()          { return xformat("On template \"%s\": ", _filename,); }

    package void setParent(bool set) 
    { 
        _optimizing = set;
    }


    Variant* getContextVar(string key) 
    {
        return (key in _contextVars);
    }

    void setContextVar(string key, Variant value)
    {
        _contextVars[key] = value;
    }

    void removeContextVar(string key)
    {
        _contextVars.remove(key);
    }

    // debug
    void printAllVars() 
    {
        foreach(key; _contextVars.keys)
            writeln(key,": ", _contextVars[key]);
    }


    void addTemplateLib(TemplateLib tlib)
    {
        foreach(cmd_name; tlib.libCommands.keys) {
            auto cmd = tlib.libCommands[cmd_name];
            _templateCommands[cmd_name] = cmd;
            _contextCommands[cmd_name] = cmd.hasContext;
        }
    }


    bool isOptimized()
    {
        _cache_file = buildPath(dirName(_full_template_path), ".cache", _filename ~ ".opt");
        if (!exists(_cache_file))
            return false;

        string[] templ_paths = _full_template_path ~ getAncestorsPaths();
        auto mtime_cache = timeLastModified(_cache_file);
        foreach(ref path; templ_paths) {
            if (timeLastModified(path) >= mtime_cache) 
                return false;
        }
        return true;
    }


    string[] getAncestorsPaths()
    {
        string[] ret;
        string extend = _extends;
        while (extend !is null) {
            foreach(ref path; _search_paths) {
                auto potential_path = buildPath(path, extend);
                if (!exists(potential_path)) {
                    extend = null;
                    break;
                } 
                ret.length += 1;
                ret[$-1] = extend;
                extend = getFileTemplateExtends(extend);
            }
        }
        return ret;
    }


    string getFileTemplateExtends(string path)
    {
        auto f = std.stdio.File(path, "r");
        auto firstline = f.readln();
        return getExtendsFromLine(firstline);
    }


    string getExtendsFromLine(string line)
    {
        if (line is null) return null;
        auto matches = match(line, EXTENDS_REGEX);
        if (matches.empty) return null;

        auto extends_arr = std.array.split(strip(line).removechars("{%}\""), " ");
        if (extends_arr.length < 3) return null;

        return extends_arr[2];
    }


    void optimize()
    {   
        _optimizing = true;
        _load_optimized = false;

        processText(_lines, _curline, _curcolumn, _processed_result);
        mergeAllTemplates();

        auto dir = dirName(_cache_file);
        if (!exists(dir))
            mkdirRecurse(dirName(_cache_file));

        std.file.write(_cache_file, this.result);

        // Restart the internal state
        foreach(key; _blocks.keys)
            _blocks.remove(key);
        _lines.length = 0;
        _processed_result.clear();
        _curline = 0; 
        _curcolumn = 0;

        _load_optimized = true;
        _optimizing = false;
    }


    void loadTemplateFile()
    {
        foreach(ref path; _search_paths) {
            auto potential_path = buildPath(path, _filename);
            //writeln("Potential path: ", potential_path);

            if (exists(potential_path)) {
                //writeln("Existe");
                _full_template_path = potential_path;
                _extends = getFileTemplateExtends(_full_template_path);

                if (_load_optimized) {
                    // Optimize first
                    if (!isOptimized) {
                        _lines = splitLines(readText(_full_template_path));
                        optimize();
                    } 
                    _lines = splitLines(readText(_cache_file));  
                } else  
                    _lines = splitLines(readText(_full_template_path));
                //_processed_result.reserve(to!int(_lines.length*80*1.5));
                return;
            }
        }
        throw new TemplateException(xformat("Template \"%s\" not found in search paths", _filename));
    }


    void render()
    {
        // Just in case it is called again (the file changed, etc)
        _processed_result.clear();
        _curline = 0;
        _curcolumn = 0;

        processText(_lines, _curline, _curcolumn, _processed_result);
        if (!_load_optimized)
            mergeAllTemplates();
    }


    void processText(ref string[] lines, ref size_t lineidx, ref size_t col, 
                     ref Appender!string processed, string command = null, 
                     string parameters = null, CommandInfo cinfo = null,
                     bool skipProcessing = false) 
    {
        //writeln("XXX lines.length: ", lines.length);
        //writeln("XXX linesidx: ", lineidx);

        while (lineidx < lines.length) {

            // Readability aliases
            auto curlinestr = lines[lineidx];
            auto linelen    = curlinestr.length;

            if (linelen == 0 || col >= linelen) {
                lineidx++;
                col = 0;
                continue;
            }

            auto startcolumn = col;
            while (col < linelen) {
                bool consumed = false;

                // XXX comprobra que no esta escapado con una barra antes
                if (curlinestr[col] == COMMAND_OPEN_TAG[0] && col < linelen) {

                    // Save the text before the command
                    processed.put(curlinestr[startcolumn..col]);

                    auto nextchar = curlinestr[col+1];
                    if (nextchar == COMMAND_OPEN_TAG[1]) {
                        // {%, command
                        consumed = true;
                       
                        // If we're processing  a command context, check that we've
                        // found the endcommand and if so return to the caller (processContextCommand)
                        auto subline = lines[lineidx][col..$];
                        if (command !is null && isCommandClose(command, parameters, subline, col)) 
                            return;    
                        
                        // Process the command
                        col +=  2;
                        processCommand(lines, lineidx, col, processed, skipProcessing);
                    } else if (nextchar == ONELINECOMMENT_OPEN_TAG[1]) {
                        // {#, comment (one line)
                        consumed = true;
                        col += 2;
                        auto subline = lines[lineidx][col..$];
                        processOneLineComment(subline, col);
                    } else if (nextchar == VAR_OPEN_TAG[1]) {
                        // {{ var
                        consumed = true;
                        // XXX no lo hace
                        if (!skipProcessing) {
                            col += 2;
                            processVarSubstitution(lines, lineidx, col, processed);
                        }  else col++;
                    }

                    if (consumed && lineidx < lines.length) {
                        curlinestr = lines[lineidx]; 
                        linelen = curlinestr.length;
                        startcolumn = col; 
                    }
                }

                if (!consumed) col++;
                
           }
           // End of line reached, save part not previously consumed by commands
           processed.put(curlinestr[startcolumn .. col]);
           processed.put("\n");

           lineidx++;
           col = 0;
        }
    }


    Appender!string mergeAllTemplates() 
    {
         // If the template defined an "extends", we create another instance and call
         // processText on the parent template. Note that the instance will also recursively do 
         // the same for any extends it could have
         if (_extends !is null) {
            // We're a derived template. Also, dont load the optimized version of the
            // parent template if we are optimizing
            auto parent = new DJTemplateParser(_extends, _search_paths, 
                                               _contextVars, _load_optimized);
            parent.setParent(true);
            parent.processText(parent._lines, parent._curline, parent._curcolumn, parent._processed_result);

            // Since we're not the root template, we send our blocks up one level. At the end, the root
            // template will have all blocks
            parent.receiveSonsBlocks(_blocks);
            _processed_result = parent.mergeAllTemplates();

        } else {
            // We're the root
            mergeBlocks();
            createFinalText();
        }

        return _processed_result;
    }


    void receiveSonsBlocks(CommandInfo[string] sons_blocks)
    {
        // Merge the sons blocks with ours. Since the derived templates blocks
        // have priority, if a block is present in both the sons ones win and 
        // rewrite ours in the array

        foreach(ref block; sons_blocks) {
            _blocks[block.parameters] = block;
        }
        _optimizing = false;
    }

/*
 * This is run in the root template object, which at this stage should already have the son
 * blocks' text (without unexpanded subblocks) in its _block member. This works by 
 * iterating over the list of blocks and calling mergeBlock on them. mergeBlock searchs
 * for ###blockmarkers###/|||blockmarker inside the block contents, and for every one 
 * found it calls itself recursively (to search inside the subblock for markers, etc).
 *
 * When there are no more markers in the block text (no more subblocks, and all the previous
 * ones has been expanded) this puts the block "subblocks_merged" member
 * to "true", to avoid doing the work again is the block is processed later in the 
 * mergeBlocks iteration (for example, if the block "body" is the first one in the iteration
 * and the block "subbody1", inside "body", is the fourth, by the time its the turn
 * of "subbody1" in mergeBlocks' iteration it will be already be processed by the recursive
 * processing of "body" so no work has to be done).
 */

    void mergeBlocks() 
    {
        // We're the root template. Insert the block contents from ourselve and all the sons
        // longo the template

        foreach(block; _blocks) {
            mergeBlock(block);
        }
    }

    string mergeBlock(CommandInfo block) 
    {
        //writeln("==> en mergeBlock para: ", block.name);
        if (block.text.length == 0)
            throw new TemplateException(
                         xformat("On template \"%s\": \"{%% block %%}\" without \"{%% endblock %%}\" found inside block \"%s\"", 
                         _filename, block.parameters));

        if (block.processed) {
            return block.text;
        }


        // Remove the internal marks of this block
        auto markslen = block.parameters.length + 6;
        block.text = block.text[markslen..$-markslen];

        auto matches = match(block.text, INTERNAL_BLOCK_REGEX);
        foreach(match; matches) {
            // Subblock found. Find its start and end using the markers and 
            // expand it recursively calling mergeBlock over it
            auto subblock_name = match[0][3..$-3];
            auto endmark = xformat("|||%s|||", subblock_name);
            auto startpos = std.string.indexOf(block.text, match[0]);
            auto endpos   = std.string.indexOf(block.text, endmark);

            if (endpos == -1) // User unscaped ###???
                continue;
            
            auto submarkslen = subblock_name.length + 6;
            block.text = block.text[0..startpos] ~ 
                         mergeBlock(_blocks[subblock_name]) ~ 
                         block.text[endpos+submarkslen..$];
        }

        // This is to avoid duplicated processing if the block is later on mergeBlocks iteration
        block.processed = true;
        return block.text;
    }


/* 
 * Replace the text already joined with all parent templates with
 * all of the blocks contents. This is run in the root template. Since the blocks
 * defined in the son templates not inside one of the blocks inherited from the root
 * template, we only need to process the __processed_result of the root template, 
 * replacing any found ###blockmarkers###/|||blockmarker||| with the content of the
 * youngest son. The blocks should already have their final contents (with all 
 * subblocks expanded from the mergeBlocks() call. Is mostly the same as 
 * mergeBlocks without the resursivity, since the blocks should already be merged
 */
    void createFinalText()
    {

        while (true) {
            auto matches = match(_processed_result.data, INTERNAL_BLOCK_REGEX_FIRST);
            if (matches.empty()) 
                break;

            auto block_name = matches.front.hit[3..$-3];
            auto endmark = xformat("|||%s|||", block_name);
            auto startpos = std.string.indexOf(_processed_result.data, matches.front.hit);
            auto endpos   = std.string.indexOf(_processed_result.data, endmark);

            if (endpos == -1)
                continue;

            auto submarkslen = block_name.length + 6;
            Appender!string proctmp;
            //proctmp.reserve(_processed_result.data.length + _blocks[block_name].text.length + _processed_result.data[endpos + submarkslen .. $].length);
            proctmp.put(_processed_result.data[0..startpos]);
            proctmp.put(_blocks[block_name].text);
            proctmp.put(_processed_result.data[endpos+submarkslen..$]);
            _processed_result = proctmp;
        }
    }


    void processCommand(ref string[] lines, ref size_t lineidx, ref size_t col, 
                        ref Appender!string processed, bool skipProcessing)
    {
        auto savedcolumn = col;
        string full_command = extractCommand(lines[lineidx][col..$], COMMAND_CLOSE_TAG, col);

        auto tokens = array(std.array.split(full_command, " "));
        if (tokens.length == 0)
            throw new TemplateException(errorPos ~ 
                                        xformat("invalid template command \"%s\"", full_command));

        auto command = tokens[0];
        auto parameters = std.string.join(tokens[1..$], " ").strip();

        if (_optimizing && command != "block" && command != "extends") {
            // When optimizing we only process blocks and extends, all other 
            // commands are carried away to the optimized template
            processed.put("{%");
            processed.put(lines[lineidx][savedcolumn .. col]);
            return;
        }

        if (!(command in _templateCommands)) {
            string exc = null;
            if (command == "endblock")
                // endblocks should be processed in processText while reading a context
                // so any endblocks found here are unmatched
                exc = xformat(errorPos ~ "unmatched \"{%% endblock %%}\"");
            else
                exc = errorPos ~ xformat("invalid template command \"{%% %s %%}\"", command);
            throw new TemplateException(exc);
        }

        if (_contextCommands[command]) 
            processContextCommand(command, parameters, lines, lineidx, col, processed, skipProcessing);
        else 
            processSimpleCommand(command, parameters, lines, lineidx, col, processed, skipProcessing);
    }


    void processOneLineComment(string subline, ref size_t col) 
    {
        // Just remove everything until the closing tag
        extractCommand(subline, ONELINECOMMENT_CLOSE_TAG, col);
    }


    void processVarSubstitution(string[] lines, ref size_t lineidx, 
                                ref size_t col, ref Appender!string processed)
    {
        //writeln("==> processVarSubstitution en linea: ", lines[lineidx]);
        auto savedcolumn = col;
        auto text_var = extractCommand(lines[lineidx][col..$], VAR_CLOSE_TAG, col);       

        if (_optimizing) {
            processed.put("{{");
            processed.put(lines[lineidx][savedcolumn .. col]);
            return;
        }

        processed.put(getContextVarFromStr(text_var).toString);
        checkEndLine(lines, lineidx, col, processed);
    }


/** 
 * extract the next command. This expects the {% to have already been consumed. It will
 * advance col until the end of the command.
 */

    string extractCommand(string line, string closingTag, ref size_t col) 
    {
        //writeln("=> extractCommand: ", _filename);
        auto pos_close = std.string.indexOf(line, closingTag);
        if (pos_close == -1) {
            string exc = errorPos ~ xformat("%s must be in the same line as the opening mark: %s", 
                                            closingTag, line);
            throw new TemplateException(exc);
        }

        auto cmd = line[0..pos_close].strip();
        col += pos_close + 2;
        return cmd;
    }


    void processSimpleCommand(string command, string parameters, ref string[] lines, 
                              ref size_t lineidx, ref size_t col, 
                              ref Appender!string processed, bool skipProcessing) 
    {
        //writeln("=> processSimpleCommand:", command);
        if (!skipProcessing) {
            string xxx = xformat("XXXRESULTADO DE COMANDO SIMPLE %s:%sXXX", command, parameters);
            processed.put(xxx);
            checkEndLine(lines, lineidx, col, processed);
        }
    }


    void processContextCommand(string command, string parameters, ref string[] lines,
                               ref size_t lineidx, ref size_t col, 
                               ref Appender!string processed, bool skipProcessing)
    {
        auto cinfo = newCommandInfo(command, parameters, lineidx, col, processed);
        Appender!string cmd_processed;

        // If the command is a "block", save its starting position
        if (command == "block") {
            if (match(parameters, VALID_IDENTIFIER_REGEX).empty)
                throw new TemplateException(errorPos ~ 
                                            xformat("invalid block name identifier \"%s\"", parameters));
          
            _blocks[parameters] = cinfo;
            // Special tag used for finding blocks quickly later when joining blocks with 
            // parent/derived templates
            cmd_processed.put(xformat("###%s###", parameters));
        }

        checkEndLine(lines, lineidx, col, processed);
        // Process with skipProcessing=true since we're only interested in loading the 
        // context into the cinfo's unproc_lines (processing will be done later in the
        // command function, if needed).
        processText(lines, lineidx, col, cmd_processed, command, parameters, cinfo, true);

        if (command == "block") {
             cmd_processed.put(xformat("|||%s|||", parameters));
             processed.put(cmd_processed.data);
        }

        closeCommandInfo(cinfo, lines, lineidx, cmd_processed);

        // XXX excepcion: procesar comentarios de bloque al optimizar
        if (!_optimizing || !skipProcessing) {
            auto tcmd = (command in _templateCommands);
            if (tcmd && (*tcmd).hasContext && (*tcmd).func !is null) {
                processed.put((*tcmd).func(cinfo, this));
            }
        }
    }
    

    CommandInfo newCommandInfo(string command, string parameters, size_t lineidx, size_t col, const ref Appender!string processed)
    {
        auto cinfo = new CommandInfo(command, parameters);
        cinfo.start = processed.data.length;
        cinfo.start_unproc_line = lineidx;
        cinfo.start_unproc_col  = col;
        return cinfo;
    }

    void closeCommandInfo(ref CommandInfo cinfo, string[] lines, size_t lineidx, const ref Appender!string cmd_processed)
    {
        // XXX esto del unproc_lines tambien es caro de cojones, esta copiando las lineas, el comando 
        // deberia recibir una referencia a las lineas y las posiciones
        with (cinfo) {
            // Save the processed text
            text = cmd_processed.data;

            // And the unprocessed lines
            //unproc_lines.length = lineidx - start_unproc_line + 1;

            auto tocopy = lineidx - start_unproc_line;
            auto lastline = start_unproc_line + tocopy;
            auto endcolumn = std.string.lastIndexOf(lines[lineidx], "{%");
            if (tocopy > 0) {
                unproc_lines = lines[start_unproc_line][start_unproc_col .. $] ~ 
                               lines[start_unproc_line+1 .. lastline] ~ 
                               lines[lastline][0 .. endcolumn];
            }
            else 
                // Command starts and ends in the same line
                //unproc_lines[0] = lines[start_unproc_line][start_unproc_col .. endcolumn];
                unproc_lines = [lines[start_unproc_line][start_unproc_col .. endcolumn]];
        }
    }


    /**
     * Check if the command is the "endsomething" of the "something" command. If it really is,
     * it will advance col until the end of the endcommand (extractCommand will do the
     * advancing).
     */
    bool isCommandClose(string command, string parameters, string subline, ref size_t col) {
        auto savedcolumn = col;
        
        col += 2;
        auto thiscommand = extractCommand(subline[2..$], COMMAND_CLOSE_TAG, col);

        string endcommand = xformat("end%s", command);
        if (thiscommand == endcommand) 
            return true;

        col = savedcolumn;
        return false;
    }


    // FIXME: Slow...
    Variant getContextVarFromStr(string strvar)
    {
        auto tokens = std.array.split(strvar, ".");
        string currenttoken  = tokens[0];
        Variant currentvar = _contextVars.get(currenttoken, Variant(""));

        if (currentvar != Variant("") && tokens.length > 1) {
            foreach(tok; tokens[1..$]) {
                auto previoustoken = currenttoken;
                currenttoken = tok;

                try 
                {
                    if (tok.length > 2 && tok[0] == '"' && tok[$-1] == '"') {
                        // string index
                        currentvar = currentvar[tok[1..$-1]];
                    }
                    else {
                        // integer index
                        if (!isDigitString(tok))
                            throw new TemplateException(errorPos ~ 
                                                        xformat("Used %s as index in %s, but is not an integer (did you forgot to \"quote\" it?)", tok, strvar));
                        currentvar = currentvar[to!int(tok)];
                    }
                } catch (VariantException)
                      throw new TemplateException(errorPos ~
                                                  xformat("template var \"%s\" cannot be indexed by index \"%s\"", 
                                                  previoustoken, tok));

            }
        }
        return currentvar;
    }

    void checkEndLine(ref string[] lines, ref size_t lineidx, ref size_t col, ref Appender!string processed) 
    {
        if (col >= lines[lineidx].length) {
            processed.put("\n");
            lineidx++;
            col = 0;
        }
    }
}

// =======================================================
// XXX mover a unittests
void main()
{
enum BENCH = false;
enum iterations = 1;

static if(!BENCH) {
    // Context ====================
    
    int[] intarray = [1, 2, 3, 4];
    Variant[] vararray = [Variant(1), Variant(2.12), Variant(true), Variant("polompos")];
    string[] stringarray = ["pok", "polompos", "cogorcios", "foo", "bar"];
    int[string] assocarray1 = ["pok": 1, "polompos": 2];
    string[int] stringintarray = [1: "pok", 6: "polompos"];

    string[string][] listassoc;
    listassoc.length = 2;
    listassoc[0] = ["polompos": "pok", "malo": "bueno"];
    listassoc[1] = ["uno": "dos", "tres": "seis"];

    string[int][] listassocint;
    listassocint.length = 2;
    listassocint[0] = [1: "pok", 7: "bueno"];
    listassocint[1] = [3: "dos", 5: "seis"];

    Variant[string] assocvariant = ["uno": Variant(1), "true": Variant(true)];

    Variant[string][] listvarassoc;
    listvarassoc.length = 2;
    listvarassoc[0] = ["uno": Variant(1), "dos": Variant(2)];
    listvarassoc[1] = ["true": Variant(true), "pi": Variant(3.14)];

    string[][] listliststring = [["uno", "dos", "tres", "cuatro"], ["a", "be", "ce", "de"]];

    auto bi = new CommandInfo("nombre", "parametros");
    bi.text = "texto";

    // End context ===============================
    Variant[string] context =      [
                                    "testvarint":    Variant(42),
                                    "testvarfloat":  Variant(3.14),
                                    "testvarstring": Variant("polompos"),
                                    "testvarbool":   Variant(true),
                                    "intarray":      Variant(intarray),
                                    "vararray":      Variant(vararray),
                                    "stringarray":   Variant(stringarray),
                                    "stringintarray":Variant(stringintarray),
                                    "assocarray1":   Variant(assocarray1),
                                    "listassoc":     Variant(listassoc), // XXX este es el que hace que vaya lento!
                                    "listassocint":  Variant(listassocint),
                                    "assocvariant":  Variant(assocvariant),
                                    "class"       :  Variant(bi),
                                    "listliststring":Variant(listliststring),
                                    "listvarassoc":  Variant(listvarassoc),
                                    ];

    Variant[string] empty;

    auto starttime = Clock.currTime();
    DJTemplateParser parser = null;
    for(long i = 0; i < iterations; i++) {
        parser = new DJTemplateParser("niece_template.html", ["."], context, true);
        parser.render();
    }
    writeln("Results:", parser.result);
    writeln("Per iteration: ", (Clock.currTime() - starttime) / iterations);
}

static if(BENCH) {
   // Test bigtable
 
    auto row = [1,2,3,4,5,6,7,8,9,10];
    int[][] table;

    for (int i = 0; i < 1000; i++) {
        table.length += 1;
        table[$-1] = row.dup;
    }
    Variant[string] context = ["table": Variant(table)];

    auto starttime = Clock.currTime();
    auto parser = new DJTemplateParser("bigtable.html", ["."], context, true);
    parser.render();

}
    writeln("dynamic template rendered in: ", Clock.currTime() - starttime, "\n\n\n");
}

