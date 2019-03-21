require 'busted.runner'()

local assert = require 'spec.assert'
local euluna_parser = require 'euluna.parsers.euluna_std_default'.parser
local lua_generator = require 'euluna.generators.lua_generator'
local analyzer = require 'euluna.analyzers.type_analyzer'
local stringx = require 'pl.stringx'

local function assert_generate_lua(euluna_code, lua_code)
  lua_code = lua_code or euluna_code
  local ast = assert.parse_ast(euluna_parser, euluna_code)
  assert(analyzer:analyze(ast))
  local generated_code = assert(lua_generator:generate(ast))
  assert.same(stringx.rstrip(lua_code), stringx.rstrip(generated_code))
end

describe("Euluna should parse and generate Lua", function()

it("empty file", function()
  assert_generate_lua("", "")
end)
it("return", function()
  assert_generate_lua("return")
  assert_generate_lua("return 1")
  assert_generate_lua("return 1, 2")
end)
it("number", function()
  assert_generate_lua("return 1, 1.2, 1e2, 0x1f, 0b10",
                      "return 1, 1.2, 1e2, 0x1f, 2")
end)
it("string", function()
  assert_generate_lua([[return 'a', "b", [=[c]=] ]], [[return "a", "b", "c"]])
  assert_generate_lua([[return "'", '"']])
  assert_generate_lua([[return "'\1", '"\1']])
end)
it("boolean", function()
  assert_generate_lua("return true, false")
end)
it("nil", function()
  assert_generate_lua("return nil")
end)
it("varargs", function()
  assert_generate_lua("return ...")
end)
it("table", function()
  assert_generate_lua("return {}")
  assert_generate_lua('return {a, "b", 1}')
  assert_generate_lua('return {a = 1, [1] = 2}')
end)
it("function", function()
  assert_generate_lua("return function() end")
  assert_generate_lua("return function()\n  return\nend")
  assert_generate_lua("return function(a, b, c) end")
end)
it("indexing", function()
  assert_generate_lua("return a.b")
  assert_generate_lua("return a[b], a[1]")
  assert_generate_lua('return ({})[1]', 'return ({})[1]')
  assert_generate_lua('return ({}).a', 'return ({}).a')
end)
it("call", function()
  assert_generate_lua("f()")
  assert_generate_lua("return f()")
  assert_generate_lua("f(g())")
  assert_generate_lua("f(a, 1)")
  assert_generate_lua("f 'a'", 'f("a")')
  assert_generate_lua("f {}", 'f({})')
  assert_generate_lua('a.f()')
  assert_generate_lua('a.f "s"', 'a.f("s")')
  assert_generate_lua("a.f {}", "a.f({})")
  assert_generate_lua("a:f()")
  assert_generate_lua("return a:f()")
  assert_generate_lua("a:f(a, 1)")
  assert_generate_lua('a:f "s"', 'a:f("s")')
  assert_generate_lua("a:f {}", 'a:f({})')
  assert_generate_lua('("a")()', '("a")()')
  assert_generate_lua('g()()', 'g()()')
  assert_generate_lua('({})()', '({})()')
  assert_generate_lua('("a"):f()', '("a"):f()')
  assert_generate_lua('g():f()', 'g():f()')
  assert_generate_lua('({}):f()', '({}):f()')
end)
it("if", function()
  assert_generate_lua("if a then\nend")
  assert_generate_lua("if a then\nelseif b then\nend")
  assert_generate_lua("if a then\nelseif b then\nelse\nend")
end)
it("switch", function()
  assert_generate_lua("switch a case b then else end", [[
local __switchval1 = a
if __switchval1 == b then
else
end]])
  assert_generate_lua("switch a case b then f() case c then g() else h() end",[[
local __switchval1 = a
if __switchval1 == b then
  f()
elseif __switchval1 == c then
  g()
else
  h()
end]])
end)
it("do", function()
  assert_generate_lua("do\n  return\nend")
end)
it("while", function()
  assert_generate_lua("while a do\nend")
end)
it("repeat", function()
  assert_generate_lua("repeat\nuntil a")
end)
it("for", function()
  assert_generate_lua("for i=1,10 do\nend")
  assert_generate_lua("for i=1,10,2 do\nend")
  assert_generate_lua("for i in a, f() do\nend")
  assert_generate_lua("for i, j, k in f() do\nend")
end)
it("break", function()
  assert_generate_lua("while true do\n  break\nend")
end)
it("goto", function()
  assert_generate_lua("::mylabel::\ngoto mylabel")
end)
it("variable declaration", function()
  assert_generate_lua("local a")
  assert_generate_lua("local a = 1")
  assert_generate_lua("local a, b, c = 1, 2")
  assert_generate_lua("local a, b, c = 1, 2, 3")
  assert_generate_lua("var a", "a = nil")
  assert_generate_lua("var a, b = 1", "a, b = 1, nil")
  assert_generate_lua("var a, b = 1, 2", "a, b = 1, 2")
  assert_generate_lua("function f() var a end", "function f()\n  local a\nend")
end)
it("assignment", function()
  assert_generate_lua("a = 1")
  assert_generate_lua("a, b = 1, 2")
  assert_generate_lua("a.b, a[1] = x, y")
end)
it("function definition", function()
  assert_generate_lua("local function f()\nend")
  assert_generate_lua("function f()\nend")
  assert_generate_lua("function f(a)\nend")
  assert_generate_lua("function f(a, b, c)\nend")
  assert_generate_lua("function a.f()\nend")
  assert_generate_lua("function a.b.f()\nend")
  assert_generate_lua("function a:f()\nend")
  assert_generate_lua("function a.b:f()\nend")
  assert_generate_lua("function f(a: integer): integer\nend", "function f(a)\nend")
end)
it("unary operators", function()
  assert_generate_lua("return not a")
  assert_generate_lua("return -a")
  assert_generate_lua("return ~a")
  assert_generate_lua("return #a")
  assert_generate_lua("return $a", "return tostring(a)")
end)
it("binary operators", function()
  assert_generate_lua("return a or b, a and b")
  assert_generate_lua("return a ~= b, a == b")
  assert_generate_lua("return a <= b, a >= b")
  assert_generate_lua("return a < b, a > b")
  assert_generate_lua("return a | b, a ~ b, a & b")
  assert_generate_lua("return a << b, a >> b")
  assert_generate_lua("return a + b, a - b")
  assert_generate_lua("return a * b, a / b, a // b")
  assert_generate_lua("return a % b")
  assert_generate_lua("return a ^ b")
  assert_generate_lua("return a .. b")
end)
it("ternary operators", function()
  assert_generate_lua("return b if a else c", "return a and b or c")
end)

end)