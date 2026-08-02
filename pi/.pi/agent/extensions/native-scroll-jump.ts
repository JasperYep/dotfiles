/**
 * Native Result Jump
 *
 * Ctrl+Up/Ctrl+Down navigate tmux's real scrollback between completed AI
 * results. The searchable text is taken from the first useful rendered line of
 * each final assistant message, so jumps skip thinking, the Working indicator,
 * and intermediate tool calls instead of landing at the start of the agent loop.
 *
 * The companion tmux copy-mode bindings call ~/.pi/agent/bin/pi-turn-scroll so
 * navigation keeps working after the first jump. Mouse-wheel scrolling,
 * selection, and normal tmux copy-mode continue to operate on the original
 * transcript rather than a second reader view.
 */

import { mkdir, rename, unlink, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";
import type { AssistantMessage } from "@earendil-works/pi-ai";
import {
	getMarkdownTheme,
	type ExtensionAPI,
	type ExtensionContext,
} from "@earendil-works/pi-coding-agent";
import {
	Key,
	Markdown,
	truncateToWidth,
	visibleWidth,
} from "@earendil-works/pi-tui";

const STATE_HEADER = "PI_RESULT_JUMP_V1";
const TMUX_STATE_OPTION = "@pi_result_jump_state";
const LEGACY_TOKEN_OPTION = "@pi_turn_anchor_token";
const MAX_RESULTS = 1000;
const MAX_SCAN_LINES = 24;

interface SearchRecord {
	needle: string;
	/** Number of rendered rows from the matched row back to the result's first visible row. */
	offset: number;
}

function stripAnsi(value: string): string {
	// OSC sequences terminated by BEL/ST, plus CSI escape sequences.
	return value.replace(
		/(?:\u001B\][\s\S]*?(?:\u0007|\u001B\\|\u009C))|(?:[\u001B\u009B][[\]()#;?]*(?:\d{1,4}(?:[;:]\d{0,4})*)?[\dA-PR-TZcf-nq-uy=><~])/g,
		"",
	);
}

function isCompletedResult(message: unknown): message is AssistantMessage {
	if (
		typeof message !== "object" ||
		message === null ||
		(message as { role?: unknown }).role !== "assistant"
	) {
		return false;
	}

	const assistant = message as AssistantMessage;
	if (assistant.stopReason === "aborted" || assistant.stopReason === "error") {
		return false;
	}

	let hasText = false;
	for (const content of assistant.content) {
		if (content.type === "toolCall") return false;
		if (content.type === "text" && content.text.trim()) hasText = true;
	}
	return hasText;
}

function renderedLines(text: string, width: number): string[] {
	try {
		return new Markdown(text.trim(), 0, 0, getMarkdownTheme()).render(width);
	} catch {
		// Theme/rendering should already be initialized in TUI mode. This fallback
		// still gives a useful target if a future renderer change throws.
		return text
			.replace(/\r\n?/g, "\n")
			.split("\n")
			.map((line) =>
				line
					.replace(/^\s{0,3}#{1,6}\s+/, "")
					.replace(/^\s*>\s?/, "")
					.replace(/^\s*(?:[-+*]|\d+[.)])\s+/, "")
					.replace(/!\[([^\]]*)\]\([^)]*\)/g, "$1")
					.replace(/\[([^\]]+)\]\([^)]*\)/g, "$1")
					.replace(/(?:\*\*|__|~~|`)/g, ""),
			);
	}
}

function createSearchRecord(
	message: unknown,
	width: number,
): SearchRecord | undefined {
	if (!isCompletedResult(message)) return undefined;

	const maxNeedleWidth = Math.max(16, Math.min(64, width - 8));
	for (const content of message.content) {
		if (content.type !== "text" || !content.text.trim()) continue;

		const lines = renderedLines(content.text, width).map((line) =>
			stripAnsi(line)
				.replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/g, "")
				.trimEnd(),
		);
		const firstVisible = lines.findIndex((line) => line.trim().length > 0);
		if (firstVisible < 0) continue;

		let best: SearchRecord | undefined;
		let bestScore = Number.NEGATIVE_INFINITY;
		const end = Math.min(lines.length, firstVisible + MAX_SCAN_LINES);

		for (let index = firstVisible; index < end; index++) {
			const line = lines[index]?.trim();
			if (!line || !/[\p{L}\p{N}]/u.test(line)) continue;

			// truncateToWidth() deliberately appends an SGR reset when it clips a
			// Unicode line, so strip ANSI once more after truncation.
			const needle = stripAnsi(
				truncateToWidth(line, maxNeedleWidth, ""),
			).trim();
			if (!needle || !/[\p{L}\p{N}]/u.test(needle)) continue;

			const rowOffset = index - firstVisible;
			const lettersAndNumbers = Array.from(needle).filter((char) =>
				/[\p{L}\p{N}]/u.test(char),
			).length;

			// Prefer the actual first result row whenever it is substantial enough;
			// only use a later distinctive line for tiny headings such as "Done".
			if (
				index === firstVisible &&
				visibleWidth(needle) >= 8 &&
				lettersAndNumbers >= 4
			) {
				return { needle, offset: 0 };
			}

			const score =
				Math.min(visibleWidth(needle), maxNeedleWidth) +
				Math.min(lettersAndNumbers, 32) -
				rowOffset * 3;

			if (score > bestScore) {
				best = { needle, offset: rowOffset };
				bestScore = score;
			}
		}

		if (best) return best;
	}

	return undefined;
}

function mergeRecord(records: SearchRecord[], record: SearchRecord): SearchRecord[] {
	const existingIndex = records.findIndex((item) => item.needle === record.needle);
	if (existingIndex >= 0) {
		const existing = records[existingIndex]!;
		if (record.offset < existing.offset) {
			const next = [...records];
			next[existingIndex] = record;
			return next;
		}
		return records;
	}

	const next = [...records, record];
	return next.length > MAX_RESULTS ? next.slice(-MAX_RESULTS) : next;
}

function collectRecords(ctx: ExtensionContext, width: number): SearchRecord[] {
	let records: SearchRecord[] = [];
	for (const entry of ctx.sessionManager.getBranch()) {
		if (entry.type !== "message") continue;
		const record = createSearchRecord(entry.message, width);
		if (record) records = mergeRecord(records, record);
	}
	return records;
}

function serializeRecords(records: SearchRecord[]): string {
	// Longer needles are checked first when multiple records happen to match the
	// same terminal row. Tabs/newlines are removed because this is a TSV file.
	const sorted = [...records].sort((a, b) => b.needle.length - a.needle.length);
	const rows = sorted.map((record) => {
		const needle = record.needle.replace(/[\t\r\n]+/g, " ").trim();
		return `${Math.max(0, Math.floor(record.offset))}\t${needle}`;
	});
	return `${STATE_HEADER}\n${rows.join("\n")}${rows.length > 0 ? "\n" : ""}`;
}

export default function (pi: ExtensionAPI) {
	const pane = process.env.TMUX_PANE;
	const inTmux = Boolean(process.env.TMUX && pane);
	const agentDir =
		process.env.PI_CODING_AGENT_DIR ?? join(homedir(), ".pi", "agent");
	const jumpHelper = join(agentDir, "bin", "pi-turn-scroll");
	const stateDir = join(agentDir, "cache", "result-jump");
	const paneName = (pane ?? "no-pane").replace(/[^a-zA-Z0-9_.-]/g, "_");
	const stateFile = join(stateDir, `${paneName}.tsv`);

	let active = false;
	let renderWidth = 80;
	let records: SearchRecord[] = [];

	async function getPaneWidth(): Promise<number> {
		if (!inTmux || !pane) return process.stdout.columns || 80;
		const result = await pi.exec(
			"tmux",
			["display-message", "-p", "-t", pane, "#{pane_width}"],
			{ timeout: 2000 },
		);
		const parsed = Number.parseInt(result.stdout.trim(), 10);
		return result.code === 0 && Number.isFinite(parsed) && parsed > 0
			? parsed
			: process.stdout.columns || 80;
	}

	async function writeState(ctx: ExtensionContext): Promise<void> {
		if (!active || !inTmux || !pane) return;
		try {
			await mkdir(stateDir, { recursive: true, mode: 0o700 });
			const tempFile = `${stateFile}.${process.pid}.tmp`;
			await writeFile(tempFile, serializeRecords(records), {
				encoding: "utf8",
				mode: 0o600,
			});
			await rename(tempFile, stateFile);
		} catch (error) {
			ctx.ui.notify(
				`Could not write result-jump state: ${error instanceof Error ? error.message : String(error)}`,
				"warning",
			);
		}
	}

	async function publishState(ctx: ExtensionContext): Promise<void> {
		if (!active || !inTmux || !pane) return;
		await writeState(ctx);
		const result = await pi.exec(
			"tmux",
			[
				"set-option",
				"-p",
				"-q",
				"-t",
				pane,
				TMUX_STATE_OPTION,
				stateFile,
			],
			{ timeout: 2000 },
		);
		await pi.exec(
			"tmux",
			[
				"set-option",
				"-p",
				"-q",
				"-u",
				"-t",
				pane,
				LEGACY_TOKEN_OPTION,
			],
			{ timeout: 2000 },
		);
		if (result.code !== 0) {
			ctx.ui.notify(
				`Could not configure tmux result jumping: ${result.stderr.trim() || `exit ${result.code}`}`,
				"warning",
			);
		}
	}

	async function rebuildState(ctx: ExtensionContext): Promise<void> {
		if (!active) return;
		renderWidth = await getPaneWidth();
		records = collectRecords(ctx, renderWidth);
		await publishState(ctx);
	}

	async function refreshWidthIfNeeded(ctx: ExtensionContext): Promise<void> {
		const nextWidth = await getPaneWidth();
		if (nextWidth !== renderWidth) {
			renderWidth = nextWidth;
			records = collectRecords(ctx, renderWidth);
		}
		await publishState(ctx);
	}

	async function clearState(): Promise<void> {
		active = false;
		if (inTmux && pane) {
			await pi.exec(
				"tmux",
				[
					"set-option",
					"-p",
					"-q",
					"-u",
					"-t",
					pane,
					TMUX_STATE_OPTION,
				],
				{ timeout: 2000 },
			);
			await pi.exec(
				"tmux",
				[
					"set-option",
					"-p",
					"-q",
					"-u",
					"-t",
					pane,
					LEGACY_TOKEN_OPTION,
				],
				{ timeout: 2000 },
			);
		}
		await unlink(stateFile).catch(() => undefined);
	}

	async function jump(
		direction: "up" | "down",
		ctx: ExtensionContext,
	): Promise<void> {
		if (!inTmux || !pane) {
			ctx.ui.notify(
				"Native result jumping currently requires tmux",
				"warning",
			);
			return;
		}

		await refreshWidthIfNeeded(ctx);
		const result = await pi.exec(jumpHelper, [direction, pane], {
			timeout: 3000,
		});
		if (result.code === 3) {
			ctx.ui.notify(
				"No completed AI result is searchable in this scrollback yet",
				"info",
			);
			return;
		}
		if (result.code !== 0) {
			ctx.ui.notify(
				`Native result jump failed: ${result.stderr.trim() || `exit ${result.code}`}`,
				"warning",
			);
		}
	}

	pi.registerShortcut(Key.ctrl("up"), {
		description: "Jump to the previous completed AI result",
		handler: async (ctx) => {
			await jump("up", ctx);
		},
	});

	pi.registerShortcut(Key.ctrl("down"), {
		description: "Jump to the next completed AI result",
		handler: async (ctx) => {
			await jump("down", ctx);
		},
	});

	pi.registerCommand("jump", {
		description: "Jump to the latest completed AI result in tmux scrollback",
		handler: async (_args, ctx) => {
			await jump("up", ctx);
		},
	});

	pi.on("session_start", async (_event, ctx) => {
		active = ctx.mode === "tui" && inTmux;
		if (!active) return;
		await rebuildState(ctx);
	});

	pi.on("message_end", async (event, ctx) => {
		if (!active || !isCompletedResult(event.message)) return;
		const nextWidth = await getPaneWidth();
		if (nextWidth !== renderWidth) {
			renderWidth = nextWidth;
			records = collectRecords(ctx, renderWidth);
		}
		const record = createSearchRecord(event.message, renderWidth);
		if (!record) return;
		records = mergeRecord(records, record);
		await publishState(ctx);
	});

	pi.on("session_tree", async (_event, ctx) => {
		if (!active) return;
		await rebuildState(ctx);
	});

	pi.on("session_shutdown", async () => {
		await clearState();
	});
}
