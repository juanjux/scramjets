// =========================================================================================0
import std.conv;

extern(C) {

    // ===============================================================
    // Function pointer types 
    // ===============================================================
    alias NEOERR* function(void* ctx, char* output) CSOUTFUNC;
    alias NEOERR* function(void* ctx, HDF* hdf, const char* filename, char** contents) CSFILELOAD;
    alias NEOERR* function(CSPARSE *parse, CS_FUNCTION *csf, CSARG *args, CSARG *result) CSFUNCTION;
    alias NEOERR* function(const char *str, char **ret) CSSTRFUNC;
    alias uint function(const void *) NE_HASH_FUNC;
    alias int function(const void *, const void *) NE_COMP_FUNC;
    alias NEOERR* function(void *ctx, HDF *hdf, const char *filename, char **contents) HDFFILELOAD;


    // ===============================================================
    // Enums 
    // ===============================================================
    enum NEOS_ESCAPE
    {
      NEOS_ESCAPE_UNDEF    =  0,    /* Used to force eval-time checking */
      NEOS_ESCAPE_NONE     =  1<<0,
      NEOS_ESCAPE_HTML     =  1<<1,
      NEOS_ESCAPE_SCRIPT   =  1<<2,
      NEOS_ESCAPE_URL      =  1<<3,
      NEOS_ESCAPE_FUNCTION =  1<<4  /* Special case used to override the others */
    } 

    enum 
    {
      /* Unary operators */
      CS_OP_NONE = (1<<0),
      CS_OP_EXISTS = (1<<1),
      CS_OP_NOT = (1<<2),
      CS_OP_NUM = (1<<3),

      /* Binary Operators */
      CS_OP_EQUAL = (1<<4),
      CS_OP_NEQUAL = (1<<5),
      CS_OP_LT = (1<<6),
      CS_OP_LTE = (1<<7),
      CS_OP_GT = (1<<8),
      CS_OP_GTE = (1<<9),
      CS_OP_AND = (1<<10),
      CS_OP_OR = (1<<11),
      CS_OP_ADD = (1<<12),
      CS_OP_SUB = (1<<13),
      CS_OP_MULT = (1<<14),
      CS_OP_DIV = (1<<15),
      CS_OP_MOD = (1<<16),

      /* Associative Operators */
      CS_OP_LPAREN = (1<<17),
      CS_OP_RPAREN = (1<<18),
      CS_OP_LBRACKET = (1<<19),
      CS_OP_RBRACKET = (1<<20),

      CS_OP_DOT = (1<<21),
      CS_OP_COMMA = (1<<22),

      /* Types */
      CS_TYPE_STRING = (1<<25),
      CS_TYPE_NUM = (1<<26),
      CS_TYPE_VAR = (1<<27),
      CS_TYPE_VAR_NUM = (1<<28),

      /* Not real types... */
      CS_TYPE_MACRO = (1<<29),
      CS_TYPE_FUNCTION = (1<<30)
    }


    enum CSTOKEN_TYPE
    {
      /* Unary operators */
      CS_OP_NONE = (1<<0),
      CS_OP_EXISTS = (1<<1),
      CS_OP_NOT = (1<<2),
      CS_OP_NUM = (1<<3),

      /* Binary Operators */
      CS_OP_EQUAL = (1<<4),
      CS_OP_NEQUAL = (1<<5),
      CS_OP_LT = (1<<6),
      CS_OP_LTE = (1<<7),
      CS_OP_GT = (1<<8),
      CS_OP_GTE = (1<<9),
      CS_OP_AND = (1<<10),
      CS_OP_OR = (1<<11),
      CS_OP_ADD = (1<<12),
      CS_OP_SUB = (1<<13),
      CS_OP_MULT = (1<<14),
      CS_OP_DIV = (1<<15),
      CS_OP_MOD = (1<<16),

      /* Associative Operators */
      CS_OP_LPAREN = (1<<17),
      CS_OP_RPAREN = (1<<18),
      CS_OP_LBRACKET = (1<<19),
      CS_OP_RBRACKET = (1<<20),

      CS_OP_DOT = (1<<21),
      CS_OP_COMMA = (1<<22),

      /* Types */
      CS_TYPE_STRING = (1<<25),
      CS_TYPE_NUM = (1<<26),
      CS_TYPE_VAR = (1<<27),
      CS_TYPE_VAR_NUM = (1<<28),

      /* Not real types... */
      CS_TYPE_MACRO = (1<<29),
      CS_TYPE_FUNCTION = (1<<30)
    }

    enum {
        STATUS_OK = 0,
        INTERNAL_ERR = 1
    }

    alias uint NERR_TYPE;
    
    // ===============================================================
    // Structs 
    // ===============================================================

    struct NEOERR {
        int error;
        int err_stack;
        int flags;
        char desc[256];
        const char* file;
        const char* func;
        int lineno;
        NEOERR* next;
    }

    struct HDF_ATTR
    {
      char *key;
      char *value;
      HDF_ATTR *next;
    }

    struct NE_HASHNODE
    {
      void *key;
      void *value;
      uint hashv;
      NE_HASHNODE *next;
    }

    struct NE_HASH
    {
      uint size;
      uint num;

      NE_HASHNODE **nodes;
      NE_HASH_FUNC hash_func;
      NE_COMP_FUNC comp_func;
    } 


    struct HDF
    {
      int link;
      int alloc_value;
      char *name;
      int name_len;
      char *value;
      HDF_ATTR *attr;
      HDF *top;
      HDF *next;
      HDF *child;

      HDF *last_hp;
      HDF *last_hs;
      NE_HASH *hash;
      HDF *last_child;
      void *fileload_ctx;
      HDFFILELOAD fileload;
    }

    struct STRING
    {
      char *buf;
      int len;
      int max;
    } 

    struct CS_POSITION {
      int line;        /* Line number for current position */
      int col;         /* Column number for current position */
      int cur_offset;  /* The current position - commence reading from here */
    }

    struct CS_ERROR {
      NEOERR *err;
      CS_ERROR *next;
    }


    struct CS_ECONTEXT
    {
      NEOS_ESCAPE global_ctx; /* Contains global default escaping mode:
                     none,html,js,url */
      NEOS_ESCAPE current;    /* Used to pass around parse and evaluation specific
                                 data from subfunctions upward. */
      NEOS_ESCAPE next_stack; /* This is a big fat workaround. Since STACK_ENTRYs
                                 are only added to the stack after the
                                 command[].parse_handler() is called for the call
                                 it is being setup for, this is used to pass state
                                 forward.  E.g. This is used for 'def' to set UNDEF
                                 escaping state to delay escaping status to
                                 evaluation time. */
      NEOS_ESCAPE when_undef; /* Contains the escaping context to be used when a
                                 UNDEF is being replaced at evaluation time.  E.g.
                                 this is set in call_eval to force the macro code
                                 to get call's parsing context at eval time. */
    }

    struct ULIST
    {
      int flags;
      void **items;
      int num;
      int max;
    }

    struct CS_FUNCTION
    {
      char *name;
      int name_len;
      int n_args;
      NEOS_ESCAPE escape; /* States escaping exemptions. default: NONE. */

      // Renamed, was CS_FUNCTION.function
      CSFUNCTION function_;
      CSSTRFUNC str_func;

      CS_FUNCTION* next;
    }


    struct CS_MACRO
    {
      char *name;
      int n_args;
      CSARG *args;
      CSTREE *tree;
      CS_MACRO *next;
    } 


    struct CSARG
    {
      CSTOKEN_TYPE op_type;
      char *argexpr;
      // argumento to the function
      char *s;
      long n;
      int alloc;

      // Renamed, was CSARG.function
      CS_FUNCTION* function_;
      // Renamed, was CSARG.macro
      CS_MACRO* macro_;
      CSARG* expr1;
      CSARG* expr2;
      CSARG* next;
    }


    struct CSTREE
    {
      int node_num;
      int cmd;
      int flags;
      NEOS_ESCAPE escape;
      CSARG arg1;
      CSARG arg2;
      CSARG *vargs;

      char *fname;
      int linenum;
      int colnum;

      CSTREE* case_0;
      CSTREE* case_1;
      CSTREE* next;
    } 

    struct CS_LOCAL_MAP
    {
      CSTOKEN_TYPE type;
      char *name;
      int map_alloc;
      /* These three (s,n,h) used to be a union, but now we sometimes allocate
       * a buffer in s with the "string" value of n, so its separate */
      char *s;
      long n;
      HDF *h;
      int first;  /* This local is the "first" item in an each/loop */
      int last;   /* This local is the "last" item in an loop, each is calculated
                   explicitly based on hdf_obj_next() in _builtin_last() */
      CS_LOCAL_MAP *next;
    } 

    struct CSPARSE
    {
      const char *context;   /* A string identifying where the parser is parsing */
      int in_file;           /* Indicates if current context is a file */
      int offset;

      int audit_mode;        /* If in audit_mode, gather some extra information */
      CS_POSITION pos;       /* Container for current position in CS file */
      CS_ERROR* err_list;    /* List of non-fatal errors encountered */
      
      char* context_string;
      CS_ECONTEXT escaping; /* Context container for escape data */

      char* tag;		/* Usually cs, but can be set via HDF Config.TagStart */
      int taglen;

      ULIST* stack;
      ULIST* alloc;         /* list of strings owned by CSPARSE and free'd when
                               its destroyed */
      CSTREE* tree;
      CSTREE* current;
      CSTREE** next;

      HDF* hdf;
     
      CSPARSE* parent;  /* set on internally created parse instances to point
                                 at the parent.  This can be used for hierarchical
                                 scope in the future. */

      CS_LOCAL_MAP* locals;
      CS_MACRO* macros;
      CS_FUNCTION* functions;

      /* Output */
      void* output_ctx;
      CSOUTFUNC output_cb;

      void* fileload_ctx;
      CSFILELOAD fileload;

      /* Global hdf struct */
      /* smarti:  Added for support for global hdf under local hdf */
      HDF* global_hdf;
    }

    // ===============================================================
    // Exported API 
    // ===============================================================
    void string_init (STRING *str);

    // Error related

    void nerr_error_traceback (NEOERR *err, STRING *str);
    void nerr_pass();
    void nerr_pass_ctx();
    void nerr_error_string(NEOERR* nerr, STRING* str);
    NEOERR* nerr_init();
    void nerr_warn_error(NEOERR* err);
    int nerr_match(NEOERR* nerr, NERR_TYPE type);
    void nerr_log_error(NEOERR* nerr);
    void nerr_ignore(NEOERR* err);
    NEOERR* nerr_register(NERR_TYPE* err, const char* name);
    int nerr_handle(NEOERR** err, NERR_TYPE type);



    // HDF related

    NEOERR* hdf_init (HDF **hdf);
    NEOERR* hdf_set_value (HDF *hdf, const char *name, const char *value);
    NEOERR* hdf_set_symlink(HDF* hdf, const char* src, const char* dest);
    //char* hdf_set_valuef(HDF* hdf, const char* namefmt, ...);
    NEOERR* hdf_dump_str(HDF* hdf, const char* prefix, int compact, STRING *str);
    int hdf_get_int_value(HDF* hdf, const char* name, int defval);
    NEOERR* hdf_read_string_ignore(HDF* hdf, const char* s, int ignore);
    NEOERR* hdf_copy(HDF* dest_hdf, const char* name, HDF* src);
    NEOERR* hdf_get_node(HDF* hdf, const char* name, HDF** ret);
    HDF* hdf_obj_child(HDF* hdf);
    NEOERR* hdf_read_string(HDF* hdf, const char* s);
    NEOERR* hdf_set_buf(HDF* hdf, const char* name, char* value);
    void hdf_register_fileload(HDF* hdf, void* ctx, HDFFILELOAD fileload);
    HDF* hdf_get_obj(HDF* hdf, const char* name);
    HDF_ATTR* hdf_get_attr(HDF* hdf, const char* name);
    HDF* hdf_obj_top(HDF* hdf);
    //NEOERR* hdf_dump_format(HDF* hdf, int lvl, FILE *fp);
    void hdf_destroy(HDF** hdf);
    char* hdf_obj_value(HDF* hdf);
    NEOERR* hdf_write_string(HDF* hdf, char** s);
    // hdf_sort_obj
    NEOERR* hdf_write_file_atomic(HDF* hdf, const char* path);
    // NEOERR* hdf_set_valuef(HDF* hdf, const char* fmt, ...);
    NEOERR* hdf_get_copy(HDF* hdf, const char* name, char** value, const char* defval);
    NEOERR* hdf_write_file(HDF* hdf, const char* path);
    // char* hdf_get_valuef(HDF* hdf, const char* namefmt, va_list ap);
    NEOERR* hdf_set_int_value(HDF* hdf, const char* name, int value);
    NEOERR* hdf_dump(HDF* hdf, const char* prefix); // to stdout
    char* hdf_get_value(HDF* hdf, const char* name, const char* defval);
    NEOERR* hdf_set_copy(HDF* hdf, const char*dest, const char* src);
    HDF* hdf_obj_next(HDF* hdf);
    //NEOERR* hdf_search_path(HDF* hdf, const char* path, char* full, int full_len);
    char* hdf_obj_name(HDF* hdf);
    NEOERR* hdf_set_attr(HDF* hdf, const char* name, const char* key, const char* value);
    HDF* hdf_get_child(HDF* hdf, const char* name);
    NEOERR* hdf_remove_tree(HDF* hdf, const char* name);


    // CSPARSE related

    NEOERR* cs_init (CSPARSE **parse, HDF *hdf);
    NEOERR* cs_parse_string (CSPARSE *parse, char *buf, size_t blen);
    NEOERR* cs_render (CSPARSE *parse, void *ctx, CSOUTFUNC cb);
    NEOERR* cs_dump (CSPARSE* parse, void* ctx, CSOUTFUNC cb);
    void    cs_destroy(CSPARSE** parse);
    NEOERR* cs_register_esc_strfunc(CSPARSE* parse, char* funcname, CSSTRFUNC str_func);
    void    cs_register_fileload(CSPARSE* parse, void* ctx, CSFILELOAD fileload);
    NEOERR* cs_register_function(CSPARSE *parse, const char *funcname, int n_args, CSFUNCTION function_);
    NEOERR* cs_register_strfunc (CSPARSE* parse, char* funcname, CSSTRFUNC str_func);
    NEOERR* cs_parse_file(CSPARSE* parse, const char* path);
    NEOERR* cs_register_esc_function(CSPARSE* parse, const char* funcname, int n_args, CSFUNCTION function_);
} // extern(C)


// ======================================================================================
// TEST 
// ======================================================================================

import std.stdio;
import std.string;
import std.c.stdlib;
import std.c.string;

bool has_error(NEOERR* err) {
    if (err != cast(NEOERR*) STATUS_OK) {
        STRING traceback; 
        string_init(&traceback);
        nerr_error_traceback(err, &traceback);
        printf("%s", traceback.buf);
        return true;
    }
    return false;
}

extern(C) {
    NEOERR* output_func(void* user_data, char* parsed_template) {
        //printf("User data: |%s|\n", cast(char*) user_data);
        printf("%s", parsed_template);
        return cast(NEOERR*) STATUS_OK;
    }

    NEOERR *test_custom_func(CSPARSE *parse, CS_FUNCTION *csf, CSARG *args, CSARG *result)
    {
        ////cs_dump(parse, null, &output_func);
        //writeln("CSF:");
        //// XXX Este no sale bien
        //writeln("\tname: ", to!string(csf.name));
        //writeln("\tname_len: ", csf.name_len);
        //writeln("\tn_args: ", csf.n_args);
        //writeln("\tNEOS_ESCAPE: ", csf.escape);

        //writeln("CSARG:");
        //writeln("\tCSTOKEN_TYPE: ", args.op_type);
        //writeln("\ts: ", to!string(args.s));
        //writeln("\tn: ", args.n);
        //writeln("\talloc: ", args.alloc);
        /*writeln("\n");*/

        result.op_type = CSTOKEN_TYPE.CS_TYPE_STRING;
        result.n = 0;
        result.alloc = 1;
        result.s = strdup(toStringz("<normal>"));
        return cast(NEOERR*) STATUS_OK;
    }
 

}

void raise_if_neoerr(NEOERR* err, string pre="") {
    if (err != cast(NEOERR*) STATUS_OK) {
        STRING traceback; 
        string_init(&traceback);
        nerr_error_traceback(err, &traceback);
        throw new ClearSilverException(pre ~ to!string(traceback));
    }
}


class ClearSilverException : Exception 
{
    this(string msg) 
    {
        super(msg);
    }
}


class HDFProxy
{
    this() 
    {
        raise_if_neoerr(hdf_init(&_hdf), "In HDProxy.this: ");
    }

    ~this() 
    {   
        hdf_destroy(&_hdf);
    }

    string get(string name, string defval = null)
    {
        char* value = hdf_get_value(_hdf, toStringz(name), toStringz(defval));
        return to!string(value);
    }
    string opIndex(string name) { return get(name, null); }


    void set(string name, string value)
    {
        raise_if_neoerr(hdf_set_value(_hdf, toStringz(name), toStringz(value)), 
                        "In HDFProxy.set (\"" ~ name ~ "\", \"" ~ value ~ "\"):");
    }

    void setIntValue(string name, int value)
    {
        raise_if_neoerr(hdf_set_int_value(_hdf, toStringz(name), value),
                        "In HDFProxy.setIntValue  (\"" ~ name ~ "\", \"" ~ to!string(value) ~ "\"):");

    }
    void opIndexAssign(string value, string name) { set(name, value); }

    
    bool hasKey(string name) 
    {
        return get(name) != null;
    }

    
    void deleteKey(string name)
    {
        raise_if_neoerr(hdf_remove_tree(_hdf, toStringz(name)), 
                        "In HDFProxy.deleteKey(\"" ~ name ~ "\")");
    }


    string dump(string prefix=null, bool compact=false)
    {
        STRING str;
        raise_if_neoerr(hdf_dump_str(_hdf, toStringz(prefix), to!int(compact), &str));
        return to!string(str.buf);
    }
    string toString() { return dump(); }

    @property HDF* hdf_ptr() { return _hdf; }

    private:
        HDF* _hdf;
}

unittest 
{   
    auto csdata = new HDFPRoxy();
    assert(csdata.get("pok") == null);
    assert(csdata.get("pok", "defvalue") == "defvalue");

    csdata.set("foo", "bar");
    assert(csdata.get("foo") == "bar");

    assert(csdata["nop"] == null);
    csdata["polompos"] = "pok";
    assert(csdata["polompos"] == "pok");

    assert(csdata.dump() == ".foo = bar\n.polompos = pok\n");

    csdata.deleteKey("foo");
    assert(csdata["foo"] == null);
    assert(csdata.dump() == ".polompos = pok\n");
}


extern(C) 
{
    NEOERR* c_output_func(inout void* user_data, in char* parsed_template) 
    {
        string out_str = cast(string)(*user_data);
        out_str = to!string(parsed_template);
        return cast(NEOERR*) STATUS_OK;
    }


class CSParser
{
    // XXX Por referencia? Por favor?
    this(HDFPRoxy hdfproxy)
    {
        raise_if_neoerr(cs_init(&parse, hdf.hdf_ptr), "In CSParser.this: ");
        _hdf = hdfproxy;
    }

    ~this()
    {
        cs_destroy(&_parse);
    }

    // cs_register_function
    string render(string input) 
    {
        raise_if_error(cs_parse_string(_parse, toStringz(input), input.length+1),
                       "In CSParser.render, parsing template: ");
     
        string out_str;
        raise_if_error(cs_render(parse, cast(void*)&out_str, &c_output_func),
                       "IN CSParser.render, rendering template: ");
        writeln("Parsed template en la cadena: ", *out_str);
        return out_str;
    }

    @property HDFProxy hdfproxy() { return _hdf; }
    @propert CSPARSE* csparse_ptr() { return _parse; }

    private:
        CSPARSE* _parse;
        HDFProxy _hdf;
}

unittest 
{
    auto csdata = HDFProxy();
    csdata.set("somevar", "somevalue");

    auto csparser = CSParser(csdata);
    string template_ = "The value is <?cs var:somevar ?>";
    auto parsed_template = csparser.render(template_);
    assert(parsed_template == "The value is somevalue");
}

int main() {

    // Class test

    string template_ = `
    1. Sustitución de variable:
    This is => <?cs var:town ?>!!!! <= 

    2. Prueba de condicional if/else abreviado, se debería cumplir el else:
    => <?cs alt:texto_si ?>Texto que debería salir si se cumple el else <?cs /alt ?> <=

    3. Prueba de condicional if/else, se debería cumplir el if:
    => <?cs if:unbooleano ?> Estoy en el if <?cs else ?> Estoy en el else <?cs /if ?> <=

    4. Iteracion foreach, MyList tiene cuatro elementos:
    => <?cs each:item = MyList ?>
            <?cs name:item ?> - Contenido: <?cs var:item ?>
            <?cs if:first(item) ?>... y es el primer elemento probado con first() <?cs /if ?>
            <?cs if:last(item)  ?>... y es el último elemento probado con last()  <?cs /if ?>
       <?cs /each ?>
    <=

    5. Loop numérico de 1 a 10 saltando dos:
    => <?cs loop:i = #1, #10, #2 ?> <?cs var:i ?> , <?cs /loop ?> <=

    6. subcount(MyList), cuenta los elementos:
    => <?cs var:subcount(MyList) ?> <=

    7. name(MyList), devuelve el nombre de la variable:
    => <?cs var:name(MyList) ?> <=

    8. Valor absoluto de -5 con abs():
    => <?cs var:abs(-5) ?> <=

    9. Longitud de la cadena "Polompos Pok" con string.length():
    => <?cs var:string.length("Polompos pok") ?> <=

    10. Probando funcion custom:
    => <?cs var:test_custom_func(town) ?> <=

    11. Probando si se puede reescribir CGI
    => <?cs var:CGI.user.name ?> <=
    `;

    NEOERR* err;

    // Inicializacion hdf
    HDF* hdf;
    if (has_error(hdf_init(&hdf))) return -1;

    if (has_error(hdf_set_value(hdf, toStringz("town"), toStringz("SPARTAAAAAAAAAAA")))) return -1;
    if (has_error(hdf_set_value(hdf, toStringz("CGI.user.name"), toStringz("Pepe")))) return -1;
    if (has_error(hdf_set_value(hdf, toStringz("unbooleano"), toStringz("true")))) return -1;

    if (has_error(hdf_set_value(hdf, toStringz("MyList.primero"), toStringz("Primero")))) return -1;
    if (has_error(hdf_set_value(hdf, toStringz("MyList.segundo"), toStringz("Segundo")))) return -1;
    if (has_error(hdf_set_value(hdf, toStringz("MyList.tercero"), toStringz("Tercero")))) return -1;
    if (has_error(hdf_set_value(hdf, toStringz("MyList.cuarto"), toStringz("Cuarto")))) return -1;
    writeln("Volcado HDF: ");
    hdf_dump(hdf, "");


    CSPARSE* parse;
    if (has_error(cs_init(&parse, hdf))) return -1;
    if (has_error(cs_register_function(parse, toStringz("test_custom_func"), 1, &test_custom_func))) return -1;

    char* buf = cast(char*) malloc(10024);
    strcpy(buf, toStringz(template_));

    // Parsing of the template is done here
    if (has_error(cs_parse_string(parse, buf, 10024))) return -1;

    // Also, for a file, with cs_file being a string with the path
    // cs_parse_file(parse, cs_file);
    //if (has_error(cs_render(parse, null, &output_func))) return -1;

    //char* townval = hdf_get_value(hdf, toStringz("townx"), "no esta");
    //writeln("Valor: ", to!string(townval));

    free(buf);

    return 0;
    // XXX probar las funciones esas de filtro como url_escape, ver a docu, parece que hay que llamar a
    // algo para cargaar las funciones
}
