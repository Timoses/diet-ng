module diet.input;

@property InputFile[] filesFromGroup(alias FILES_GROUP)()
{
	static assert(FILES_GROUP.expand.length % 2 == 0);
	auto ret = new InputFile[FILES_GROUP.expand.length / 2];
	foreach (i, F; FILES_GROUP.expand) {
		static if (i % 2 == 0) {
			ret[i / 2].name = FILES_GROUP.expand[i+1];
			ret[i / 2].contents = FILES_GROUP.expand[i];
		}
	}
	return ret;
}

template collectFiles(string root_file)
{
	import std.algorithm.searching : canFind;
	enum contents = stripUTF8BOM(import(root_file));
	enum baseFiles = collectReferencedFiles!(root_file, contents);
	static if (baseFiles.canFind!(f => f.name == root_file))
		enum collectFiles = baseFiles;
	else enum collectFiles = InputFile(root_file, contents) ~ baseFiles;
}

private template collectReferencedFiles(string file_name, string file_contents)
{
	import std.path : extension;

	enum references = collectReferences(file_contents);
	template impl(size_t i) {
		static if (i < references.length) {
			enum rfiles = impl!(i+1);
			static if (__traits(compiles, import(references[i]))) {
				enum ifiles = collectFiles!(references[i]);
				enum impl = merge(ifiles, rfiles);
			} else static if (__traits(compiles, import(references[i] ~ extension(file_name)))) {
				enum ifiles = collectFiles!(references[i] ~ extension(file_name));
				enum impl = merge(ifiles, rfiles);
			} else enum impl = rfiles;
		} else enum InputFile[] impl = [];
	}
	alias collectReferencedFiles = impl!0;
}

private string[] collectReferences(string content)
{
	import std.string : strip, stripLeft, splitLines;
	import std.algorithm.searching : startsWith;

	string[] ret;
	foreach (i, ln; content.stripLeft().splitLines()) {
		// FIXME: this produces false-positives when a text paragraph is used:
		// p.
		//     This is some text.
		//     import oops, this is also just text.
		ln = ln.stripLeft();
		if (i == 0 && ln.startsWith("extends "))
			ret ~= ln[8 .. $].strip();
		else if (ln.startsWith("include "))
			ret ~= ln[8 .. $].strip();
	}
	return ret;
}

private InputFile[] merge(InputFile[] a, InputFile[] b)
{
	import std.algorithm.searching : canFind;
	auto ret = a;
	foreach (f; b)
		if (!a.canFind!(g => g.name == f.name))
			ret ~= f;
	return ret;
}

struct InputFile {
	string name;
	string contents;
}


template Group(A...) {
	import std.typetuple;
	alias expand = TypeTuple!A;
}

template localAliases(int i, ALIASES...)
{
	static if (i < ALIASES.length) {
		import std.conv : to;
		enum string localAliases = "alias ALIASES["~i.to!string~"] "~__traits(identifier, ALIASES[i])~";\n"
			~localAliases!(i+1, ALIASES);
	} else {
		enum string localAliases = "";
	}
}

private string stripUTF8BOM(string input)
{
	if (input.length >= 3 && input[0 .. 3] == [0xEF, 0xBB, 0xBF])
		return input[3 .. $];
	return input;
}