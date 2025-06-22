module calbuild.app;

import std.stdio;
import std.string;
import calbuild.init;
import calbuild.build;

private string usage = "
Usage: calbuild COMMAND <...>

Commands:
	init  - Create project
	build - Build project
";

int main(string[] args) {
	if (args.length == 1) {
		writeln(usage.strip());
		return 0;
	}

	switch (args[1]) {
		case "init":  return Init();
		case "build": return Build();
		default: {
			stderr.writefln("Unknown command '%s'", args[1]);
			return 1;
		}
	}
}
