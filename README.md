# CalBuild
Early Callisto build system

## Compile
```
dub build
```

## Usage
### Creating a project
```
calbuild init
```

### Compiling a project
```
calbuild build
```

## Variables
- `BuildFlags` - Flags passed to the compiler while building modules
- `LinkFlags`  - Flags passed to the module linker
- `Name`       - Name of project, and executable
