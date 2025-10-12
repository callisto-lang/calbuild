module calbuild.project;

import std.file;
import std.path;
import std.stdio;
import std.array;
import std.format;
import std.string;
import std.process;
import core.stdc.stdlib : exit, system;
import lumars;
import calbuild.colour;

struct SubProject {
	string name;
	string path;
}

class Project {
	string[string] vars;
	SubProject[]   projects;
	string[]       deps;

	this() {
		
	}

	void SetupLua(ref LuaState lua) {
		lua.globalTable["set"] = (string var, string contents) {
			vars[var] = contents;
		};
		lua.globalTable["get"] = (string var) {
			if (var !in vars) {
				stderr.writefln("Variable '%s' does not exist", var);
				exit(1);
			}

			return vars[var];
		};
		lua.globalTable["project"] = (string project, string directory) {
			projects ~= SubProject(project, directory);
		};
		lua.globalTable["add"] = (string var, string contents) {
			if (var in vars) {
				vars[var] = vars[var] ~ contents;
			}
			else {
				vars[var] = contents;
			}
		};
		lua.globalTable["depends"] = (string dep) {
			if (!exists(dep ~ "/project.lua")) {
				stderr.writefln("'%s' is not a calbuild project", dep);
				exit(1);
			}

			auto lua2 = LuaState(null);
			SetupLua(lua2);

			auto oldDir = vars["Dir"];
			vars["Dir"] = dep;
			lua.doString(readText(dep ~ "/project.lua"));
			vars["Dir"] = oldDir;
		};
	}

	void Load(string path = "project.lua") {
		static firstLoad = true;

		if (!exists(path)) {
			stderr.writeln("No project here");
			exit(1);
		}

		// set default values
		if (firstLoad) {
			vars["BuildFlags"] = "";
			vars["LinkFlags"]  = "";
			firstLoad          = false;
		}

		auto code = readText(path);
		auto lua  = LuaState(null);

		SetupLua(lua);
		vars["Dir"] = dirName(path);
		lua.doString(code);

		if ("Name" !in vars) {
			stderr.writeln("Project must have 'Name' value");
			exit(1);
		}
	}

	void Build(bool verbose, bool noDelete, bool profiler) {
		string cmd = "cac %s -m -o %s -i ./.build/ " ~ vars["BuildFlags"];

		if (profiler) {
			cmd ~= " -p";
		}

		writefln(
			"%s   Starting%s build of application '%s'",
			GetColour(Colour.Yellow), Reset(), vars["Name"]
		);

		void BuildFile(SubProject project, DirEntry e, bool stub) {
			string modPath;

			if (project.path.endsWith(".cal")) {
				modPath = format("./.build/%s", project.name);
			}
			else {
				modPath = format(
					"./.build/%s.%s", project.name, e.name.baseName().stripExtension()
				);
			}

			if (exists(modPath ~ ".mod")) {
				bool modNewer =
					DirEntry(modPath ~ ".mod").timeLastModified > e.timeLastModified;

				if (stub && modNewer) {
					return;
				}
				else if (!stub && modNewer) {
					// if this module is not a stub, then there is no need to compile
					auto mod = File(modPath ~ ".mod", "rb");

					mod.seek(3, SEEK_SET);
					auto flags = mod.rawRead(new ubyte[1])[0];

					if ((flags & 1) == 0) { // 0 if the module is not a stub
						return;
					}
				}
			}

			string fCmd = format(cmd, e.name, modPath) ~ (stub? " -stub" : "");

			if (verbose) {
				writeln(fCmd);
			}

			if (profiler) {
				writefln("File: %s", e.name);
			}

			auto res = system(fCmd.toStringz());

			if (res != 0) {
				stderr.writeln(GetColour(Colour.Red) ~ "Build failed");
				stderr.writefln("Command: %s", fCmd);

				// the build folder now contains incomplete module files, which
				// will ruin the build process, meaning i have to force a clean
				// build next time
				if (!noDelete) {
					rmdirRecurse(".build");
				}
				exit(1);
			}
		}

		// build stubs
		foreach (project ; projects) {
			writefln(
				"%s  Preparing%s project '%s'", GetColour(Colour.Yellow), Reset(),
				project.name
			);

			if (project.path.endsWith(".cal")) {
				BuildFile(project, DirEntry(project.path), true);
			}
			else {
				foreach (e ; dirEntries(project.path, SpanMode.depth)) {
					BuildFile(project, e, true);
				}
			}
		}

		// build actual modules
		foreach (project ; projects) {
			writefln(
				"%s  Compiling%s project '%s'", GetColour(Colour.Green), Reset(),
				project.name
			);

			if (project.path.endsWith(".cal")) {
				BuildFile(project, DirEntry(project.path), false);
			}
			else {
				foreach (e ; dirEntries(project.path, SpanMode.depth)) {
					BuildFile(project, e, false);
				}
			}
		}

		writefln("%s    Linking%s %s", GetColour(Colour.Green), Reset(), vars["Name"]);

		// get all modules
		string[] mods;
		foreach (e ; dirEntries(".build", SpanMode.shallow)) {
			mods ~= e.name;
		}

		string linkCmd = format(
			"cac link %s -o %s %s", mods.join(" "), vars["Name"], vars["LinkFlags"]
		);

		auto res = executeShell(linkCmd);
		if (res.status != 0) {
			stderr.writeln(res.output);
			stderr.writeln(GetColour(Colour.Red) ~ "Linking failed");
			exit(1);
		}

		writefln("%s      Built%s project '%s'", GetColour(Colour.Green), Reset(), vars["Name"]);
	}
}
