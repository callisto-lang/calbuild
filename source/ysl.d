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

alias YSLFuncCall = void delegate(string[] args);

struct YSLFunc {
	size_t      params;
	YSLFuncCall call;
}

class YSLEnv {
	YSLFunc[string] funcs;
	string[string]  vars;

	this() {
		
	}

	string[] Split(string str, ulong line) {
		string[] ret;
		string   reading;
		bool     inString;

		void AssertEnd(size_t i) {
			if (i >= str.length) {
				stderr.writefln("Line %d: Unexpected end of line", line);
				exit(1);
			}
		}

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
						AssertEnd(i);

						char ch = EscapeToChar(str[i]);

						if (ch == 255) {
							stderr.writefln("Line %d: Invalid escape %c", line, ch);
							exit(1);
						}

						reading ~= ch;
						break;
					}
					case '$': {
						++ i;
						AssertEnd(i);

						if (str[i] == '$') {
							reading ~= str[i];
							break;
						}
						/*else if (str[i] == '{') {
							string var;

							while (true) {
								++ i;
								AssertEnd(i);

								if (str[i] == '}') {
									break;
								}
								else {
									var ~= str[i];
								}
							}

							
						}*/ // idk what was happening here
						else {
							stderr.writefln("Line %d: Invalid $ escape", line);
							exit(1);
						}
					}
					default: reading ~= str[i];
				}
			}
			else {
				if (str[i] == '#') {
					break;
				}

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

	void Run(string program) {
		auto lines = program.split("\n");

		foreach (i, ref line ; lines) {
			auto parts = Split(line, i + 1);

			if (parts.length == 0) continue;

			if (parts[0] !in funcs) {
				stderr.writefln("Line %d: Function '%s' doesn't exist", i + 1, parts[0]);
				exit(1);
			}

			auto func = funcs[parts[0]];

			if (parts.length - 1 != func.params) {
				stderr.writefln(
					"Line %d: Function requires %d parameters", i + 1, func.params
				);
				exit(1);
			}

			func.call(parts[1 .. $]);
		}
	}
}
