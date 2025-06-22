module calbuild.build;

import std.file;
import std.path;
import std.array;
import std.stdio;
import std.format;
import std.process;
import calbuild.project;

int Build() {
	if (!exists(".build")) {
		mkdir(".build");
	}

	auto project = new Project();
	project.Load();

	string cmd = "cac %s -m -o %s " ~ project.vars["BuildFlags"];

	string[] mods;
	foreach (e ; dirEntries(project.vars["SourceFolder"], SpanMode.depth)) {
		writefln("Compiling %s", e.name.baseName());

		string modPath  = "./.build/" ~ e.name.baseName().stripExtension();
		string fCmd     = format(cmd, e.name, modPath);
		auto res        = executeShell(fCmd);
		mods           ~= modPath ~ ".mod";

		if (res.status != 0) {
			stderr.writeln(res.output);
			stderr.writeln("Build failed");
			return 1;
		}
	}

	writeln("Linking...");
	string linkCmd = format(
		"cac link %s -o %s %s", mods.join(" "), project.vars["Name"],
		project.vars["LinkFlags"]
	);

	auto res = executeShell(linkCmd);
	if (res.status != 0) {
		stderr.writeln(res.output);
		stderr.writeln("Linking failed");
		return 1;
	}

	writefln("Built '%s'", project.vars["Name"]);
	return 0;
}
