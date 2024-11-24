import json
import re
import subprocess
from pathlib import Path
import random

class DefaultDict(dict):
    def __missing__(self, key):
        return 0

def clean_shader_code(shader_code):

    # Srip comments and whitespaces 
    re_remove = re.compile(r"\r| *//.*?$|/\*.*?\*/|^ +", re.DOTALL | re.MULTILINE)
    stripped_code, _ = re_remove.subn("", shader_code)
    #print(fr"{stripped_code = }")
    # Multiple emty lines or spaces, substitute to \n to keep it readable maybe
    re_multispace = re.compile(r"( |\n){2,}")
    shortened_code, _ = re_multispace.subn(r"\n", stripped_code)
    # get tabs
    re_tab = re.compile(br"\t")


    # Find all #defines
    re_find_define = re.compile(r"(#define) (\w*)", re.IGNORECASE)
    defines = [x.group(2) for x in re_find_define.finditer(shortened_code)]
    print(defines)

    # Substitute all occurences with a different name
    substituted_code = shortened_code
    for definition in defines:
        re_definition = re.compile(fr"\b{definition}\b")
        substituted_code, _ = re_definition.subn(f"custom_{definition}", substituted_code)

    re.sub(r"mat\d transpose\(", "void none(", substituted_code)
    pixel_code, _ = re.subn(r"texture2D\(", "getPixel(", substituted_code)

    # These are an idea but not perfect
    # Because while in GLSL the main is always at the end, this is not the case in WebGL
    # And we've aòredy seen the issue appear
    main_code, _ = re.subn(r"void main\(", "vec4 lovrmain(", pixel_code)
    ending_code, _ = re.subn(r"}\s*$", "\treturn Projection * View * Transform * gl_Position;\n}", main_code)

    return ending_code

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
            error_text = result.stdout.splitlines()
            error_line = re.search(r"(?:\w+:.\d+:)(\d+):(.*)" , error_text[1])
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

        print(result.stdout)

        # LOVR does not seem to ever print here
        #print("stderr:", result.stderr)
    return counters

def main():
    shaders_folder = Path("/home/udinanon/Programming/Projects/LOVR/VertexShaderArt/vertexshaderart.com/art")
    shaders = [x for x in shaders_folder.iterdir() if x.is_dir()]
    counters = DefaultDict({
        "success":0,
        "shader_error":0,
        "other_error":0
    })
    for index in range(len(shaders)):
#    for index in range(100): #len(shaders)):
    # index = random.randint(0, len(shaders))
    # index = 212
        shader_code = json.loads((shaders[index] / "art.json").read_bytes() )["settings"]["shader"]
        print(f"{index =}")
        print(f"PATH: {(shaders[index] / "art.json")}")
        print(f"LINK: http://127.0.0.1:8000/art/{shaders[index].parts[-1]}")


        #print(fr"{shader_code =}")
        cleaned_shader_code = clean_shader_code(shader_code)
        #save_shader(cleaned_shader_code)
        counters = test_shader(counters, cleaned_shader_code, index)
    print(counters)
if __name__=="__main__":
    main()

   # [2024-11-21 20:30:59] result 
    #{'success': 1702, 'shader_error': 684, 'other_error': 4, 'overload_precision_error': 500, 'unprocessed_main': 61}
