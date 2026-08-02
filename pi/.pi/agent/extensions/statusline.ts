/**
 * Configurable statusline footer.
 *
 * Config: ~/.pi/agent/statusline.json
 * Commands:
 *   /statusline              toggle on/off
 *   /statusline reload       reload config from disk
 *   /statusline show         show current config
 *   /statusline left a b c   set left items
 *   /statusline right a b c  set right items
 *   /statusline items        list valid item ids
 */

import type { AssistantMessage } from "@earendil-works/pi-ai";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";
import { Buffer } from "node:buffer";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, relative, resolve, sep } from "node:path";

/** All configurable statusline fields. */
export const STATUSLINE_ITEMS = [
	"model",
	"provider",
	"thinking",
	"activity",
	"speed",
	"turn",
	"context",
	"contextPercent",
	"contextTokens",
	"contextWindow",
	"input",
	"output",
	"cacheRead",
	"cacheWrite",
	"cacheHit",
	"cost",
	"cwd",
	"branch",
	"sessionName",
	"sessionId",
	"extStatus",
	"idle",
	"pending",
	"clock",
] as const;

export type StatuslineItem = (typeof STATUSLINE_ITEMS)[number];

export type CwdStyle = "short" | "full" | "basename";
export type ModelStyle = "id" | "short";
export type TokenScope = "session" | "branch" | "last";

export interface StatuslineConfig {
	enabled: boolean;
	/** Joiner between fields within left/right side. */
	separator: string;
	/** Min spaces between left and right. */
	minPad: number;
	/** Context % warning threshold. */
	contextWarnAt: number;
	/** Context % error threshold. */
	contextErrorAt: number;
	cwdStyle: CwdStyle;
	modelStyle: ModelStyle;
	/** How to aggregate token/cost stats. */
	tokenScope: TokenScope;
	/** When model supports reasoning and level is off, still show "think off". */
	showThinkingWhenOff: boolean;
	left: StatuslineItem[];
	right: StatuslineItem[];
}

const CONFIG_PATH = resolve(homedir(), ".pi/agent/statusline.json");

const DEFAULT_CONFIG: StatuslineConfig = {
	enabled: true,
	separator: " · ",
	minPad: 2,
	contextWarnAt: 70,
	contextErrorAt: 90,
	cwdStyle: "short",
	modelStyle: "id",
	tokenScope: "session",
	showThinkingWhenOff: true,
	// Minimal default: model, thinking level, and context usage.
	left: ["model", "thinking", "context"],
	right: ["branch", "cwd"],
};

type Activity = "idle" | "working" | "done";
type SpeedPhase = "idle" | "waiting" | "streaming" | "done";

interface OutputSpeed {
	phase: SpeedPhase;
	turnStartedAt?: number;
	streamStartedAt?: number;
	estimatedTokens: number;
	tokensPerSecond?: number;
	exact: boolean;
	sawStreamUpdate: boolean;
}

interface TokenStats {
	input: number;
	output: number;
	cacheRead: number;
	cacheWrite: number;
	cost: number;
	cacheHit?: number;
}

function isStatuslineItem(v: unknown): v is StatuslineItem {
	return typeof v === "string" && (STATUSLINE_ITEMS as readonly string[]).includes(v);
}

function sanitizeItems(items: unknown, fallback: StatuslineItem[]): StatuslineItem[] {
	if (!Array.isArray(items)) return [...fallback];
	const out: StatuslineItem[] = [];
	for (const item of items) {
		if (isStatuslineItem(item) && !out.includes(item)) out.push(item);
	}
	return out;
}

function loadConfig(): StatuslineConfig {
	const base: StatuslineConfig = {
		...DEFAULT_CONFIG,
		left: [...DEFAULT_CONFIG.left],
		right: [...DEFAULT_CONFIG.right],
	};
	if (!existsSync(CONFIG_PATH)) return base;
	try {
		const raw = JSON.parse(readFileSync(CONFIG_PATH, "utf-8")) as Partial<StatuslineConfig>;
		return {
			enabled: raw.enabled ?? base.enabled,
			separator: typeof raw.separator === "string" ? raw.separator : base.separator,
			minPad: typeof raw.minPad === "number" ? Math.max(1, raw.minPad) : base.minPad,
			contextWarnAt:
				typeof raw.contextWarnAt === "number" ? raw.contextWarnAt : base.contextWarnAt,
			contextErrorAt:
				typeof raw.contextErrorAt === "number" ? raw.contextErrorAt : base.contextErrorAt,
			cwdStyle:
				raw.cwdStyle === "full" || raw.cwdStyle === "basename" || raw.cwdStyle === "short"
					? raw.cwdStyle
					: base.cwdStyle,
			modelStyle: raw.modelStyle === "short" || raw.modelStyle === "id" ? raw.modelStyle : base.modelStyle,
			tokenScope:
				raw.tokenScope === "branch" || raw.tokenScope === "last" || raw.tokenScope === "session"
					? raw.tokenScope
					: base.tokenScope,
			showThinkingWhenOff: raw.showThinkingWhenOff ?? base.showThinkingWhenOff,
			left: sanitizeItems(raw.left, base.left),
			right: sanitizeItems(raw.right, base.right),
		};
	} catch {
		return base;
	}
}

function saveConfig(cfg: StatuslineConfig): void {
	mkdirSync(dirname(CONFIG_PATH), { recursive: true });
	writeFileSync(CONFIG_PATH, `${JSON.stringify(cfg, null, 2)}\n`, "utf-8");
}

function fmtTokens(n: number): string {
	if (n < 1000) return String(n);
	if (n < 10_000) return `${(n / 1000).toFixed(1)}k`;
	if (n < 1_000_000) return `${Math.round(n / 1000)}k`;
	if (n < 10_000_000) return `${(n / 1_000_000).toFixed(1)}M`;
	return `${Math.round(n / 1_000_000)}M`;
}

function fmtOutputSpeed(tokensPerSecond: number): string {
	if (tokensPerSecond < 1) return tokensPerSecond.toFixed(2);
	if (tokensPerSecond < 100) return tokensPerSecond.toFixed(1);
	if (tokensPerSecond < 1000) return String(Math.round(tokensPerSecond));
	return `${(tokensPerSecond / 1000).toFixed(1)}k`;
}

/**
 * Streaming events contain text rather than tokenizer ids. UTF-8 bytes / 4 is a
 * useful live approximation for both ASCII-heavy code and CJK text. The final
 * value is replaced with provider-reported output tokens when available.
 */
function estimateStreamTokens(text: string): number {
	return Buffer.byteLength(text, "utf8") / 4;
}

function calculateOutputSpeed(
	tokens: number,
	startedAt: number | undefined,
	finishedAt: number,
): number | undefined {
	if (tokens <= 0 || startedAt === undefined) return undefined;
	const elapsedSeconds = (finishedAt - startedAt) / 1000;
	if (elapsedSeconds <= 0) return undefined;
	return tokens / elapsedSeconds;
}

function shortModelId(id: string): string {
	// strip common dated suffixes: -20250514, -20241022
	return id.replace(/-\d{8}($|[.-])/g, "$1").replace(/-$/, "");
}

function formatCwd(cwd: string, style: CwdStyle): string {
	if (style === "full") return cwd;
	if (style === "basename") {
		const parts = cwd.split(sep).filter(Boolean);
		return parts.length ? parts[parts.length - 1]! : cwd;
	}
	const home = homedir();
	const resolved = resolve(cwd);
	const resolvedHome = resolve(home);
	const rel = relative(resolvedHome, resolved);
	const inside =
		rel === "" || (rel !== ".." && !rel.startsWith(`..${sep}`) && !rel.startsWith(sep));
	if (!inside) return cwd;
	return rel === "" ? "~" : `~${sep}${rel}`;
}

function collectTokenStats(
	ctx: ExtensionContext,
	scope: TokenScope,
): TokenStats {
	const stats: TokenStats = {
		input: 0,
		output: 0,
		cacheRead: 0,
		cacheWrite: 0,
		cost: 0,
	};

	const entries =
		scope === "branch"
			? ctx.sessionManager.getBranch()
			: ctx.sessionManager.getEntries();

	const assistantUsages: Array<NonNullable<AssistantMessage["usage"]>> = [];
	for (const entry of entries) {
		if (entry.type === "message" && entry.message.role === "assistant") {
			const u = (entry.message as AssistantMessage).usage;
			if (u) assistantUsages.push(u);
		}
	}

	const selected =
		scope === "last"
			? assistantUsages.length
				? [assistantUsages[assistantUsages.length - 1]!]
				: []
			: assistantUsages;

	for (const u of selected) {
		stats.input += u.input ?? 0;
		stats.output += u.output ?? 0;
		stats.cacheRead += u.cacheRead ?? 0;
		stats.cacheWrite += u.cacheWrite ?? 0;
		stats.cost += u.cost?.total ?? 0;
	}

	if (assistantUsages.length) {
		const last = assistantUsages[assistantUsages.length - 1]!;
		const prompt = (last.input ?? 0) + (last.cacheRead ?? 0) + (last.cacheWrite ?? 0);
		if (prompt > 0) stats.cacheHit = ((last.cacheRead ?? 0) / prompt) * 100;
	}

	return stats;
}

function clockNow(): string {
	const d = new Date();
	const hh = String(d.getHours()).padStart(2, "0");
	const mm = String(d.getMinutes()).padStart(2, "0");
	return `${hh}:${mm}`;
}

export default function (pi: ExtensionAPI) {
	let cfg = loadConfig();
	let activity: Activity = "idle";
	let thinkingLevel = "high";
	let turnCount = 0;
	let outputSpeed: OutputSpeed = {
		phase: "idle",
		estimatedTokens: 0,
		exact: false,
		sawStreamUpdate: false,
	};
	let lastSpeedRefreshAt = 0;
	let requestRender: (() => void) | undefined;
	let latestCtx: ExtensionContext | undefined;
	let clockTimer: ReturnType<typeof setInterval> | undefined;

	function needsClock(): boolean {
		return cfg.left.includes("clock") || cfg.right.includes("clock");
	}

	function syncClockTimer() {
		if (needsClock() && !clockTimer) {
			clockTimer = setInterval(() => refresh(), 30_000);
		} else if (!needsClock() && clockTimer) {
			clearInterval(clockTimer);
			clockTimer = undefined;
		}
	}

	function refresh() {
		requestRender?.();
	}

	function resetOutputSpeed(phase: SpeedPhase, turnStartedAt?: number) {
		outputSpeed = {
			phase,
			turnStartedAt,
			estimatedTokens: 0,
			exact: false,
			sawStreamUpdate: false,
		};
		lastSpeedRefreshAt = 0;
	}

	function applyConfig(next: StatuslineConfig, ctx?: ExtensionContext) {
		cfg = next;
		syncClockTimer();
		if (ctx) {
			if (cfg.enabled) installFooter(ctx);
			else restoreDefault(ctx);
		}
		refresh();
	}

	function renderItem(
		item: StatuslineItem,
		c: ExtensionContext,
		theme: {
			fg: (name: string, text: string) => string;
		},
		footerData: {
			getGitBranch: () => string | null;
			getExtensionStatuses: () => ReadonlyMap<string, string>;
			getAvailableProviderCount: () => number;
		},
		tokens: TokenStats,
	): string | string[] | undefined {
		const usage = c.getContextUsage?.();
		const contextWindow = usage?.contextWindow ?? c.model?.contextWindow ?? 0;
		const contextPercentValue = usage?.percent ?? 0;
		const contextPercent =
			usage?.percent != null ? usage.percent.toFixed(1) : "?";

		switch (item) {
			case "model": {
				const raw = c.model?.id || "no-model";
				const id = cfg.modelStyle === "short" ? shortModelId(raw) : raw;
				return theme.fg("accent", id);
			}
			case "provider": {
				const p = c.model?.provider;
				if (!p) return undefined;
				return theme.fg("dim", `(${p})`);
			}
			case "thinking": {
				if (!c.model?.reasoning) return undefined;
				const fastIcon = footerData.getExtensionStatuses().get("fast-mode") === "⚡" ? " ⚡" : "";
				if (thinkingLevel === "off") {
					return cfg.showThinkingWhenOff ? theme.fg("dim", `think off${fastIcon}`) : undefined;
				}
				return theme.fg("dim", `${thinkingLevel}${fastIcon}`);
			}
			case "activity": {
				if (activity === "working") {
					return theme.fg("accent", "●") + theme.fg("dim", ` T${turnCount}`);
				}
				if (activity === "done") {
					return theme.fg("success", "✓") + theme.fg("dim", ` T${turnCount}`);
				}
				return theme.fg("dim", "○ idle");
			}
			case "speed": {
				if (outputSpeed.phase === "idle") return undefined;
				if (outputSpeed.tokensPerSecond === undefined) {
					const color = outputSpeed.phase === "streaming" ? "accent" : "dim";
					return theme.fg(color, "… tok/s");
				}
				const prefix = outputSpeed.exact ? "" : "~";
				const label = `${prefix}${fmtOutputSpeed(outputSpeed.tokensPerSecond)} tok/s`;
				if (outputSpeed.phase === "streaming") return theme.fg("accent", label);
				return theme.fg(outputSpeed.exact ? "success" : "dim", label);
			}
			case "turn":
				return theme.fg("dim", `T${turnCount}`);
			case "context": {
				const label =
					contextPercent === "?"
						? `?/${fmtTokens(contextWindow)}`
						: `${contextPercent}%/${fmtTokens(contextWindow)}`;
				if (contextPercentValue > cfg.contextErrorAt) return theme.fg("error", label);
				if (contextPercentValue > cfg.contextWarnAt) return theme.fg("warning", label);
				return theme.fg("dim", label);
			}
			case "contextPercent": {
				const label = contextPercent === "?" ? "?" : `${contextPercent}%`;
				if (contextPercentValue > cfg.contextErrorAt) return theme.fg("error", label);
				if (contextPercentValue > cfg.contextWarnAt) return theme.fg("warning", label);
				return theme.fg("dim", label);
			}
			case "contextTokens": {
				const t = usage?.tokens;
				return theme.fg("dim", t == null ? "?" : fmtTokens(t));
			}
			case "contextWindow":
				return theme.fg("dim", fmtTokens(contextWindow));
			case "input":
				return tokens.input ? theme.fg("dim", `↑${fmtTokens(tokens.input)}`) : undefined;
			case "output":
				return tokens.output ? theme.fg("dim", `↓${fmtTokens(tokens.output)}`) : undefined;
			case "cacheRead":
				return tokens.cacheRead ? theme.fg("dim", `R${fmtTokens(tokens.cacheRead)}`) : undefined;
			case "cacheWrite":
				return tokens.cacheWrite ? theme.fg("dim", `W${fmtTokens(tokens.cacheWrite)}`) : undefined;
			case "cacheHit":
				return tokens.cacheHit !== undefined
					? theme.fg("dim", `CH${tokens.cacheHit.toFixed(1)}%`)
					: undefined;
			case "cost":
				return tokens.cost > 0 ? theme.fg("dim", `$${tokens.cost.toFixed(3)}`) : undefined;
			case "cwd":
				return theme.fg("dim", formatCwd(c.cwd, cfg.cwdStyle));
			case "branch": {
				const b = footerData.getGitBranch();
				return b ? theme.fg("dim", b) : undefined;
			}
			case "sessionName": {
				const name = c.sessionManager.getSessionName?.();
				return name ? theme.fg("dim", name) : undefined;
			}
			case "sessionId": {
				const id = c.sessionManager.getSessionId?.();
				if (!id) return undefined;
				return theme.fg("dim", id.slice(0, 8));
			}
			case "extStatus": {
				const statuses = footerData.getExtensionStatuses?.();
				if (!statuses?.size) return undefined;
				const texts: string[] = [];
				for (const [key, text] of statuses) {
					// fast-mode is rendered inline after thinking effort.
					if (key === "fast-mode") continue;
					if (text) texts.push(text);
				}
				return texts.length ? texts : undefined;
			}
			case "idle":
				return theme.fg("dim", c.isIdle() ? "idle" : "busy");
			case "pending":
				return c.hasPendingMessages() ? theme.fg("warning", "queued") : undefined;
			case "clock":
				return theme.fg("dim", clockNow());
			default:
				return undefined;
		}
	}

	function joinSide(parts: string[]): string {
		return parts.filter(Boolean).join(cfg.separator);
	}

	function installFooter(ctx: ExtensionContext) {
		latestCtx = ctx;
		if (!ctx.hasUI || ctx.mode === "print" || ctx.mode === "json") return;
		syncClockTimer();

		ctx.ui.setFooter((tui, theme, footerData) => {
			requestRender = () => tui.requestRender();
			const unsub = footerData.onBranchChange(() => tui.requestRender());

			return {
				dispose() {
					unsub();
					requestRender = undefined;
				},
				invalidate() {},
				render(width: number): string[] {
					const c = latestCtx;
					if (!c) return [theme.fg("dim", "statusline")];

					const needsTokens = [...cfg.left, ...cfg.right].some((item) =>
						["input", "output", "cacheRead", "cacheWrite", "cacheHit", "cost"].includes(item),
					);
					const tokens = needsTokens
						? collectTokenStats(c, cfg.tokenScope)
						: {
								input: 0,
								output: 0,
								cacheRead: 0,
								cacheWrite: 0,
								cost: 0,
							};

					const build = (items: StatuslineItem[]): string => {
						const parts: string[] = [];
						for (const item of items) {
							const rendered = renderItem(item, c, theme, footerData, tokens);
							if (rendered == null) continue;
							if (Array.isArray(rendered)) parts.push(...rendered);
							else parts.push(rendered);
						}
						return joinSide(parts);
					};

					const left = build(cfg.left);
					const right = build(cfg.right);
					const minPad = cfg.minPad;
					const leftW = visibleWidth(left);
					const rightW = visibleWidth(right);

					if (!right) {
						return [truncateToWidth(left || theme.fg("dim", "statusline"), width, "...")];
					}
					if (!left) {
						const pad = " ".repeat(Math.max(0, width - rightW));
						return [pad + right];
					}
					if (leftW + minPad + rightW <= width) {
						const pad = " ".repeat(width - leftW - rightW);
						return [left + pad + right];
					}
					// Prefer left; truncate right
					const avail = Math.max(0, width - leftW - minPad);
					if (avail > 0) {
						const truncatedRight = truncateToWidth(right, avail, "");
						const pad = " ".repeat(
							Math.max(0, width - leftW - visibleWidth(truncatedRight)),
						);
						return [left + pad + truncatedRight];
					}
					return [truncateToWidth(left, width, "...")];
				},
			};
		});
	}

	function restoreDefault(ctx: ExtensionContext) {
		ctx.ui.setFooter(undefined);
		requestRender = undefined;
	}

	pi.on("session_start", async (_event, ctx) => {
		latestCtx = ctx;
		resetOutputSpeed("idle");
		cfg = loadConfig();
		syncClockTimer();
		if (cfg.enabled) installFooter(ctx);
	});

	pi.on("session_shutdown", async (_event, ctx) => {
		latestCtx = ctx;
		if (clockTimer) {
			clearInterval(clockTimer);
			clockTimer = undefined;
		}
		if (cfg.enabled) restoreDefault(ctx);
	});

	pi.on("turn_start", async (_event, ctx) => {
		latestCtx = ctx;
		turnCount++;
		activity = "working";
		resetOutputSpeed("waiting", performance.now());
		refresh();
	});

	pi.on("message_start", async (event, ctx) => {
		latestCtx = ctx;
		if (event.message.role !== "assistant") return;
		outputSpeed = {
			phase: "streaming",
			turnStartedAt: outputSpeed.turnStartedAt,
			streamStartedAt: performance.now(),
			estimatedTokens: 0,
			exact: false,
			sawStreamUpdate: false,
		};
		lastSpeedRefreshAt = 0;
		refresh();
	});

	pi.on("message_update", async (event, ctx) => {
		latestCtx = ctx;
		if (event.message.role !== "assistant") return;

		const update = event.assistantMessageEvent;
		if (
			update.type !== "text_delta" &&
			update.type !== "thinking_delta" &&
			update.type !== "toolcall_delta"
		) {
			return;
		}

		const now = performance.now();
		outputSpeed.phase = "streaming";
		outputSpeed.streamStartedAt ??= now;
		outputSpeed.sawStreamUpdate = true;
		outputSpeed.estimatedTokens += estimateStreamTokens(update.delta);

		const reportedTokens = event.message.usage.output ?? 0;
		const currentTokens = reportedTokens > 0 ? reportedTokens : outputSpeed.estimatedTokens;
		outputSpeed.tokensPerSecond = calculateOutputSpeed(
			currentTokens,
			outputSpeed.streamStartedAt,
			now,
		);
		outputSpeed.exact = false;

		// Avoid forcing a full TUI render for every tiny token delta.
		if (now - lastSpeedRefreshAt >= 150) {
			lastSpeedRefreshAt = now;
			refresh();
		}
	});

	pi.on("message_end", async (event, ctx) => {
		latestCtx = ctx;
		if (event.message.role !== "assistant") return;

		const now = performance.now();
		const reportedTokens = event.message.usage.output ?? 0;
		const totalTokens = reportedTokens > 0 ? reportedTokens : outputSpeed.estimatedTokens;
		const startedAt = outputSpeed.sawStreamUpdate
			? (outputSpeed.streamStartedAt ?? outputSpeed.turnStartedAt)
			: (outputSpeed.turnStartedAt ?? outputSpeed.streamStartedAt);

		outputSpeed.tokensPerSecond = calculateOutputSpeed(totalTokens, startedAt, now);
		outputSpeed.exact = reportedTokens > 0;
		outputSpeed.phase = "done";
		refresh();
	});

	pi.on("turn_end", async (_event, ctx) => {
		latestCtx = ctx;
		activity = "done";
		refresh();
		setTimeout(() => {
			if (activity === "done") {
				activity = "idle";
				refresh();
			}
		}, 1500);
	});

	pi.on("model_select", async (_event, ctx) => {
		latestCtx = ctx;
		resetOutputSpeed("idle");
		refresh();
	});

	pi.on("thinking_level_select", async (event, ctx) => {
		latestCtx = ctx;
		thinkingLevel = event.level;
		refresh();
	});

	pi.registerCommand("statusline", {
		description:
			"Statusline: toggle | reload | show | items | left <ids...> | right <ids...>",
		handler: async (args, ctx) => {
			latestCtx = ctx;
			const raw = (args ?? "").trim();
			const [cmd, ...rest] = raw ? raw.split(/\s+/) : ["toggle"];

			if (cmd === "toggle" || cmd === "") {
				cfg.enabled = !cfg.enabled;
				saveConfig(cfg);
				if (cfg.enabled) {
					installFooter(ctx);
					ctx.ui.notify("Statusline enabled", "info");
				} else {
					restoreDefault(ctx);
					ctx.ui.notify("Default footer restored", "info");
				}
				return;
			}

			if (cmd === "reload") {
				const next = loadConfig();
				applyConfig(next, ctx);
				ctx.ui.notify(`Statusline reloaded (${CONFIG_PATH})`, "info");
				return;
			}

			if (cmd === "show") {
				ctx.ui.notify(
					`left=[${cfg.left.join(",")}] right=[${cfg.right.join(",")}] enabled=${cfg.enabled}`,
					"info",
				);
				return;
			}

			if (cmd === "items") {
				ctx.ui.notify(STATUSLINE_ITEMS.join(" "), "info");
				return;
			}

			if (cmd === "left" || cmd === "right") {
				if (rest.length === 0 || (rest.length === 1 && rest[0] === "clear")) {
					if (cmd === "left") cfg.left = [];
					else cfg.right = [];
					saveConfig(cfg);
					applyConfig(cfg, ctx);
					ctx.ui.notify(`Statusline ${cmd} cleared`, "info");
					return;
				}
				const invalid = rest.filter((x) => !isStatuslineItem(x));
				if (invalid.length) {
					ctx.ui.notify(
						`Unknown items: ${invalid.join(", ")}. Use /statusline items`,
						"error",
					);
					return;
				}
				const items = sanitizeItems(rest, []);
				if (cmd === "left") cfg.left = items;
				else cfg.right = items;
				saveConfig(cfg);
				applyConfig(cfg, ctx);
				ctx.ui.notify(`Statusline ${cmd}: ${items.join(" · ") || "(empty)"}`, "info");
				return;
			}

			if (cmd === "enable") {
				cfg.enabled = true;
				saveConfig(cfg);
				installFooter(ctx);
				ctx.ui.notify("Statusline enabled", "info");
				return;
			}

			if (cmd === "disable") {
				cfg.enabled = false;
				saveConfig(cfg);
				restoreDefault(ctx);
				ctx.ui.notify("Default footer restored", "info");
				return;
			}

			ctx.ui.notify(
				"Usage: /statusline [toggle|reload|show|items|left <ids...>|right <ids...>|enable|disable]",
				"error",
			);
		},
	});
}
