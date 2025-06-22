module calbuild.project;

import std.file;
import std.stdio;
import core.stdc.stdlib : exit;
import calbuild.ysl;

class Project {
	string[string] vars;

	this() {
		
	}

	void Load() {
		if (!exists("project.ysl")) {
			stderr.writeln("No project here");
			exit(1);
		}

		// set default values
		vars["SourceFolder"] = "source";
		vars["BuildFlags"]   = "";
		vars["LinkFlags"]    = "";

		auto code = readText("project.ysl");
		auto ysl  = new YSLEnv();

		ysl.funcs["set"] = (YSLEnv env, string[] args) {
			if (args.length != 2) {
				stderr.writeln("set: Requires 2 parameters");
				exit(1);
			}

			vars[args[0]] = args[1];
		};
		ysl.Run(code);

		if ("Name" !in vars) {
			stderr.writeln("Project must have 'Name' value");
			exit(1);
		}
	}
}
