local title = "Intel(R) Distribution for GDB"
local desc = "Intel® oneAPI Application Debugger (gdb-oneapi)" 
local url = "URL: https://www.intel.com/content/www/us/en/developer/tools/oneapi/distribution-for-gdb.html"
---------------------------------------------
whatis(title)
whatis(desc)
whatis(url)

---------------------------------------------
local version = myModuleVersion()
local pkgname = myModuleName():gsub("^oneapi/", "")
local root = "/opt/intel/oneapi"
local root = pathJoin(root, pkgname, version)
local target_arch = "intel64"
local target_platform = "linux"
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

-- New vars
setenv("INTEL_PYTHONHOME", pathJoin(root, "opt/debugger"))

-- PATH
prepend_path("PATH", pathJoin(root, "opt/debugger/bin"))

-- LD_LIBRARY_PATH
prepend_path("LD_LIBRARY_PATH", pathJoin(root, "opt/debugger/lib"))

-- Documentation
prepend_path("MANPATH", pathJoin(root, "share/man"))
prepend_path("GDB_INFO", pathJoin(root, "share/info"))
prepend_path("INFOPATH", pathJoin(root, "share/info"))

