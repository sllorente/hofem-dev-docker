---------------------------------------------
local pkgname    = myModuleName()
local version    = myModuleVersion()
local pkgnamever = myModuleFullName()
---------------------------------------------
local rootapps = "/opt"
local hierA = hierarchyA(pkgnamever,1)
local compiler = hierA[1]
local compilerD  = compiler:gsub("/","-")
---------------------------------------------
local root = pathJoin(rootapps, compilerD, pkgnamever)
-- Ubuntu development packages are shared by the GNU hierarchy.
local system = compiler:match("^gcc/") ~= nil
local libdir
if system then
  root = pkgname == "gidpost" and "/usr/local" or "/usr"
  local multiarch = capture("gcc -print-multiarch"):gsub("%s+", "")
  libdir = root == "/usr" and pathJoin(root, "lib", multiarch) or pathJoin(root, "lib")
elseif mode() == "load" and not isDir(root) then
  LmodError("Library build is unavailable: " .. root)
end
local bin = pathJoin(root, "bin")
local lib = libdir or pathJoin(root, "lib")
local include = pathJoin(root, "include")
if system and (pkgname == "scotch" or pkgname == "ptscotch" or pkgname == "arpack" or pkgname == "parpack") then
  include = pathJoin(include, pkgname == "ptscotch" and "scotch" or (pkgname == "parpack" and "arpack" or pkgname))
end

whatis("Name:        " .. pkgname)
whatis("Version:     " .. version)

if mode() == "load" then
  LmodMessage("Loading " .. pkgname .. " version " .. version .. " compiled with " .. compiler)
end

-- GRF
setenv("GRF_" .. pkgname:upper() .. "ROOT", root)
setenv("GRF_" .. pkgname:upper() .. "LIB", lib)
setenv("GRF_" .. pkgname:upper() .. "INC", include)
setenv("GRF_" .. pkgname:upper() .. "BIN", bin)
setenv("GRF_" .. pkgname:upper() .. "_VERSION", version)

-- LD_LIBRARY_PATH why not?
if not system then prepend_path("LD_LIBRARY_PATH", lib) end
