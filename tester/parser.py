import json
import re
import subprocess
from pathlib import Path
import argparse
class DefaultDict(dict):
    def __missing__(self, key):
        return 0

def clean_shader_code(shader_code):

    # Srip comments and whitespaces 
    re_remove = re.compile(r"\r| *//.*?$|/\*.*?\*/|^ +", re.DOTALL | re.MULTILINE)
    stripped_code, _ = re_remove.subn("", shader_code)

    # Multiple empty lines or spaces, substitute to \n to keep it readable maybe
    re_multispace = re.compile(r"(\n\s*){2,}")
    shortened_code, _ = re_multispace.subn(r"\n", stripped_code)

    # Fixing Defines
    # Find all #defines
    re_find_define = re.compile(r"(#define)\s+(\w*)", re.IGNORECASE)
    defines = [x.group(2) for x in re_find_define.finditer(shortened_code)]
    #print(defines)
    # Substitute all occurences with a different name
    substituted_code = shortened_code
    for definition in defines:
        re_definition = re.compile(fr"\b{definition}\b")
        substituted_code, _ = re_definition.subn(f"custom{definition}", substituted_code)

    # Fixing struct names
    # Find all structs
    re_find_define = re.compile(r"(struct)\s+(\w*)", re.IGNORECASE)
    structs = [x.group(2) for x in re_find_define.finditer(substituted_code)]
    #print(defines)
    # Substitute all occurences with a different name
    for struct in structs:
        re_struct = re.compile(fr"\b{struct}\b")
        substituted_code, _ = re_struct .subn(f"custom{struct}", substituted_code)


    # Fixing function overriding
    # these regexes override all occurences of the functions, so we don0t use the built in methods at all
    # this ensures better compatibility, but might cause a small loss of precision or performance
    substituted_code, _ = re.subn(r"mat4 transpose\s*\(", "mat4 OVERRIDDEN_transpose(", substituted_code)
    substituted_code, _ = re.subn(r"mat4 inverse\s*\(", "mat4 OVERRIDDEN_inverse(", substituted_code)
    substituted_code, _ = re.subn(r"float round\(", "float OVERRIDDEN_round(", substituted_code)
    substituted_code, _ = re.subn(r"float PI\s*=", "float OVERRIDDEN_PI =", substituted_code)
    substituted_code, _ = re.subn(r"gl_PointSize", "PointSize", substituted_code)
    
    

    # remapping keywords between WebGL APIs and LOVR APIs
    pixel_code, _ = re.subn(r"texture2D\(", "getPixel(", substituted_code)

    # Remove added uniforms, attrubutes and varyings
    #  these could never do anything afaik and are just ignored in WebGL i guess
    # the shaders don0t seem to work even in the original environment, these might just be broken and WebGL isn0t strict enough to notice
    pixel_code, _ = re.subn(r"^uniform.*$\n", "", pixel_code, flags=re.MULTILINE)
    pixel_code, _ = re.subn(r"^varying.*$\n", "", pixel_code, flags=re.MULTILINE)
    pixel_code, _ = re.subn(r"^attribute.*$\n", "", pixel_code, flags=re.MULTILINE)
    
    # Fixing Main 
    # Locate main code block
    main_re = re.compile(r"void(\s)+main\s*\((\w|\s)*\)(\s|\n)*{")
    main_definition_location = main_re.search(pixel_code)
    #print(pixel_code)
    print(main_definition_location)
    # find block end
    # regex can't count sadly
    parenthesis_counter = 1
    line_number = 0
    for symbol in pixel_code[main_definition_location.end():]:
        line_number +=1
        if symbol == "{":
            parenthesis_counter += 1
        elif symbol == "}":
            parenthesis_counter -= 1
        if parenthesis_counter < 1:
            break
    # print(f"START: {main_definition_location.end()}")
    # print(f"END: {main_definition_location.end()+line_number}")
    
    # now extract and process
    main_code_block = pixel_code[main_definition_location.end():main_definition_location.end()+line_number]
    #print(main_code_block)
    # Detect and plug unsemicolon-ed lines
    # detecs if a line ends with a } and a character not from teh first group, with no ; in the middle
    main_code_block, _ = re.subn(r"(?<=[^;\n\s}{}])(?<!;)(\s|\n)*}", ";\n}", main_code_block)
    # substitue al empty returns
    main_code_block, _ = re.subn(r"return;", "return Projection * View * Transform * gl_Position;", main_code_block)
    # ensure code block returns
    main_code_block, _ = re.subn(r"}(\n|\s)*$", "return Projection * View * Transform * gl_Position;\n}", main_code_block)
    # paste it back in
    end_code  = pixel_code[:main_definition_location.end()] + main_code_block + pixel_code[main_definition_location.end()+line_number:]
    # move to the appropriate lovrmain
    end_code, _ = main_re.subn("vec4 lovrmain(){", end_code)
    
    return end_code

def test_shader(counters, shader_code, index, store_shader = None):
    with open("header.vert", "r") as header_handler:
        header_code = header_handler.read()
    full_code = "\n".join([header_code, shader_code]) 
    with open("out.vert", "w") as file_handler:
        file_handler.writelines(full_code)
    if store_shader:
        with open(f"{index}.txt", "w+") as file_handler:
            file_handler.writelines(full_code)
    try:
        result = subprocess.run(["../../binaries/lovr-v0.17.1-x86_64.AppImage",  "./"], capture_output=True,  text=True, timeout=3)
    except subprocess.TimeoutExpired:
        counters["success"]+=1
        #print("Timed out, no probelm!")
    else:
        # print("stdout:", result.stdout)

        if "Could not parse vertex shader:" in result.stdout:
            print("SHADER ERROR")
            counters["shader_error"]+=1
            error_line = re.search(r"(?:ERROR:.\d+:)(\d+):(.*)" , result.stdout)
            error_line_number = int(error_line.group(1))
            faulty_code =full_code.splitlines()[error_line_number-1]
            error_message = error_line.group(2)
            if "overloaded functions must have the same parameter precision qualifiers" in result.stdout: 
                counters["overload_precision_error"]+=1
            if "'main' : function already has a body " in result.stdout:
                counters["unprocessed_main"]+=1
            with open("errors.log", "a") as log_handler:
                log_handler.write(f"{index}, {error_message}, LINE: {error_line_number}, {faulty_code}\n")
        else:
            counters["other_error"]+=1
            error_text = result.stdout.splitlines()
            with open("errors.log", "a") as log_handler:
                log_handler.write(f"{index}, {error_text[0]}, UNKOWN LINE\n")

        print(result.stdout)

        # LOVR does not seem to ever print here
        #print("stderr:", result.stderr)
    return counters

def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("-o", action="store_true", help="Load from in.vert file instead of reading an ID")
    parser.add_argument("-id", type=str, help="Unique id of the shader, can be found in URL", default = "")
    parser.add_argument("-index", help="select specific instance to test", type=int, default=-1)
    parser.add_argument("--all", help="force testing of all indices, not skipping successes", action="store_true")
    parser.add_argument("--errlog", type=str, help="select error log file for indexes to test")

    return parser.parse_args()

def generate_test_ids(parser, shaders):
    if parser.all:
        test_idxs = range(len(shaders))
    elif parser.index >-1:
        if parser.index > len(shaders):
            print("Invalid shader index selected")
            quit()
        test_idxs = [parser.index]
    elif parser.errlog:
        with open(parser.errlog, "r") as errlog_handler:
            errnums = [int(line.split(",")[0]) for line in errlog_handler.readlines()]
        return errnums
    else:
        with open("success.log", "r") as reader:
            success_data = reader.readlines()
        success_idxs = [int(x) for x in success_data]
        test_idxs = [x for x in range(len(shaders)) if x not in success_idxs]    
    return test_idxs

def main():
    parser = parse_args()
    shaders_folder = Path("/home/udinanon/Programming/Projects/LOVR/VertexShaderArt/vertexshaderart.com/art")
    shaders = [x for x in shaders_folder.iterdir() if x.is_dir()]
    counters = DefaultDict({
        "success":0,
        "shader_error":0,
        "other_error":0
    })
    test_idxs = generate_test_ids(parser, shaders)
    for index in test_idxs:
        shader_code = json.loads((shaders[index] / "art.json").read_bytes() )["settings"]["shader"]
        if len(parser.id):
            selected_shader = [shader for shader in shaders if parser.id in shader.name][0]
            shader_code = json.loads((selected_shader / "art.json").read_bytes() )["settings"]["shader"]
        if parser.o:
            with open("in.vert", "r") as file_reader:
                shader_code = file_reader.read()

        logger.debug(f"{index =}")
        print(f"{index =}")
        print(f"PATH: {(shaders[index] / "art.json")}")
        print(f"LINK: http://127.0.0.1:8000/vertexshaderart.com/art/{shaders[index].parts[-1]}")

        #print(fr"{shader_code =}")
        with open("in.vert", "w") as file_writer:
            file_writer.writelines(shader_code)
        cleaned_shader_code = clean_shader_code(shader_code)
        #save_shader(cleaned_shader_code)
        counters = test_shader(counters, cleaned_shader_code, index)
    print(counters)
if __name__=="__main__":

    main()
