// Syntax-checks a Lua file without printing the AST. Exit code 1 on error.
const fs = require("fs");
const luaparse = require("luaparse");
const file = process.argv[2];
try {
  luaparse.parse(fs.readFileSync(file, "utf8"), { luaVersion: "5.1" });
} catch (e) {
  console.error(`${file}: ${e.message}`);
  process.exit(1);
}
