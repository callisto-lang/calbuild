module calbuild.project;

import std.file;
import std.path;
import std.stdio;
import std.array;
import std.format;
import std.string;
import std.process;
import core.stdc.stdlib : exit, system;
import calbuild.ysl;
import calbuild.colour;

struct SubProject {
	string name;
	string path;
}

class Project {
	YSLEnv       ysl;
	SubProject[] projects;
	string[]     deps;

	this() {
		ysl = new YSLEnv();
	}

	void SetupYSL() {
		ysl.funcs["set"] = YSLFunc(2, (string[] args) {
			ysl.vars[args[0]] = args[1];
		});
		ysl.funcs["project"] = YSLFunc(2, (string[] args) {
			string dir = args[1][0] == '/'?
				args[1] : ysl.vars["Dir"] ~ "/" ~ args[1];

			projects ~= SubProject(args[0], dir);
		});
		ysl.funcs["add"] = YSLFunc(2, (string[] args) {
			if (args[0] in ysl.vars) {
				ysl.vars[args[0]] = ysl.vars[args[0]] ~ args[1];
			}
			else {
				ysl.vars[args[0]] = args[1];
			}
		});
		ysl.funcs["depends"] = YSLFunc(1, (string[] args) {
			string dir = args[0][0] == '/'? args[0] : ysl.vars["Dir"] ~ "/" ~ args[0];

			if (!exists(dir ~ "/project.ysl")) {
				stderr.writefln("'%s' is not a calbuild project", args[0]);
				exit(1);
			}

			auto oldDir = ysl.vars["Dir"];
			ysl.vars["Dir"] = dir;
			ysl.Run(readText(args[0] ~ "/project.ysl"));
			ysl.vars["Dir"] = oldDir;
		});
	}

	void Load(string path = "project.ysl") {
		static firstLoad = true;

		if (!exists(path)) {
			stderr.writeln("No project here");
			exit(1);
		}

		// set default values
		if (firstLoad) {
			ysl.vars["BuildFlags"] = "";
			ysl.vars["LinkFlags"]  = "";
			firstLoad          = false;
		}

		SetupYSL();

		ysl.vars["Dir"] = dirName(path);

		ysl.Run(readText(path));

		if ("Name" !in ysl.vars) {
			stderr.writeln("Project must have 'Name' value");
			exit(1);
		}
	}

	void Build(bool verbose, bool noDelete, bool profiler) {
		string cmd = "cac %s -m -o %s -i ./.build/ " ~ ysl.vars["BuildFlags"];

		if (profiler) {
			cmd ~= " -p";
		}

		writefln(
			"%s   Starting%s build of application '%s'",
			GetColour(Colour.Yellow), Reset(), ysl.vars["Name"]
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

		writefln(
			"%s    Linking%s %s", GetColour(Colour.Green), Reset(), ysl.vars["Name"]
		);

		// get all modules
		string[] mods;
		foreach (e ; dirEntries(".build", SpanMode.shallow)) {
			mods ~= e.name;
		}

		string linkCmd = format(
			"cac link %s -o %s %s", mods.join(" "), ysl.vars["Name"],
			ysl.vars["LinkFlags"]
		);

		auto res = executeShell(linkCmd);
		if (res.status != 0) {
			stderr.writeln(res.output);
			stderr.writeln(GetColour(Colour.Red) ~ "Linking failed");
			exit(1);
		}

		writefln(
			"%s      Built%s project '%s'", GetColour(Colour.Green), Reset(),
			ysl.vars["Name"]
		);
	}
}
