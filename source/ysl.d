module calbuild.ysl;

import std.stdio;
import std.string;
import core.stdc.stdlib : exit;

char EscapeToChar(char ch) {
	switch (ch) {
		case '0': return 0;
		case 'n': return '\n';
		case 'r': return '\r';
		case 'e': return '\x1b';
		default:  return 255;
	}
}

string[] Split(string str, ulong line) {
	string[] ret;
	string   reading;
	bool     inString;

	for (size_t i = 0; i < str.length; ++ i) {
		if (inString) {
			switch (str[i]) {
				case '"': {
					ret      ~= reading;
					reading   = "";
					inString  = false;
					continue;
				}
				case '\\': {
					++ i;

					if (i >= str.length) {
						stderr.writeln(
							"Line %d: Unexpected end of line interpreting escape",
							line
						);
						exit(1);
					}

					char ch = EscapeToChar(str[i]);

					if (ch == 255) {
						stderr.writefln("Line %d: Invalid escape %c", line, ch);
						exit(1);
					}

					reading ~= ch;
					break;
				}
				default: reading ~= str[i];
			}
		}
		else {
			switch (str[i]) {
				case '"': {
					inString = true;
					break;
				}
				case ' ':
				case '\t': {
					if (reading.strip() == "") {
						reading = "";
						break;
					}

					ret     ~= reading;
					reading  = "";
					break;
				}
				default: {
					reading ~= str[i];
					break;
				}
			}
		}
	}

	if (reading.strip() != "") {
		ret ~= reading;
	}

	return ret;
}

alias YSLFunc = void delegate(YSLEnv env, string[] args);

class YSLEnv {
	YSLFunc[string] funcs;

	this() {
		funcs["#"] = (YSLEnv env, string[] args) {};
	}

	void Run(string program) {
		auto lines = program.split("\n");

		foreach (i, ref line ; lines) {
			auto parts = line.Split(i + 1);

			if (parts.length == 0) continue;

			if (parts[0] !in funcs) {
				stderr.writefln("Line %d: Function '%s' doesn't exist", i + 1, parts[0]);
				exit(1);
			}

			funcs[parts[0]](this, parts[1 .. $]);
		}
	}
}
