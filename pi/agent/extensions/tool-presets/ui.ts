/**
 * Interactive surfaces: the `/preset` picker, the fixed-row `/tools` overlay,
 * the `d` detail popup both surfaces share, and the `/skill:` autocomplete
 * marker.
 *
 * All of them are TUI-only by construction. The autocomplete hook is a no-op stub
 * outside interactive mode, so it is registered unconditionally.
 */

import { DynamicBorder, type AutocompleteProviderFactory, type ExtensionContext, type ToolInfo } from "@earendil-works/pi-coding-agent";
import {
	Container,
	Key,
	SelectList,
	type SelectItem,
	Text,
	matchesKey,
	sliceByColumn,
	truncateToWidth,
	visibleWidth,
	wrapTextWithAnsi,
} from "@earendil-works/pi-tui";
import type { AutocompleteItem, AutocompleteProvider } from "@earendil-works/pi-tui";

const PRESET_PICKER_ROWS = 12;
const TOOLS_OVERLAY_ROWS = 15;
const SKILL_PREFIX = "skill:";

/** Top and bottom border, title line, subtitle line, footer line. */
const DETAIL_BOX_CHROME = 5;
const DETAIL_MIN_BODY_ROWS = 3;

/**
 * Wraps the built-in autocomplete provider and appends ` (hidden)` to the
 * description of every `skill:<name>` entry the active preset gates. It removes,
 * reorders, and re-inserts nothing.
 */
export function hiddenSkillMarker(gatedNames: () => ReadonlySet<string>): AutocompleteProviderFactory {
	return (current: AutocompleteProvider): AutocompleteProvider => ({
		triggerCharacters: current.triggerCharacters,
		getSuggestions: async (lines, cursorLine, cursorCol, options) => {
			const result = await current.getSuggestions(lines, cursorLine, cursorCol, options);
			if (!result) return result;

			const gated = gatedNames();
			if (gated.size === 0) return result;

			return {
				...result,
				items: result.items.map((item) => {
					const name = skillNameOf(item);
					if (!name || !gated.has(name)) return item;
					const description = item.description ? `${item.description} (hidden)` : "(hidden)";
					return { ...item, description };
				}),
			};
		},
		applyCompletion: (lines, cursorLine, cursorCol, item, prefix) =>
			current.applyCompletion(lines, cursorLine, cursorCol, item, prefix),
		shouldTriggerFileCompletion: current.shouldTriggerFileCompletion
			? (lines, cursorLine, cursorCol) => current.shouldTriggerFileCompletion!(lines, cursorLine, cursorCol)
			: undefined,
	});
}

function skillNameOf(item: AutocompleteItem): string | undefined {
	const value = item.value.startsWith(SKILL_PREFIX)
		? item.value
		: item.label.startsWith(SKILL_PREFIX)
			? item.label
			: undefined;
	return value?.slice(SKILL_PREFIX.length);
}

/** Modal preset picker. Returns the chosen preset name, or null on cancel. */
export async function showPresetSelector(
	ctx: ExtensionContext,
	items: SelectItem[],
	initialValue?: string,
	onDetail?: (item: SelectItem) => void,
): Promise<string | null> {
	return ctx.ui.custom<string | null>((tui, theme, _keybindings, done) => {
		const container = new Container();
		container.addChild(new DynamicBorder((text) => theme.fg("accent", text)));
		container.addChild(new Text(theme.fg("accent", theme.bold("Select Tool Preset"))));

		const selectList = new SelectList(items, Math.min(items.length, PRESET_PICKER_ROWS), {
			selectedPrefix: (text) => theme.fg("accent", text),
			selectedText: (text) => theme.fg("accent", text),
			description: (text) => theme.fg("muted", text),
			scrollInfo: (text) => theme.fg("dim", text),
			noMatch: (text) => theme.fg("warning", text),
		});
		if (initialValue !== undefined) {
			const initialIndex = items.findIndex((item) => item.value === initialValue);
			if (initialIndex > 0) selectList.setSelectedIndex(initialIndex);
		}
		selectList.onSelect = (item) => done(item.value);
		selectList.onCancel = () => done(null);
		container.addChild(selectList);

		container.addChild(new Text(theme.fg("dim", "↑↓ navigate • enter select • d details • esc cancel")));
		container.addChild(new DynamicBorder((text) => theme.fg("accent", text)));

		return {
			render(width: number) {
				return container.render(width);
			},
			invalidate() {
				container.invalidate();
			},
			handleInput(data: string) {
				// Intercepted before the list sees it: a printable key would filter the list.
				if (data === "d" && onDetail) {
					const item = selectList.getSelectedItem();
					if (item) onDetail(item);
					return;
				}
				selectList.handleInput(data);
				tui.requestRender();
			},
		};
	});
}

export interface DetailSection {
	heading?: string;
	/** Already themed, not yet wrapped: the popup wraps them at the render width. */
	lines: string[];
}

export interface DetailOverlayOptions {
	title: string;
	subtitle?: string;
	sections: DetailSection[];
}

/**
 * Read-only detail popup, centered over the surface that opened it. The body is
 * static and scrolls inside a hand-rolled viewport: `ScrollView` needs a layout
 * pass that the overlay renderer does not run, so it can neither clip nor scroll
 * here, and the overlay only slices a plain `render(width)` to `maxHeight`.
 */
export async function showDetailOverlay(ctx: ExtensionContext, options: DetailOverlayOptions): Promise<void> {
	const { title, subtitle, sections } = options;

	await ctx.ui.custom<void>(
		(tui, theme, keybindings, done) => {
			const body: string[] = [];
			for (const section of sections) {
				if (section.heading) {
					if (body.length > 0) body.push("");
					body.push(theme.fg("accent", theme.bold(section.heading)));
				}
				for (const line of section.lines) body.push(line);
			}

			let scrollTop = 0;
			let wrappedWidth = -1;
			let wrapped: string[] = [];

			/** The overlay is capped at 80% of the terminal, so the body gets the rest. */
			const bodyRows = (): number =>
				Math.max(DETAIL_MIN_BODY_ROWS, Math.floor(tui.terminal.rows * 0.8) - DETAIL_BOX_CHROME);

			const wrapBody = (width: number): string[] => {
				if (width !== wrappedWidth) {
					wrappedWidth = width;
					wrapped = body.flatMap((line) => wrapTextWithAnsi(line, width));
				}
				return wrapped;
			};

			const maxScrollTop = (): number => Math.max(0, wrapped.length - bodyRows());

			const scrollBy = (delta: number): void => {
				const next = Math.max(0, Math.min(scrollTop + delta, maxScrollTop()));
				if (next === scrollTop) return;
				scrollTop = next;
				tui.requestRender();
			};

			return {
				render(width: number) {
					const innerWidth = Math.max(1, width - 2);
					const contentWidth = Math.max(1, innerWidth - 1);
					const border = (text: string) => theme.fg("border", text);
					const pad = (text: string) => truncateToWidth(text, innerWidth, "…", true);

					const label = ` ${theme.fg("accent", theme.bold(title))} `;
					const labelWidth = visibleWidth(label);
					const ruleWidth = Math.max(0, innerWidth - labelWidth - 1);

					const lines = wrapBody(contentWidth);
					const rows = Math.max(1, Math.min(lines.length, bodyRows()));
					const top = Math.min(scrollTop, maxScrollTop());
					const visible = lines.slice(top, top + rows);

					const out = [border(`╭─${label}${"─".repeat(ruleWidth)}`) + border("╮")];
					const subtitleLine = subtitle ? ` ${theme.fg("muted", ellipsizeLeft(subtitle, contentWidth - 1))}` : "";
					out.push(border("│") + pad(subtitleLine) + border("│"));

					for (let i = 0; i < rows; i++) {
						const line = visible[i];
						out.push(border("│") + pad(line === undefined || line === "" ? "" : ` ${line}`) + border("│"));
					}

					const range = lines.length > rows ? `${top + 1}-${top + rows}/${lines.length}   ` : "";
					const hint = `${range}↑↓ scroll • PgUp/PgDn page • esc close`;
					out.push(border("│") + pad(` ${theme.fg("dim", hint)}`) + border("│"));
					out.push(border(`╰${"─".repeat(innerWidth)}╯`));
					return out;
				},
				invalidate() {
					// The wrap cache is keyed by width, so a resize re-wraps on the next
					// render without dropping the lines a keystroke needs to scroll.
				},
				handleInput(data: string) {
					if (keybindings.matches(data, "tui.select.up") || data === "k") scrollBy(-1);
					else if (keybindings.matches(data, "tui.select.down") || data === "j") scrollBy(1);
					else if (keybindings.matches(data, "tui.select.pageUp")) scrollBy(-bodyRows());
					else if (keybindings.matches(data, "tui.select.pageDown")) scrollBy(bodyRows());
					else if (
						keybindings.matches(data, "tui.select.cancel") ||
						keybindings.matches(data, "tui.select.confirm") ||
						data === "q"
					) {
						done();
					}
				},
			};
		},
		{ overlay: true, overlayOptions: { anchor: "center", width: "80%", maxHeight: "80%", margin: 2 } },
	);
}

/** Drop from the left so the tail survives, which is where the distinctive part sits. */
function ellipsizeLeft(text: string, width: number): string {
	const full = visibleWidth(text);
	if (full <= width) return text;
	if (width <= 1) return sliceByColumn(text, full - width, width, true);
	return `…${sliceByColumn(text, full - (width - 1), width - 1, true)}`;
}

export interface ToolsOverlayOptions {
	tools: ToolInfo[];
	getActive: () => string[];
	overrideSource: (name: string) => "override" | "preset";
	onToggle: (name: string, enabled: boolean) => void;
	onDetail?: (tool: ToolInfo) => void;
}

/**
 * Fixed-row tool editor. Every row is one terminal line and the height never
 * depends on the selected tool, so the list cannot shift as the cursor moves.
 */
export async function showToolsOverlay(ctx: ExtensionContext, options: ToolsOverlayOptions): Promise<void> {
	const { tools, getActive, overrideSource, onToggle, onDetail } = options;

	await ctx.ui.custom<void>((tui, theme, keybindings, done) => {
		let index = 0;

		const visibleRange = (): { startIndex: number; endIndex: number } => {
			const maxVisible = Math.min(tools.length, TOOLS_OVERLAY_ROWS);
			const startIndex = Math.max(0, Math.min(index - Math.floor(maxVisible / 2), tools.length - maxVisible));
			return { startIndex, endIndex: Math.min(startIndex + maxVisible, tools.length) };
		};

		const renderRow = (tool: ToolInfo, width: number, selected: boolean, active: ReadonlySet<string>): string => {
			const enabled = active.has(tool.name);
			const prefix = selected ? "→ " : "  ";
			const box = enabled ? "[x]" : "[ ]";
			const available = Math.max(1, width - visibleWidth(prefix) - visibleWidth(box) - 1);

			let tag = overrideSource(tool.name) === "override" ? " (override)" : "";
			if (available < visibleWidth(tag) + 4) tag = "";
			const name = truncateToWidth(tool.name, Math.max(1, available - visibleWidth(tag)), "…");

			// The cursor never outranks the state: a disabled row under the cursor
			// stays dim so it cannot be misread as enabled.
			const nameColor = enabled ? (selected ? "accent" : "text") : "dim";
			return truncateToWidth(
				theme.fg("accent", prefix) +
					theme.fg(enabled ? "success" : "dim", box) +
					" " +
					theme.fg(nameColor, name) +
					(tag ? theme.fg("dim", tag) : ""),
				width,
			);
		};

		return {
			render(width: number) {
				const active = new Set(getActive());
				const lines = [
					theme.fg("accent", truncateToWidth(theme.bold("Tool Configuration"), width, "…")),
					theme.fg("dim", truncateToWidth("State comes from the active preset unless marked (override)", width, "…")),
				];

				const { startIndex, endIndex } = visibleRange();
				for (let i = startIndex; i < endIndex; i++) {
					const tool = tools[i];
					if (!tool) continue;
					lines.push(renderRow(tool, width, i === index, active));
				}

				lines.push(theme.fg("dim", truncateToWidth(`  (${index + 1}/${tools.length})`, width - 2, "")));
				const description = tools[index]?.description;
				lines.push(description ? theme.fg("muted", truncateToWidth(`  ${description}`, width, "…")) : "");
				lines.push(
					theme.fg("dim", truncateToWidth("↑↓ navigate • space/←→ toggle • d description • esc close", width, "…")),
				);
				lines.push(theme.fg("dim", truncateToWidth("[x] on   [ ] off (dimmed name)", width, "…")));
				return lines;
			},
			invalidate() {},
			handleInput(data: string) {
				const tool = tools[index];
				if (keybindings.matches(data, "tui.select.up")) {
					index = index === 0 ? tools.length - 1 : index - 1;
				} else if (keybindings.matches(data, "tui.select.down")) {
					index = index === tools.length - 1 ? 0 : index + 1;
				} else if (data === " " || keybindings.matches(data, "tui.select.confirm")) {
					if (!tool) return;
					onToggle(tool.name, !getActive().includes(tool.name));
				} else if (matchesKey(data, Key.right) || matchesKey(data, Key.left)) {
					// Absolute, not a flip: pressing the same arrow twice cannot invert itself.
					if (!tool) return;
					onToggle(tool.name, matchesKey(data, Key.right));
				} else if (data === "d") {
					if (!tool || !onDetail) return;
					onDetail(tool);
					return;
				} else if (keybindings.matches(data, "tui.select.cancel")) {
					done();
					return;
				} else {
					return;
				}
				tui.requestRender();
			},
		};
	});
}
