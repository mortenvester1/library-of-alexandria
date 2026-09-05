import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";
import { homedir } from "node:os";
import { isAbsolute, relative, resolve, sep } from "node:path";

const protectedTools = new Set(["read", "edit", "write"]);
const gitRoot = resolve(homedir(), "git");
// Credential files; keep in sync with the Read denies in ~/.claude/settings.json.
const protectedPaths = [
	".aws",
	".config/aws",
	".config/gh/hosts.yml",
	".config/gnupg",
	".config/rclone/rclone.conf",
	".kube/config",
	".orca/linear-tokens",
	".ssh",
].map((p) => resolve(homedir(), p));

function expandHome(path: string): string {
	if (path === "~") return homedir();
	if (path.startsWith(`~${sep}`)) return resolve(homedir(), path.slice(2));
	return path;
}

function isWithin(base: string, target: string): boolean {
	const rel = relative(base, target);
	return rel === "" || (rel !== ".." && !rel.startsWith(`..${sep}`) && !isAbsolute(rel));
}

export default function protectedEnv(pi: ExtensionAPI): void {
	pi.on("tool_call", (event, ctx) => {
		if (!protectedTools.has(event.toolName)) return;

		const inputPath = event.input.path;
		if (typeof inputPath !== "string") return;

		const expanded = expandHome(inputPath);
		const absolute = isAbsolute(expanded) ? resolve(expanded) : resolve(ctx.cwd, expanded);

		if (protectedPaths.some((base) => isWithin(base, absolute))) {
			return { block: true, reason: `Path "${inputPath}" is protected` };
		}
		if (!isWithin(gitRoot, absolute)) return;
		if (!relative(gitRoot, absolute).split(sep).some((part) => part.startsWith(".env"))) return;

		return { block: true, reason: `Path "${inputPath}" is protected` };
	});
}
