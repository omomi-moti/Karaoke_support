#!/bin/bash
# PostToolUse(Edit|Write): Presentation のファイルに具体的な Repository の型が入ったら知らせる。
file=$(jq -r '.tool_input.file_path // .tool_response.filePath // empty')

case "$file" in
	*/Sources/Presentation/*.swift) ;;
	*) exit 0 ;;
esac

if matches=$(grep -nE 'SwiftData[A-Z][A-Za-z]*Repository' "$file"); then
	echo "Presentation に具体的な Repository の型があります。…RepositoryProtocol を環境から受け取ってください（.claude/rules/presentation.md）。" >&2
	echo "$matches" >&2
	exit 2
fi

exit 0
