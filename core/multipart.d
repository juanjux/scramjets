/** This code uses code taken and adapted from Wombat multipartd.d
 */
module core.multipart;

import std.variant;
import std.stdio;
import std.string;
import std.conv;
import std.file;
import std.random;
import std.path;

import core.uploadedfile;
import lib.sjsocket;
import user.settings;


class MultipartParserException : Exception 
{
    this(string msg) 
    {
        super(msg);
    }
}

class UploadTooBigException : Exception
{
    this(string msg)
    {
        super(msg);
    }
}


// get the end boundary marker
uint nextBoundary(string buffer, string boundary, uint startPos)
{
    auto boundaryLength = boundary.length;
    if(!boundaryLength) 
        return uint.max;

    uint bufferLength = buffer.length;

    for (; startPos < bufferLength; ++startPos) {
        if (buffer[startPos] == '-') { // startPossible boundary
            if ((startPos + boundaryLength) >= bufferLength)
                return uint.max;

            string possibleBoundary = buffer[startPos .. startPos + boundaryLength];

            if (possibleBoundary == boundary)
                return startPos + boundaryLength + 2; // the 2 is newline
        }
    }

    return uint.max;
}


// generate a random file name for the local server storage
string random_file_name( uint length = 16) { 
    auto r = new Random(unpredictableSeed);

    string ret;
    static string alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";

    for ( int i = 0 ; i < length;i++ ) {
        ret ~= alphabet[uniform(0, 51, r)];
	}

    return ret;
}


// add a POST value to the POST object, adding to the list if the key already exists
void addPOSTvalue(string data, string key, string newline, ref string[][string] 
POST) 
{
    auto tokens = data.split(newline);
    if (tokens.length > 1) {
        auto post_value = std.string.join(tokens[1..$], newline);

        if (key in POST)
            POST[key] ~= post_value;
        else
            POST[key] = [post_value];
    }
}


// Save the file on disk and store the file info on FILES
// XXX: Encodings, gzip, base64, etc...
void save_add_file(ubyte[] content, string file_name, ref UploadedFile[] FILES)
{
    string local_name;

    // Generate until there is a path that doesn't exists (before you sent this to the Daily WTF consideer
    // that we're using 16 random chars, so collisions should be extremely rare)
    while(true) {
        local_name = std.path.buildPath(Settings["file_upload_dir"].get!string(), random_file_name());
        if ( !exists(local_name) )
            break;
    }

    UploadedFile ufile;
    ufile.size = content.length;
    ufile.server_file_name = local_name;
    ufile.server_dir = Settings["file_upload_dir"].get!string();
    ufile.file_name = file_name;

    // Now save the file
    std.file.write(local_name, content);

    FILES ~= ufile;
}


// Main function, read the body of the POST request from the socket 
// and parse it into the POST values and the FILES
void parse_multipart_form(string boundary,
                          SJSocket socket,
                          string[string] env,
                          string content_type, 
                          ulong content_length,
                          // output:
                          out string[][string] POST, 
                          out UploadedFile[] FILES)
{

    ulong chunk_size = Settings.get("file_upload_chunk_size", Variant(64*1024)).get!ulong;

    if (!content_length) 
        return;

    uint boundEnd = 0;
    uint boundStart = boundary.length + 2;
    int nameStartPos, nameEndPos, newLinePos, ctype_start, ctype_end;

    // loop over the input, extracting the data
    static string nameField = "name=\"";
    static string fileNameField = "filename=\"";
    static string ctype_field = "Content-Type: ";
    static string newline = "\r\n\r\n";

    // XXX This reads everything in memory, implement reading & writing by reasonable
    // sized chunks
    string buffer = cast(string)socket.receive_until(to!uint(content_length));

    while(1) {
        boundEnd = nextBoundary(buffer, boundary, boundStart );

        if (boundEnd == uint.max)
            break;

        // TODO, figure out why the +6L is needed, im pretty sure its the extra -- , + the \r\n\r\n
        string data = buffer[ boundStart .. ( boundEnd  - ( boundary.length + 6) ) ];
        foreach(token; to!string(data).split(newline))
            writeln(token, "-");

        auto joined = std.string.join(to!string(data).split(newline)[1..$], newline);

        // would have been alot easier to use regexes, but this should perform better
        // XXX: check that is true 

        nameStartPos = indexOf(data, nameField);
        nameStartPos += nameField.length;

        nameEndPos = indexOf( data[nameStartPos..$], "\"" ) + nameStartPos;

        string name = data[ nameStartPos .. nameEndPos ];
        string file_name = null;

        nameStartPos = indexOf(data, fileNameField);

        // Get the file
        if ( nameStartPos != -1 && nameStartPos != data.length ) {
            nameStartPos += fileNameField.length;
            nameEndPos = indexOf(data[nameStartPos..$], "\"") + nameStartPos;
            file_name = data[nameStartPos .. nameEndPos];
            newLinePos = indexOf(data[nameEndPos..$], newLinePos) + nameEndPos + newline.length;

            ubyte[] content = cast(ubyte[]) data[newLinePos..$];
            if ( content.length > Settings["file_upload_max_size"].get!ulong() )
                throw new UploadTooBigException("Upload too big. Max size: " 
                                                ~ to!string(Settings["file_upload_max_size"].get!ulong()) 
                                                ~ "File size: " ~ to!string(content.length)); 
            save_add_file(content, file_name, FILES);
        }
        else {
            // Not a file, get the post data for this field
            file_name = "";
            addPOSTvalue(data, name, newline, POST);
        }

        boundStart = boundEnd;
    }
}
