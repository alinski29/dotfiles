/**
 * Pure resolution: the tool layer (baseline -> preset -> overrides), the
 * prompt's disabled-tools block, and the skill advertisement filter.
 *
 * Nothing here holds state; callers pass in the active preset, the registered
 * tools, and the loaded skills.
 */

import type { Skill, ToolInfo } from "@earendil-works/pi-coding-agent";
import {
	isGlob,
	matchesAny,
	type Overrides,
	type Preset,
	type SkillRestriction,
	type ToolRestriction,
} from "./config.ts";

const PROMPT_DESCRIPTION_LIMIT = 120;

export type RestrictionMode = "enable" | "disable" | "none";

export function restrictionMode(tools: ToolRestriction | undefined): RestrictionMode {
	if (tools?.enable) return "enable";
	if (tools?.disable) return "disable";
	return "none";
}

export function describeTools(tools: ToolRestriction | undefined): string {
	if (tools?.enable !== undefined) return `only ${tools.enable.length} tools`;
	if (tools?.disable !== undefined) return `minus ${tools.disable.length} tools`;
	return "all tools";
}

export function describeSkills(skills: SkillRestriction | undefined): string {
	if (skills?.enable !== undefined) return `only ${skills.enable.length} skills`;
	if (skills?.disable !== undefined) return `minus ${skills.disable.length} skills`;
	return "all skills";
}

/** Picker summary: counts only, so single-line truncation cannot hide strictness. */
export function describePreset(preset: Preset): string {
	if (!preset.tools && !preset.skills) return "no restriction";
	return `${describeTools(preset.tools)} • ${describeSkills(preset.skills)}`;
}

export interface ToolLayerInput {
	registered: string[];
	base: string[];
	preset: Preset;
	overrides: Overrides;
}

/** Strict recompute: a pure function of baseline, the active preset, and overrides. */
export function computeActiveTools({ registered, base, preset, overrides }: ToolLayerInput): string[] {
	const tools = preset.tools;

	let restricted: string[];
	switch (restrictionMode(tools)) {
		case "enable":
			restricted = registered.filter((name) => matchesAny(tools?.enable, name));
			break;
		case "disable":
			restricted = base.filter((name) => !matchesAny(tools?.disable, name));
			break;
		default:
			restricted = base;
	}

	const registeredSet = new Set(registered);
	const active = new Set(restricted);
	for (const name of overrides.enabled) {
		if (registeredSet.has(name)) active.add(name);
	}
	for (const name of overrides.disabled) active.delete(name);

	return [...active];
}

/**
 * Which inactive tools the prompt block advertises. `shown` is absolute,
 * `hidden` subtractive, and neither means everything. Both are display filters:
 * they never add or remove an active tool.
 */
export function advertisesTool(tools: ToolRestriction | undefined, name: string): boolean {
	if (tools?.shown !== undefined) return matchesAny(tools.shown, name);
	if (tools?.hidden !== undefined) return !matchesAny(tools.hidden, name);
	return true;
}

export function buildDisabledToolsBlock(
	allTools: ToolInfo[],
	active: ReadonlySet<string>,
	tools: ToolRestriction | undefined,
): string | undefined {
	const disabled = allTools
		.map((tool) => tool.name)
		.filter((name) => !active.has(name) && advertisesTool(tools, name));
	if (disabled.length === 0) return undefined;

	const descriptions = new Map(allTools.map((tool) => [tool.name, tool.description]));
	const bullets = disabled.map((name) => {
		const description = descriptions.get(name);
		if (!description) return `- ${name}`;
		const short =
			description.length > PROMPT_DESCRIPTION_LIMIT
				? `${description.slice(0, PROMPT_DESCRIPTION_LIMIT - 3)}...`
				: description;
		return `- ${name}: ${short}`;
	});

	let block = `\n\n## Disabled Tools\nThe following tools exist but are currently disabled:\n${bullets.join("\n")}\n`;
	if (active.has("enable_tool")) {
		block +=
			"Call the enable_tool tool to request enabling any of them. " +
			"Explain what you need and why, and the user will approve or deny.";
	}
	return block;
}

// ---------------------------------------------------------------------------
// Skill advertisement
// ---------------------------------------------------------------------------

/** Does the preset's skill filter wish this name away? */
function matchesSkillFilter(skills: SkillRestriction | undefined, name: string): boolean {
	if (!skills) return false;
	if (skills.enable !== undefined) return !matchesAny(skills.enable, name);
	if (skills.disable !== undefined) return matchesAny(skills.disable, name);
	return false;
}

/**
 * A visible skill the active preset does not advertise. Command-only skills
 * (`disable-model-invocation: true`) are never gated by a preset: the
 * frontmatter floor outranks it, and core's own filter drops them anyway.
 */
export function isGatedSkill(skills: SkillRestriction | undefined, skill: Skill): boolean {
	return !skill.disableModelInvocation && matchesSkillFilter(skills, skill.name);
}

/** The array that replaces `systemPromptOptions.skills`. */
export function advertisedSkills(preset: Preset, skills: readonly Skill[]): Skill[] {
	if (!preset.skills) return [...skills];
	return skills.filter((skill) => !isGatedSkill(preset.skills, skill));
}

/**
 * Lazy validation against the known skill names; see the spec, decision 8. A
 * name is known when it is loaded here or exists in the dotfiles catalogue.
 */
export function skillWarnings(
	presetName: string,
	preset: Preset,
	skills: readonly Skill[],
	knownNames: ReadonlySet<string> = new Set(skills.map((skill) => skill.name)),
): string[] {
	const restriction = preset.skills;
	if (!restriction) return [];

	const unknown: string[] = [];
	const commandOnly: string[] = [];
	for (const pattern of [...(restriction.enable ?? []), ...(restriction.disable ?? [])]) {
		if (isGlob(pattern)) continue;
		if (!knownNames.has(pattern)) {
			unknown.push(pattern);
			continue;
		}
		const matches = skills.filter((skill) => skill.name === pattern);
		if (matches.length > 0 && matches.every((skill) => skill.disableModelInvocation)) commandOnly.push(pattern);
	}

	const warnings: string[] = [];
	if (unknown.length > 0) warnings.push(`Preset "${presetName}": unknown skills: ${unknown.join(", ")}`);
	if (commandOnly.length > 0) {
		warnings.push(`Preset "${presetName}": skills entries matching only command-only skills: ${commandOnly.join(", ")}`);
	}
	return warnings;
}
