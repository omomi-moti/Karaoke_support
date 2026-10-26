#!/bin/bash
# PreToolUse(Bash): main への push と、project.pbxproj を git add することを止める。
command=$(jq -r '.tool_input.command // empty')

if printf '%s' "$command" | grep -Eq 'git[[:space:]]+push([[:space:]].*)?[[:space:]](origin[[:space:]]+)?(HEAD:)?main([[:space:]]|$)'; then
	echo "main には直接 push しない決まりです（CLAUDE.md の Git Conventions）。PR を通してください。" >&2
	exit 2
fi

if printf '%s' "$command" | grep -Eq 'git[[:space:]]+add([[:space:]].*)?project\.pbxproj'; then
	echo "project.pbxproj のビルド番号は、本人に頼まれたときしか入れない決まりです（CLAUDE.md の Working with Claude）。" >&2
	exit 2
fi

exit 0
