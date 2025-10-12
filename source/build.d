module calbuild.build;

import std.file;
import std.path;
import std.array;
import std.stdio;
import std.format;
import std.process;
import calbuild.project;

int Build(string[] args) {
	if (!exists(".build")) {
		mkdir(".build");
	}

	bool verbose;
	bool noDelete;
	bool profiler;

	for (size_t i = 0; i < args.length; ++ i) {
		switch (args[i]) {
			case "-v": {
				verbose = true;
				break;
			}
			case "-nd": {
				noDelete = true;
				break;
			}
			case "-p": {
				profiler = true;
				break;
			}
			default: {
				stderr.writefln("Unknown flag: '%s'", args[i]);
				return 1;
			}
		}
	}

	auto project = new Project();
	project.Load();
	project.Build(verbose, noDelete, profiler);
	return 0;
}
