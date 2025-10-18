module calbuild.clean;

import std.file;
import std.stdio;
import calbuild.colour;

int Clean(string[] args) {
	if (!exists("project.ysl")) {
		stderr.writeln("No calbuild project here");
		return 1;
	}

	writefln("%s  Cleaning%s build artifacts", GetColour(Colour.Green), Reset());
	rmdirRecurse(".build");
	return 0;
}
