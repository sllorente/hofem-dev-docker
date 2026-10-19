local version = myModuleVersion()
local component = myModuleName():gsub("^oneapi/", "")
local intel_root = "/opt/intel/oneapi"
local root = pathJoin(intel_root, component, version)
local target_arch = "intel64"
local target_platform = "linux"
local bin = pathJoin(root, "bin")
local include = pathJoin(root, "include")

whatis("Add oneap-cli sample browser to PATH and oneAPI samples include dirs into CPATH.")

if mode() == "load" then
   LmodMessage("Loading " .. component .. " v." .. version)
end
if mode() == "unload" then
   LmodMessage("Unloading " .. component .. " v." .. version)
end

-- New vars
setenv("ONEAPI_ROOT", intel_root)

-- PATH
prepend_path("PATH", bin)
prepend_path("CPATH", include)

