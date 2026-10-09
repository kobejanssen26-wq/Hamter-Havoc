"""Generates run.lua: the game's real scripts (from default.project.json) wrapped for the mock Roblox runtime,
followed by a scene script (argv[1]). Library assets (ModelLibrary/**/build-model.lua, model-config.lua, scripts/)
and every src/ file they mention are embedded too. Output: harness/run.lua (git-ignored)."""
import os, sys, json, re
HERE=os.path.dirname(os.path.abspath(__file__))
ROOT=os.path.abspath(os.path.join(HERE,"..","..",".."))
SRC=os.path.join(ROOT,"src")
PROJECT=json.load(open(os.path.join(ROOT,"default.project.json")))
out=[]
counter=[0]
def nid():
    counter[0]+=1
    return counter[0]

HEADER='''
local M = require("./mock")
local Instance, Vector2, Vector3, CFrame, Color3, UDim, UDim2 = M.Instance, M.Vector2, M.Vector3, M.CFrame, M.Color3, M.UDim, M.UDim2
local NumberRange, NumberSequence, NumberSequenceKeypoint, ColorSequence, ColorSequenceKeypoint, TweenInfo, Random, Enum, Rect = M.NumberRange, M.NumberSequence, M.NumberSequenceKeypoint, M.ColorSequence, M.ColorSequenceKeypoint, M.TweenInfo, M.Random, M.Enum, M.Rect
local task, os, game, workspace = M.task, M.os, M.game, M.workspace
local function warn(...) print("[warn]", ...) end
local rawtypeof = typeof
local function typeof(v)
	local mt = type(v) == "table" and getmetatable(v) or nil
	if type(mt) == "table" and rawget(mt, "__type") then return rawget(mt, "__type") end
	return rawtypeof(v)
end
local RawData = M.RawData
local N = {}
local cache = {}
local function require(inst)
	if cache[inst] ~= nil then return cache[inst] end
	local data = RawData[inst]
	assert(data and data.Source, "require: not a script: " .. tostring(inst))
	local result = data.Source(inst, require)
	if result == nil then error("Module did not return a value: " .. M.InstanceMethods.GetFullName(inst)) end
	cache[inst] = result
	return result
end
local function mk(class, name, parent)
	local inst = M.newInstance(class, true)
	RawData[inst].Name = name
	if parent then M.setParent(inst, parent) end
	return inst
end
'''
out.append(HEADER)

def kind_of(fname):
    if fname.endswith(".server.luau"): return "Script", fname[:-len(".server.luau")]
    if fname.endswith(".client.luau"): return "LocalScript", fname[:-len(".client.luau")]
    if fname.endswith(".luau"): return "ModuleScript", fname[:-len(".luau")]
    return None, None

def lua_source(path):
    return open(path).read()

def emit_script(path, class_, name, parent_id):
    i=nid()
    out.append('N[%d] = mk(%r, %r, N[%d])\nRawData[N[%d]].Source = function(script, require)\n%s\nend\n'%(i,class_,name,parent_id,i,lua_source(path)))
    return i

def emit_dir(path, name, parent_id, as_service=False, service_class=None):
    # directory -> Folder or init module
    entries=sorted(os.listdir(path))
    init=None
    for cand in ("init.luau","init.server.luau","init.client.luau"):
        if cand in entries: init=cand
    if init:
        class_ = {"init.luau":"ModuleScript","init.server.luau":"Script","init.client.luau":"LocalScript"}[init]
        i=nid()
        out.append('N[%d] = mk(%r, %r, N[%d])\nRawData[N[%d]].Source = function(script, require)\n%s\nend\n'%(i,class_,name,parent_id,i,lua_source(os.path.join(path,init))))
    else:
        i=nid()
        if as_service:
            out.append('N[%d] = M.service(%r)\n'%(i,service_class or name))
        else:
            out.append('N[%d] = mk("Folder", %r, N[%d])\n'%(i,name,parent_id))
    for e in entries:
        if e.startswith("init.") : continue
        full=os.path.join(path,e)
        if os.path.isdir(full):
            emit_dir(full,e,i)
        else:
            c,n=kind_of(e)
            if c: emit_script(full,c,n,i)
    return i

# walk the rojo tree
def walk(node, name, parent_id):
    cls=node.get("$className")
    path=node.get("$path")
    if path:
        full=os.path.join(ROOT,path)
        if os.path.isdir(full):
            # service with a path -> service + children from dir ; or folder module
            if parent_id==0 and cls:
                i=nid(); out.append('N[%d] = M.service(%r)\n'%(i,cls))
                for e in sorted(os.listdir(full)):
                    f=os.path.join(full,e)
                    if os.path.isdir(f): emit_dir(f,e,i)
                    else:
                        c,n=kind_of(e)
                        if c: emit_script(f,c,n,i)
                return i
            return emit_dir(full,name,parent_id)
    if parent_id==0:
        i=nid(); out.append('N[%d] = M.service(%r)\n'%(i,cls)); 
    else:
        i=nid(); out.append('N[%d] = mk(%r, %r, N[%d])\n'%(i,cls or "Folder",name,parent_id))
    for k,v in node.items():
        if k.startswith("$"): continue
        walk(v,k,i)
    return i

root=PROJECT["tree"]
out.append('N[0] = M.game\n')
for k,v in root.items():
    if k.startswith("$"): continue
    walk(v,k,0)

out.append('''
local function find(path)
	local cur = game
	for part in string.gmatch(path, "[^%.]+") do
		cur = M.InstanceMethods.FindFirstChild(cur, part)
		assert(cur, "find: missing " .. path .. " at " .. part)
	end
	return cur
end
''')

# ---- ModelLibrary assets ------------------------------------------------------------------------------------
LIB=os.path.join(ROOT,"ModelLibrary")
files={}   # repo-relative path -> text (library scripts + any src file an asset definition mentions)
def long(text):
    level=0
    while ("]"+"="*level+"]") in text: level+=1
    return "["+"="*level+"["+("\n" if text.startswith("\n") else "")+text+"]"+"="*level+"]"
out.append("local ASSETS = {}\nlocal FILES = {}\n")
if os.path.isdir(LIB):
    for dirpath,dirs,names in sorted(os.walk(LIB)):
        dirs.sort()
        if "build-model.lua" in names and "model-config.lua" in names:
            rel=os.path.relpath(dirpath,ROOT).replace(os.sep,"/")
            cfg=open(os.path.join(dirpath,"model-config.lua")).read()
            bld=open(os.path.join(dirpath,"build-model.lua")).read()
            out.append("ASSETS[#ASSETS+1] = { Dir = %r, Config = (function()\n%s\nend)(), Build = (function()\n%s\nend)() }\n"%(rel,cfg,bld))
            sd=os.path.join(dirpath,"scripts")
            if os.path.isdir(sd):
                for n in sorted(os.listdir(sd)):
                    files[rel+"/scripts/"+n]=open(os.path.join(sd,n)).read()
            for m in re.findall(r'"(src/[^"]+\.luau)"',cfg+bld):
                files[m]=open(os.path.join(ROOT,m)).read()
shared=os.path.join(LIB,"_shared","scripts")
if os.path.isdir(shared):
    for n in sorted(os.listdir(shared)):
        files["ModelLibrary/_shared/scripts/"+n]=open(os.path.join(shared,n)).read()
for k,v in files.items():
    out.append("FILES[%r] = %s\n"%(k,long(v)))
for scene in sys.argv[1:]:
    text=open(scene).read()
    for m in re.findall(r'"(src/[^"]+\.luau)"',text):   # game files a scene packages into models
        if m not in files:
            files[m]=open(os.path.join(ROOT,m)).read()
            out.append("FILES[%r] = %s\n"%(m,long(files[m])))
    out.append(text)
open(os.path.join(HERE,"run.lua"),"w").write("\n".join(out))
print("generated run.lua with", counter[0], "nodes")
