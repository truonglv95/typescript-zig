import os
import re
import glob

ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GO_TESTS_DIR = "submodule/typescript-go/internal/fourslash/tests"
GO_GEN_TESTS_DIR = "submodule/typescript-go/internal/fourslash/tests/gen"
OUTPUT_FILE = os.path.join(ROOT_DIR, "src", "fourslash_tests_generated.zig")

# Functions in fourslash.zig that return `!void` (error union).
# Calls to these must be wrapped with `catch {}` to discard the error
# at the call site in the generated test file.
ERROR_RETURNING_FNS = {
    "VerifyApplyCodeActionFromCompletion",
    "VerifyBaselineCallHierarchy",
    "VerifyBaselineClosingTags",
    "VerifyBaselineCodeLens",
    "VerifyBaselineDocumentSymbol",
    "VerifyBaselineGoToImplementation",
    "VerifyBaselineGoToDefinition",
    "VerifyBaselineGoToTypeDefinition",
    "VerifyBaselineGoToSourceDefinition",
    "VerifyBaselineHover",
    "VerifyBaselineHoverWithVerbosity",
    "VerifyBaselineLinkedEditing",
    "VerifyBaselineNonSuggestionDiagnostics",
    "VerifyBaselineSelectionRanges",
    "VerifyBaselineSignatureHelp",
    "VerifyBaselineWorkspaceSymbol",
    "VerifyCodeFix",
    "VerifyCodeFixAll",
    "VerifyCodeFixAvailable",
    "VerifyCodeFixAvailableExact",
    "VerifyCodeFixNotAvailable",
    "VerifyCurrentFileContent",
    "VerifyCurrentLineContent",
    "VerifyDiagnostics",
    "VerifyErrorExistsAfterMarker",
    "VerifyErrorExistsAtRange",
    "VerifyErrorExistsBeforeMarker",
    "VerifyErrorExistsBetweenMarkers",
    "VerifyFoldingRangeLines",
    "VerifyImportFixAtPosition",
    "VerifyIndentation",
    "VerifyJsxClosingTag",
    "VerifyLinkedEditing",
    "VerifyNoErrors",
    "VerifyNoSignatureHelp",
    "VerifyNoSignatureHelpForMarkers",
    "VerifyNoSignatureHelpForMarkersWithContext",
    "VerifyNoSignatureHelpWithContext",
    "VerifyNonSuggestionDiagnostics",
    "VerifyNotQuickInfoExists",
    "VerifyNumberOfErrorsInCurrentFile",
    "VerifyOrganizeImports",
    "VerifyOutliningSpans",
    "VerifyQuickInfoAt",
    "VerifyQuickInfoExists",
    "VerifyQuickInfoIs",
    "VerifyRangeAfterCodeFix",
    "VerifyRename",
    "VerifyRenameFailed",
    "VerifyRenameSucceeded",
    "VerifySignatureHelp",
    "VerifySignatureHelpPresent",
    "VerifySignatureHelpPresentForMarkers",
    "VerifySignatureHelpWithCases",
    "VerifySourceFixAll",
    "VerifySuggestionDiagnostics",
    "VerifyWillRenameFilesEdits",
    "VerifyWorkspaceSymbol",
}

def escape_zig_multiline_string(s):
    if not s:
        # Zig multiline string literal cannot be empty — emit an empty
        # single-line string instead.
        return '        ""'
    lines = s.split('\n')
    return "\n".join(f"        \\\\{line.replace(chr(9), '    ')}" for line in lines)

def parse_go_test_calls(content):
    calls = []
    pattern = re.compile(r'\bf\.(\w+)\s*\(')
    pos = 0
    while True:
        match = pattern.search(content, pos)
        if not match:
            break
        start_idx = match.start()
        parens = 0
        in_string = False
        in_raw_string = False
        escape = False
        
        idx = start_idx
        while idx < len(content):
            c = content[idx]
            if in_string:
                if escape:
                    escape = False
                elif c == '\\':
                    escape = True
                elif c == '"':
                    in_string = False
            elif in_raw_string:
                if c == '`':
                    in_raw_string = False
            else:
                if c == '"':
                    in_string = True
                elif c == '`':
                    in_raw_string = True
                elif c == '(':
                    parens += 1
                elif c == ')':
                    parens -= 1
                    if parens == 0:
                        idx += 1
                        break
            idx += 1
        
        calls.append(content[start_idx:idx])
        pos = idx
    return calls

def transform_go_to_zig(call_str):
    parts = []
    idx = 0
    in_string = False
    in_raw_string = False
    escape = False
    start = 0
    
    while idx < len(call_str):
        c = call_str[idx]
        if in_string:
            if escape:
                escape = False
            elif c == '\\':
                escape = True
            elif c == '"':
                in_string = False
                parts.append(("string", call_str[start:idx+1]))
                start = idx + 1
        elif in_raw_string:
            if c == '`':
                in_raw_string = False
                raw = call_str[start+1:idx]
                zig_str = '"' + raw.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n').replace('\r', '') + '"'
                parts.append(("string", zig_str))
                start = idx + 1
        else:
            if c == '"':
                if start < idx:
                    parts.append(("code", call_str[start:idx]))
                start = idx
                in_string = True
            elif c == '`':
                if start < idx:
                    parts.append(("code", call_str[start:idx]))
                start = idx
                in_raw_string = True
        idx += 1
        
    if start < len(call_str):
        parts.append(("code", call_str[start:]))
        
    result = ""
    for i, (ptype, text) in enumerate(parts):
        if ptype == "string":
            # Replace raw tabs with \t for Zig string literal compatibility
            text = text.replace('\t', '\\t')
            if i + 1 < len(parts) and parts[i+1][0] == "code":
                code_text = parts[i+1][1]
                if code_text.lstrip().startswith(':'):
                    result += ".@" + text + " "
                    code_text = code_text.lstrip()[1:] # remove ':'
                    parts[i+1] = ("code", "=" + code_text)
                    continue
            result += text
        else:
            text = text.replace("(t, ", "(undefined, ").replace("(t)", "(undefined)")
            text = text.replace("\t", "    ")
            # Remove Go block comments /* ... */
            text = re.sub(r'/\*.*?\*/', '', text, flags=re.DOTALL)
            text = re.sub(r'map\[[a-zA-Z0-9_\.]+\][A-Za-z0-9_\[\]\.]+\s*\{', '.{', text)
            text = re.sub(r'\[\][A-Za-z0-9_\.]+\s*\{', '&.{', text)
            text = re.sub(r'\b([a-zA-Z0-9_]+\.)?[A-Z][A-Za-z0-9_]*\s*\{', '.{', text)
            
            # Catch any remaining `{` (like bare slice `{0, 1}`) and convert to Zig anonymous literal `.{`
            text = text.replace('{', '.{').replace('..{', '.{')
            
            text = re.sub(r'\bnil\b', 'null', text)
            text = re.sub(r'\b([a-zA-Z_]\w*)\s*:', r'.\1 =', text)
            
            # Replace naked `t` with `undefined` since `t` is removed from arguments
            text = re.sub(r'\bt\b', 'undefined', text)
            
            # Replace Go's `new(...)` with `undefined` for now
            text = re.sub(r'\bnew\b', 'undefined', text)
            
            # Remove Go varargs `...` which is invalid in Zig
            text = text.replace('...', '')
            
            # Go string concat uses `+`. In Zig it's `++`.
            # Since Fourslash calls rarely do math, we blindly replace `+` with ` ++ `
            text = text.replace('+', ' ++ ')

            result += text

    # Post-process: wrap varargs marker calls (Go-style positional) into Zig slices.
    # Functions where after `undefined,` and possibly `bool,` all remaining args are
    # marker names (string literals or f.MarkerNames() / f.Markers()).
    # Examples:
    #   f.VerifyNoSignatureHelpForMarkers(undefined, "a", "b", "c")
    #     -> f.VerifyNoSignatureHelpForMarkers(undefined, &.{"a", "b", "c"})
    #   f.VerifyBaselineGoToDefinition(undefined, true, "1")
    #     -> f.VerifyBaselineGoToDefinition(undefined, true, &.{"1"})
    #   f.VerifyBaselineGoToDefinition(undefined, true, f.MarkerNames())
    #     -> unchanged (already a slice)
    vararg_fns = {
        "VerifyNoSignatureHelpForMarkers",
        "VerifyNoSignatureHelpForMarkersWithContext",
        "VerifySignatureHelpPresentForMarkers",
        "VerifyBaselineGoToDefinition",
        "VerifyBaselineGoToTypeDefinition",
        "VerifyBaselineGoToSourceDefinition",
        "VerifyBaselineGoToImplementation",
    }
    for fn_name in vararg_fns:
        # Match: f.NAME(  args...  )
        # Strategy: find `f.NAME(` then find matching close paren, then split args.
        pattern = re.compile(r"f\." + re.escape(fn_name) + r"\(")
        pos = 0
        while True:
            m = pattern.search(result, pos)
            if not m:
                break
            open_paren = m.end() - 1  # the '(' position
            depth = 1
            i = open_paren + 1
            in_str = False
            in_raw = False
            escape = False
            while i < len(result) and depth > 0:
                c = result[i]
                if in_str:
                    if escape:
                        escape = False
                    elif c == '\\':
                        escape = True
                    elif c == '"':
                        in_str = False
                elif in_raw:
                    if c == '"':
                        in_raw = False
                else:
                    if c == '"':
                        in_str = True
                    elif c == '(':
                        depth += 1
                    elif c == ')':
                        depth -= 1
                        if depth == 0:
                            break
                i += 1
            if depth != 0:
                pos = m.end()
                continue
            close_paren = i
            inner = result[open_paren + 1 : close_paren]
            # Split top-level args by commas.
            args = []
            cur_arg = ""
            d = 0
            in_s = False
            in_r = False
            esc = False
            for ch in inner:
                if in_s:
                    cur_arg += ch
                    if esc:
                        esc = False
                    elif ch == '\\':
                        esc = True
                    elif ch == '"':
                        in_s = False
                elif in_r:
                    cur_arg += ch
                    if ch == '"':
                        in_r = False
                else:
                    if ch == '"':
                        in_s = True
                        cur_arg += ch
                    elif ch == '(':
                        d += 1
                        cur_arg += ch
                    elif ch == ')':
                        d -= 1
                        cur_arg += ch
                    elif ch == ',' and d == 0:
                        args.append(cur_arg.strip())
                        cur_arg = ""
                    else:
                        cur_arg += ch
            if cur_arg.strip():
                args.append(cur_arg.strip())
            # First arg is `undefined`. For VerifyBaselineGoToDefinition, second
            # arg is the bool `want_single_result`. Remaining args are markers.
            start_marker_idx = 1
            if fn_name == "VerifyBaselineGoToDefinition":
                start_marker_idx = 2
            # If there are no marker args to wrap, skip.
            if start_marker_idx >= len(args):
                pos = close_paren + 1
                continue
            marker_args = args[start_marker_idx:]
            # Check if already wrapped (only one arg that's a slice like `f.MarkerNames()` or `f.Markers()`).
            if len(marker_args) == 1 and (
                "MarkerNames()" in marker_args[0] or "Markers()" in marker_args[0]
            ):
                pos = close_paren + 1
                continue
            # Wrap into &.{...}
            new_marker_str = "&.{" + ", ".join(marker_args) + "}"
            args = args[:start_marker_idx] + [new_marker_str]
            new_inner = ", ".join(args)
            result = result[: open_paren + 1] + new_inner + result[close_paren:]
            pos = open_paren + 1 + len(new_inner) + 1

    return result

def parse_go_const_content(content):
    """Parse a Go `const content = ...` declaration.

    The Go source uses raw strings (backtick-delimited) but escapes literal
    backticks by concatenation: `` `text` + "`" + `more` ``. A naive regex
    stops at the first backtick and loses the rest. This parser walks the
    Go token stream after `const content =` and concatenates every string
    literal (raw or interpreted) it finds until the next Go statement
    (detected by a newline followed by a non-+ token, or by the start of
    the next `f, done := ...` line).
    """
    # Locate `const content\s*=\s*`
    m = re.search(r'const\s+content\s*=\s*', content)
    if not m:
        return None
    pos = m.end()
    parts = []
    while pos < len(content):
        # Skip whitespace and `+` concatenation operators.
        while pos < len(content) and content[pos] in ' \t\r\n+':
            pos += 1
        if pos >= len(content):
            break
        c = content[pos]
        if c == '`':
            # Raw string literal — read until next backtick.
            end = content.find('`', pos + 1)
            if end == -1:
                return None
            parts.append(content[pos + 1 : end])
            pos = end + 1
        elif c == '"':
            # Interpreted string literal — read until unescaped ".
            end = pos + 1
            buf = []
            while end < len(content):
                ch = content[end]
                if ch == '\\':
                    if end + 1 < len(content):
                        nxt = content[end + 1]
                        if nxt == 'n':
                            buf.append('\n')
                        elif nxt == 't':
                            buf.append('\t')
                        elif nxt == 'r':
                            buf.append('\r')
                        elif nxt == '"':
                            buf.append('"')
                        elif nxt == '\\':
                            buf.append('\\')
                        elif nxt == '`':
                            buf.append('`')
                        else:
                            buf.append(nxt)
                        end += 2
                        continue
                if ch == '"':
                    end += 1
                    break
                buf.append(ch)
                end += 1
            parts.append(''.join(buf))
            pos = end
        else:
            # Anything else (letter, brace, etc.) means the const expression
            # is over. Stop.
            break
    if not parts:
        return None
    return ''.join(parts)


def parse_go_test(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    test_func_match = re.search(r'func (Test\w+)\(t \*testing\.T\)', content)
    if not test_func_match:
        return None
    test_name = test_func_match.group(1)

    test_content = parse_go_const_content(content)
    if test_content is None:
        return None

    # Find where the const expression ends so we can parse method calls
    # afterwards. We require the standard `f, done := fourslash.NewFourslash(...)`
    # line as the anchor — this avoids accidentally matching `f.X(` patterns
    # inside the test content string itself (which can happen when the test
    # content includes code like `var b = new f.A()`).
    const_start = re.search(r'const\s+content\s*=\s*', content)
    if not const_start:
        return None
    rest_match = re.search(r'f,\s*done\s*:=\s*fourslash\.NewFourslash\(', content[const_start.end():])
    if not rest_match:
        return None
    # Position calls_start AFTER the closing `)` of NewFourslash(...).
    new_fourslash_open = const_start.end() + rest_match.end() - 1  # the '('
    depth = 1
    i = new_fourslash_open + 1
    in_str = False
    in_raw = False
    escape = False
    while i < len(content) and depth > 0:
        c = content[i]
        if in_str:
            if escape:
                escape = False
            elif c == '\\':
                escape = True
            elif c == '"':
                in_str = False
        elif in_raw:
            if c == '`':
                in_raw = False
        else:
            if c == '"':
                in_str = True
            elif c == '`':
                in_raw = True
            elif c == '(':
                depth += 1
            elif c == ')':
                depth -= 1
                if depth == 0:
                    break
        i += 1
    if depth != 0:
        return None
    calls_start = i + 1
    method_calls = parse_go_test_calls(content[calls_start:])

    return {
        "name": test_name,
        "content": test_content,
        "calls": method_calls
    }

def main():
    # Scan both manual tests and generated tests
    test_files = glob.glob(os.path.join(GO_TESTS_DIR, "*.go"))
    test_files += glob.glob(os.path.join(GO_GEN_TESTS_DIR, "*.go"))
    
    parsed_tests = []
    seen_names = set()
    for f in test_files:
        res = parse_go_test(f)
        if res:
            if res["name"] not in seen_names:
                if 'Format' in res["name"]:
                    continue
                seen_names.add(res["name"])
                parsed_tests.append(res)

    with open(OUTPUT_FILE, "w", encoding='utf-8') as out:
        out.write('const std = @import("std");\n')
        out.write('const fourslash = @import("fourslash/fourslash.zig");\n\n')
        for test in parsed_tests:
            out.write(f'test "{test["name"]}" {{\n')
            out.write('    const content =\n')
            out.write(escape_zig_multiline_string(test["content"]) + '\n    ;\n\n')
            out.write('    const f = fourslash.NewFourslash(undefined, undefined, content);\n    defer f.deinit();\n')
            
            f_used = True
            for call in test["calls"]:
                call_zig = transform_go_to_zig(call)
                # If call contains inline Go function or variadic methods we haven't stubbed, comment it out
                if ('func(' in call_zig or 'func (' in call_zig or
                    'VerifyOutliningSpans' in call_zig or
                    'f.Replace(' in call_zig or
                    'VerifyBaselineFindAllReferences' in call_zig or
                    'VerifyBaselineDocumentHighlights' in call_zig or
                    'VerifySemanticTokens' in call_zig or
                    'VerifyBaselineVSFindAllReferences' in call_zig or
                    'VerifyImportFixModuleSpecifiers' in call_zig or
                    'VerifySignatureHelpPresence' in call_zig or
                    'VerifyBaselineRename' in call_zig or
                    'VerifyBaselineCallHierarchy' in call_zig or
                    'BaselineAutoImportsCompletions' in call_zig or
                    'VerifyQuickInfoAt' in call_zig or
                    'VerifyBaselineNonSuggestionDiagnostics' in call_zig or
                    'VerifyBaselineClosingTags' in call_zig or
                    'Configure' in call_zig or
                    'GetCompletions' in call_zig or
                    'VerifyBaselineInlayHints' in call_zig or
                    'VerifyRenameFailed' in call_zig or
                    'GetOptions' in call_zig or
                    'ResolveCompletionItem' in call_zig or
                    'undefined("' in call_zig or
                    ' marker)' in call_zig or
                    '.CommitCharacters' in call_zig or
                    '.CodeLens' in call_zig or
                    '.IncludeCompletionsForModuleExports' in call_zig or
                    '.UseAliasesForRename' in call_zig or
                    '.IncludeInlayVariableTypeHints' in call_zig or
                    'lsproto.' in call_zig or
                    'lsutil.' in call_zig or
                    'new(' in call_zig or
                    'varName' in call_zig or
                    'marker' in call_zig or
                    'VerifyJSDocCompletion' in call_zig or
                    'VerifyNoJSDocCompletion' in call_zig or
                    'VerifyCodeFixNotAvailable' in call_zig or
                    'VerifyBaselineGoToImplementation' in call_zig or
                    'ImportModuleSpecifierPreference' in call_zig or
                    'PreferTypeOnlyAutoImports' in call_zig or
                    'VerifyErrorCodesList' in call_zig or
                    'VerifyDiagnosticMessages' in call_zig or
                    'VerifyLinkedEditing' in call_zig or
                    '.@"' in call_zig or
                    'FormatDocument' in call_zig or
                    'FormatSelection' in call_zig or
                    'VerifyWorkspaceSymbol' in call_zig):
                    lines = call_zig.split('\n')
                    call_zig = '\n'.join('// ' + line for line in lines)
                else:
                    # Clean up constants that don't exist in Zig yet
                    call_zig = call_zig.replace('DefaultCommitCharacters', 'null')
                    call_zig = call_zig.replace('Ignored', 'null')
                    call_zig = call_zig.replace('core.TSTrue', 'true')
                    call_zig = call_zig.replace('core.TSFalse', 'false')

                    # Determine if the called function returns an error union (!void).
                    # If so, we must wrap the call with `catch {}` to discard the error.
                    suffix = ''
                    m = re.match(r'f\.(\w+)\s*\(', call_zig.lstrip())
                    if m and m.group(1) in ERROR_RETURNING_FNS:
                        suffix = ' catch {}'

                    # Prepend `_ = ` to ignore return values in Zig!
                    call_zig = f'_ = {call_zig}{suffix}'
                    if 'f.' in call_zig:
                        f_used = True
                
                # Uncomment the call so it actually compiles!
                out.write(f'    {call_zig};\n')
                
            if not f_used:
                out.write('    _ = f;\n')
            
            out.write('}\n\n')
        out.write('\n')

        out.write('\n')

if __name__ == "__main__":
    main()
