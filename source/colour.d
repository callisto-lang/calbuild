module calbuild.colour;

enum Colour {
	Reset,
	Red,
	Green,
	Yellow,
	Blue,
	Purple,
	Cyan
}

string Reset() {
	version (Windows) {
		return "";
	}
	else {
		return "\x1b[0m";
	}
}

string GetColour(Colour colour) {
	version (Windows) {
		return "";
	}
	else {
		final switch (colour) {
			case Colour.Reset:  return "\x1b[0m";
			case Colour.Red:    return "\x1b[31m";
			case Colour.Green:  return "\x1b[32m";
			case Colour.Yellow: return "\x1b[33m";
			case Colour.Blue:   return "\x1b[34m";
			case Colour.Purple: return "\x1b[35m";
			case Colour.Cyan:   return "\x1b[36m";
		}
	}
}
