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
	project.Build();
	return 0;
}
