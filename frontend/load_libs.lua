local ffi = require("ffi")

-- GLFW definitions
ffi.cdef[[
    typedef struct GLFWwindow GLFWwindow;
    int glfwInit(void);
    void glfwTerminate(void);
    void glfwWindowHint(int hint, int value);
    GLFWwindow* glfwCreateWindow(int width, int height, const char* title, void* monitor, void* share);
    void glfwGetWindowSize(GLFWwindow* window, int* width, int* height);
    void glfwDestroyWindow(GLFWwindow* window);
    int glfwWindowShouldClose(GLFWwindow* window);
    void glfwPollEvents(void);
    void glfwSwapBuffers(GLFWwindow* window);
    void glfwMakeContextCurrent(GLFWwindow* window);
    void glfwSetScrollCallback(GLFWwindow* window,void (*callback) (GLFWwindow*,double,double));
    void glfwSetMouseButtonCallback(GLFWwindow* window,void (*callback) (GLFWwindow*,int,int,int));
    void glfwGetCursorPos(GLFWwindow* ,double*,double*);
]]

-- OpenGL definitions
ffi.cdef[[
    typedef unsigned int GLenum;
    typedef unsigned int GLuint;
    typedef int GLint;
    typedef int GLsizei;
    typedef float GLfloat;
    typedef unsigned char GLboolean;
    typedef signed char GLbyte;
    typedef unsigned char GLubyte;
    typedef char GLchar;

    void glGetIntegerv(GLenum target,GLint* data);
    void glViewport(GLint x, GLint y, GLsizei w, GLsizei h);
    void glDisable(int);
    void glClear(unsigned int mask);
    void glClearColor(float red, float green, float blue, float alpha);
    void glPolygonMode(int face, int mode);
    void glGenBuffers(int n, unsigned int *buffers);
    void glBindBuffer(unsigned int target, unsigned int buffer);
    void glBufferData(unsigned int target, ptrdiff_t size, const void *data, unsigned int usage);
    void glGenVertexArrays(int n, unsigned int *arrays);
    void glBindVertexArray(unsigned int array);
    void glVertexAttribPointer(unsigned int index, int size, unsigned int type, unsigned char normalized, int stride, const void *pointer);
    void glEnableVertexAttribArray(unsigned int index);
    void glUseProgram(unsigned int program);
    void glDrawArrays(unsigned int mode, int first, int count);
    unsigned int glCreateShader(unsigned int type);
    void glShaderSource(unsigned int shader, int count, const char **string, const int *length);
    void glCompileShader(unsigned int shader);
    void glGetShaderiv(unsigned int shader, unsigned int pname, int *params);
    void glGetShaderInfoLog(unsigned int shader, int bufSize, int *length, char *infoLog);
    unsigned int glCreateProgram(void);
    void glAttachShader(unsigned int program, unsigned int shader);
    void glLinkProgram(unsigned int program);
    void glGetProgramiv(unsigned int program, unsigned int pname, int *params);
    GLint glGetAttribLocation(GLuint program, GLchar* name);
    void glDeleteShader(unsigned int shader);
    void glDeleteBuffers(GLsizei n , unsigned int* buffers);
    void glLineWidth(float width);
    void glDrawArraysInstanced(unsigned int mode, int first, int count, int instancecount);
    void glEnableVertexAttribArray(unsigned int index);
    void glVertexAttribDivisor(unsigned int index, unsigned int divisor);
    void glGenTextures(int n, unsigned int *textures);
    void glBindTexture(unsigned int target, unsigned int texture);
    void glTexImage2D(unsigned int target, int level, int internalformat, int width, int height, int border, unsigned int format, unsigned int type, const void *pixels);
    void glTexParameteri(unsigned int target, unsigned int pname, int param);
    void glGenerateMipmap(unsigned int target);
    void glActiveTexture(unsigned int texture);
    void glEnable(unsigned int cap);
    void glBlendFunc(unsigned int sfactor, unsigned int dfactor);
    int glGetUniformLocation(unsigned int program, const char *name);
    void glUniform1i(int location, int v0);
    void glUniform3f(int location, float v0, float v1, float v2);
    void glUniform1f(int location, float v0);
    void glUniform2f(int location, float v0, float v1);
]]

-- stb_image definitions
ffi.cdef[[
    unsigned char *stbi_load(const char *filename, int *x, int *y, int *channels_in_file, int desired_channels);
    void stbi_image_free(void *retval_from_stbi_load);
    void stbi_set_flip_vertically_on_load(int flag_true_if_should_flip);
]]

GLFW_CONTEXT_VERSION_MAJOR = 0x00022002
GLFW_CONTEXT_VERSION_MINOR = 0x00022003
GLFW_OPENGL_PROFILE = 0x00022008
GLFW_OPENGL_CORE_PROFILE = 0x00032001
GLFW_MOUSE_BUTTON_RIGHT =  0x00000000
GLFW_PRESS              =  0x00000001
GLFW_RELEASE            =  0x00000000

GL_COLOR_BUFFER_BIT = 0x00004000
GL_ARRAY_BUFFER = 0x8892
GL_STATIC_DRAW = 0x88E4
GL_DYNAMIC_DRAW = 0x88E8
GL_FLOAT = 0x1406
GL_FALSE = 0
GL_LINE = 0x0002
GL_LINE_STRIP = 0x0003
GL_TRIANGLES = 0x0004
GL_TRIANGLE_STRIP = 0x0005
GL_VERTEX_SHADER = 0x8B31
GL_FRAGMENT_SHADER = 0x8B30
GL_COMPILE_STATUS = 0x8B81
GL_LINK_STATUS = 0x8B82
GL_INFO_LOG_LENGTH = 0x8b84
GL_TEXTURE_2D = 0x0DE1
GL_TEXTURE_WRAP_S = 0x2802
GL_TEXTURE_WRAP_T = 0x2803
GL_TEXTURE_MIN_FILTER = 0x2801
GL_TEXTURE_MAG_FILTER = 0x2800
GL_LINEAR = 0x2601
GL_LINEAR_MIPMAP_LINEAR = 0x2703
GL_CLAMP_TO_EDGE = 0x812F
GL_REPEAT = 0x2901
GL_RGB = 0x1907
GL_RGBA = 0x1908
GL_UNSIGNED_BYTE = 0x1401
GL_TEXTURE0 = 0x84C0
GL_BLEND = 0x0BE2
GL_SRC_ALPHA = 0x0302
GL_ONE_MINUS_SRC_ALPHA = 0x0303
GL_POLYGON_MODE = 0xb40
GL_FRONT = 0x0404
GL_BACK = 0x0405
GL_FRONT_AND_BACK = 0x0408
GL_FILL = 0x1b02
GL_CULL_FACE = 	0x0b44
GL_VIEWPORT = 0x0ba2

local glfw = ffi.load("glfw")
local gl = ffi.load("GL")
local stbi = ffi.load("./libstbimage.so")

-- Compile shader helper
local function compile_shader(source, shader_type)
    local shader = gl.glCreateShader(shader_type)
    local source_ptr = ffi.new("const char*[1]", ffi.new("const char*", source))
    gl.glShaderSource(shader, 1, source_ptr, nil)
    gl.glCompileShader(shader)
    local success = ffi.new("int[1]")
    gl.glGetShaderiv(shader, GL_COMPILE_STATUS, success)
    if success[0] == 0 then
        local log = ffi.new("char[512]")
        gl.glGetShaderInfoLog(shader, 512, nil, log)
        error("Shader compilation failed: " .. ffi.string(log))
    end
    return shader
end

-- Create shader program with custom shaders
local function create_shader_program(vertex_src, fragment_src)
    local vertex_shader = compile_shader(vertex_src, GL_VERTEX_SHADER)
    local fragment_shader = compile_shader(fragment_src, GL_FRAGMENT_SHADER)
    local program = gl.glCreateProgram()
    gl.glAttachShader(program, vertex_shader)
    gl.glAttachShader(program, fragment_shader)
    gl.glLinkProgram(program)
    local success = ffi.new("int[1]")
    gl.glGetProgramiv(program, GL_LINK_STATUS, success)
    if success[0] == 0 then
        error("Shader program linking failed")
    end
    gl.glDeleteShader(vertex_shader)
    gl.glDeleteShader(fragment_shader)
    return program
end

---@param array number[]
local function create_vertex_buffer(array)
    local data = ffi.new("float[?]",#array,array)
    local buffer = ffi.new("int[1]")
    gl.glGenBuffers(1,buffer)
    gl.glBindBuffer(GL_ARRAY_BUFFER,buffer[0])
    gl.glBufferData(GL_ARRAY_BUFFER,ffi.sizeof("float")*#array,data,GL_STATIC_DRAW)
    return buffer[0]
end

local gl_util = {
    compile_shader = compile_shader,
    create_shader_program = create_shader_program,
    create_vertex_buffer = create_vertex_buffer
}

return {glfw=glfw,gl=gl,stbi=stbi,gl_util=gl_util}
