import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";
import { homedir } from "node:os";
import { isAbsolute, relative, resolve, sep } from "node:path";

const protectedTools = new Set(["read", "edit", "write"]);
const gitRoot = resolve(homedir(), "git");

function expandHome(path: string): string {
	if (path === "~") return homedir();
	if (path.startsWith(`~${sep}`)) return resolve(homedir(), path.slice(2));
	return path;
}

export default function protectedEnv(pi: ExtensionAPI): void {
	pi.on("tool_call", (event, ctx) => {
		if (!protectedTools.has(event.toolName)) return;

		const inputPath = event.input.path;
		if (typeof inputPath !== "string") return;

		const expanded = expandHome(inputPath);
		const absolute = isAbsolute(expanded) ? resolve(expanded) : resolve(ctx.cwd, expanded);
		const fromGitRoot = relative(gitRoot, absolute);
		if (fromGitRoot.startsWith(`..${sep}`) || isAbsolute(fromGitRoot)) return;
		if (!fromGitRoot.split(sep).some((part) => part.startsWith(".env"))) return;

		return { block: true, reason: `Path "${inputPath}" is protected` };
	});
}
