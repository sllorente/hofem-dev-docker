local title = "Intel® Unified Memory Framework"
local desc = "A library for constructing allocators and memory pools."
local url = "URL: https://github.com/oneapi-src/unified-memory-framework"

whatis(title)
whatis(desc)
whatis(url)
prereq("oneapi/compiler")

---------------------------------------------
local intel_root = "/opt/intel/oneapi" 
local target_arch = "intel64"
local target_platform = "linux"
---------------------------------------------
local pkgname    = myModuleName()
local version    = myModuleVersion()
local pkgV  = version:match('%d+')      -- one digit rule
local pkgVV = version:match('%d+%.%d+')  -- two digit rule
if not pkgV then pkgV = version end
if not pkgVV then pkgVV = pkgV end
local root = pathJoin(intel_root, pkgname , pkgVV)
---------------------------------------------

---------------------------------------------
help("This module loads " .. pkgname .. "library.")
---------------------------------------------

if mode() == "load" then
   LmodMessage("Loading " .. title .. " v. " .. version)
end
if mode() == "unload" then
   LmodMessage("Unloading " .. title .. " v. " .. version)
end
---------------------------------------------

-- New vars
setenv("UMF_ROOT", root)

-- LD_LIBRARY_PATH
prepend_path("LD_LIBRARY_PATH", pathJoin(root, "lib"))

-- LIBRARY_PATH
prepend_path("LIBRARY_PATH", pathJoin(root, "lib"))

-- CPATH
prepend_path("CPATH", pathJoin(root, "include"))
prepend_path("C_INCLUDE_PATH", pathJoin(root, "include"))
prepend_path("CPLUS_INCLUDE_PATH", pathJoin(root, "include"))


-- others
prepend_path("CMAKE_PREFIX_PATH", root)

