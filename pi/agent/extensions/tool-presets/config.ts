/**
 * Preset configuration: the `presets.json` schema, validation, glob matching,
 * and the core hard-filter flag check.
 *
 * A preset is a named object with two optional sub-objects:
 *
 *   { "plan": { "tools": { "enable": [...] }, "skills": { "enable": [...] } } }
 *
 * `tools` holds the four tool keys, `skills` holds two; any other key at either
 * level is a validation error that warns and skips the preset.
 */

import { CONFIG_DIR_NAME, getAgentDir, parseFrontmatter } from "@earendil-works/pi-coding-agent";
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";

export const DEFAULT_PRESET = "default";
export const PRESETS_STATE_TYPE = "preset-state";
export const PRESETS_BASELINE_TYPE = "preset-baseline";
const PRESETS_FILE_NAME = "presets.json";

const KNOWN_PRESET_KEYS = new Set(["tools", "skills"]);

interface SubSchema {
	name: string;
	keys: Set<string>;
	pairs: [string, string][];
}

const TOOLS_SCHEMA: SubSchema = {
	name: "tools",
	keys: new Set(["enable", "disable", "hidden", "shown"]),
	pairs: [
		["enable", "disable"],
		["hidden", "shown"],
	],
};

const SKILLS_SCHEMA: SubSchema = {
	name: "skills",
	keys: new Set(["enable", "disable"]),
	pairs: [["enable", "disable"]],
};

export interface ToolRestriction {
	enable?: string[];
	disable?: string[];
	hidden?: string[];
	shown?: string[];
}

export interface SkillRestriction {
	enable?: string[];
	disable?: string[];
}

/** A `string[]` sub-object, keyed by the schema's known keys. */
export type Restriction = Record<string, string[]>;

export interface Preset {
	tools?: ToolRestriction;
	skills?: SkillRestriction;
}

export interface Overrides {
	enabled: string[];
	disabled: string[];
}

export interface PresetState {
	preset: string;
	overrides: Overrides;
}

// ---------------------------------------------------------------------------
// Glob matching: case-sensitive, `*` (any run) and `?` (one char), full string.
// ---------------------------------------------------------------------------

const globCache = new Map<string, RegExp>();

export function globToRegExp(pattern: string): RegExp {
	const cached = globCache.get(pattern);
	if (cached) return cached;

	let source = "^";
	for (const char of pattern) {
		if (char === "*") source += ".*";
		else if (char === "?") source += ".";
		else source += char.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
	}
	const regex = new RegExp(`${source}$`);
	globCache.set(pattern, regex);
	return regex;
}

export function isGlob(pattern: string): boolean {
	return pattern.includes("*") || pattern.includes("?");
}

export function matchesAny(patterns: readonly string[] | undefined, name: string): boolean {
	if (!patterns || patterns.length === 0) return false;
	return patterns.some((pattern) => globToRegExp(pattern).test(name));
}

// ---------------------------------------------------------------------------
// Config loading
// ---------------------------------------------------------------------------

/** Read a JSON file. `value` is undefined for a missing file or a parse error. */
export function readJsonFile(filePath: string): { value: unknown; error?: string } {
	if (!fs.existsSync(filePath)) return { value: undefined };
	try {
		return { value: JSON.parse(fs.readFileSync(filePath, "utf-8")) };
	} catch (error) {
		return { value: undefined, error: error instanceof Error ? error.message : String(error) };
	}
}

/** Parse a string array field; `undefined` when absent, `null` when malformed. */
export function readStringArray(value: unknown): string[] | undefined | null {
	if (value === undefined) return undefined;
	if (!Array.isArray(value)) return null;
	if (value.some((entry) => typeof entry !== "string")) return null;
	return value as string[];
}

function parseSubSchema(
	presetName: string,
	value: unknown,
	schema: SubSchema,
	filePath: string,
): { value: Restriction | undefined } | { warning: string } {
	const skip = (reason: string) => ({
		warning: `tool-presets: preset "${presetName}" in ${filePath} ${reason}; skipped`,
	});

	if (value === undefined) return { value: undefined };
	if (value === null || typeof value !== "object" || Array.isArray(value)) {
		return skip(`"${schema.name}" must be an object`);
	}

	const obj = value as Record<string, unknown>;
	const unknownKeys = Object.keys(obj).filter((key) => !schema.keys.has(key));
	if (unknownKeys.length > 0) return skip(`"${schema.name}" has unknown keys: ${unknownKeys.join(", ")}`);

	const parsed: Restriction = {};
	for (const key of schema.keys) {
		const array = readStringArray(obj[key]);
		if (array === null) return skip(`"${schema.name}.${key}" has a non-array or non-string entry`);
		if (array !== undefined) parsed[key] = array;
	}
	for (const [first, second] of schema.pairs) {
		if (parsed[first] !== undefined && parsed[second] !== undefined) {
			return skip(`declares both "${schema.name}.${first}" and "${schema.name}.${second}"`);
		}
	}

	return { value: parsed };
}

/** Returns the preset, or the warning that explains why it was skipped. */
function parsePreset(name: string, value: unknown, filePath: string): Preset | string {
	const skip = (reason: string) => `tool-presets: preset "${name}" in ${filePath} ${reason}; skipped`;

	if (value === null || typeof value !== "object" || Array.isArray(value)) return skip("must be an object");

	const obj = value as Record<string, unknown>;
	const unknownKeys = Object.keys(obj).filter((key) => !KNOWN_PRESET_KEYS.has(key));
	if (unknownKeys.length > 0) return skip(`has unknown keys: ${unknownKeys.join(", ")}`);

	const tools = parseSubSchema(name, obj.tools, TOOLS_SCHEMA, filePath);
	if ("warning" in tools) return tools.warning;
	const skills = parseSubSchema(name, obj.skills, SKILLS_SCHEMA, filePath);
	if ("warning" in skills) return skills.warning;

	return { tools: tools.value as ToolRestriction | undefined, skills: skills.value as SkillRestriction | undefined };
}

function readPresetsFile(filePath: string): { presets: Map<string, Preset>; warnings: string[] } {
	const presets = new Map<string, Preset>();
	const warnings: string[] = [];

	const { value: raw, error } = readJsonFile(filePath);
	if (error) {
		warnings.push(`tool-presets: failed to parse ${filePath}: ${error}`);
		return { presets, warnings };
	}
	if (raw === undefined) return { presets, warnings };

	if (raw === null || typeof raw !== "object" || Array.isArray(raw)) {
		warnings.push(`tool-presets: ${filePath} must contain an object of named presets`);
		return { presets, warnings };
	}

	for (const [name, value] of Object.entries(raw as Record<string, unknown>)) {
		const result = parsePreset(name, value, filePath);
		if (typeof result === "string") warnings.push(result);
		else presets.set(name, result);
	}

	return { presets, warnings };
}

function collectUnknownTools(preset: Preset, registered: ReadonlySet<string>): string[] {
	const unknown: string[] = [];
	const patterns = [...(preset.tools?.enable ?? []), ...(preset.tools?.disable ?? [])];
	for (const pattern of patterns) {
		if (isGlob(pattern)) continue;
		if (!registered.has(pattern)) unknown.push(pattern);
	}
	return unknown;
}

/** Merge the global and project files, project wins by preset name, then validate. */
export function loadPresets(
	cwd: string,
	registered: ReadonlySet<string>,
): { presets: Map<string, Preset>; warnings: string[] } {
	const merged = new Map<string, Preset>();
	const warnings: string[] = [];

	const files = [path.join(getAgentDir(), PRESETS_FILE_NAME), path.join(cwd, CONFIG_DIR_NAME, PRESETS_FILE_NAME)];
	for (const filePath of files) {
		const { presets, warnings: fileWarnings } = readPresetsFile(filePath);
		warnings.push(...fileWarnings);
		for (const [name, preset] of presets) merged.set(name, preset);
	}

	if (!merged.has(DEFAULT_PRESET)) merged.set(DEFAULT_PRESET, {});

	for (const [name, preset] of merged) {
		const unknown = collectUnknownTools(preset, registered);
		if (unknown.length > 0) warnings.push(`Preset "${name}": unknown tools: ${unknown.join(", ")}`);
	}

	return { presets: merged, warnings };
}

export function normalizeOverrides(input: unknown): Overrides {
	const obj = (input ?? {}) as Record<string, unknown>;
	const enabled = readStringArray(obj.enabled);
	const disabled = readStringArray(obj.disabled);
	return {
		enabled: enabled ?? [],
		disabled: disabled ?? [],
	};
}

// ---------------------------------------------------------------------------
// Skill frontmatter
// ---------------------------------------------------------------------------

/**
 * Frontmatter-only peek at a skill file, for skills known through
 * `pi.getCommands()` alone (which carries no `disableModelInvocation`).
 * `undefined` means unreadable or unparseable, which is treated as an ordinary
 * skill: the same default core uses for an absent key.
 */
export function readSkillFlags(filePath: string): { disableModelInvocation: boolean } | undefined {
	let text: string;
	try {
		text = fs.readFileSync(filePath, "utf-8");
	} catch {
		return undefined;
	}
	try {
		const { frontmatter } = parseFrontmatter(text);
		return { disableModelInvocation: frontmatter["disable-model-invocation"] === true };
	} catch {
		return undefined;
	}
}

// ---------------------------------------------------------------------------
// Dotfiles skill catalogue
// ---------------------------------------------------------------------------

const DOTFILES_SKILLS_PATH = path.join(".agents", "skills");

/**
 * Skill names defined in the dotfiles repo. Its `DOTFILES_HOME/.agents/skills`
 * catalogue is only partially linked into `~/.agents/skills`, so a preset is
 * global config naming both global and per-project skills; a name that exists
 * in the catalogue but is not loaded here is known, not unknown.
 */
export function dotfilesSkillNames(): string[] {
	const envRoot = process.env.DOTFILES_HOME;
	const root = envRoot && envRoot.length > 0 ? envRoot : path.join(os.homedir(), ".dotfiles");
	const dir = path.join(root, DOTFILES_SKILLS_PATH);

	let entries: fs.Dirent[];
	try {
		entries = fs.readdirSync(dir, { withFileTypes: true });
	} catch {
		return [];
	}

	const names: string[] = [];
	for (const entry of entries) {
		if (!entry.isDirectory() && !entry.isSymbolicLink()) continue;
		try {
			const { frontmatter } = parseFrontmatter(fs.readFileSync(path.join(dir, entry.name, "SKILL.md"), "utf-8"));
			names.push(typeof frontmatter.name === "string" && frontmatter.name.length > 0 ? frontmatter.name : entry.name);
		} catch {
			// No SKILL.md, or an unreadable one: not a skill directory.
		}
	}
	return names;
}

// ---------------------------------------------------------------------------
// Core hard-filter flag conflict (decision 13)
// ---------------------------------------------------------------------------

/** Pi parses flags as space-separated tokens; `--flag=value` is not a core flag. */
export function findHardFilterConflict(argv: readonly string[]): string | undefined {
	const hardFlags = new Set(["--exclude-tools", "-xt", "--no-tools", "-nt"]);

	for (let i = 0; i < argv.length; i++) {
		const arg = argv[i];
		if (arg.includes("=")) continue;
		if (hardFlags.has(arg)) return arg;

		if (arg === "--tools" || arg === "-t") {
			const next = argv[i + 1];
			if (next === undefined) continue;
			const entries = next
				.split(",")
				.map((entry) => entry.trim())
				.filter((entry) => entry.length > 0);
			const onlyModifiers =
				entries.length > 0 && entries.every((entry) => entry.startsWith("+") || entry.startsWith("-"));
			if (!onlyModifiers) return arg;
		}
	}

	return undefined;
}

export function hardFilterMessage(flag: string): string {
	return `tool-presets: ${flag} cannot be combined with tool presets; express the restriction in presets.json instead`;
}
