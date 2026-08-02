/**
 * Keep gemini-3.6-flash-* usable as a multi-step coding agent.
 *
 * Upstream often returns completed-but-empty responses after tool multi-turns.
 * This extension:
 * 1) Truncates large tool results for flash models (reduces empty-stop rate)
 * 2) Auto-retries empty stop with a short follow-up nudge (capped)
 */
import type { AgentMessage, ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import type { AssistantMessage, TextContent, ImageContent } from "@earendil-works/pi-ai";

const FLASH_MODEL_RE = /gemini-3(?:\.\d+)?-flash/i;
const MAX_TOOL_RESULT_CHARS = 3500;
const MAX_EMPTY_RETRIES = 3;
const RETRY_PROMPT =
	"Continue the unfinished task now. Do not stop with an empty reply. Emit the next tool call, or the final answer if the task is done.";

function isAssistantMessage(msg: AgentMessage | undefined): msg is AssistantMessage {
	return !!msg && msg.role === "assistant";
}

function isFlashModel(modelId: string | undefined): boolean {
	return !!modelId && FLASH_MODEL_RE.test(modelId);
}

function contentTextLength(content: readonly (TextContent | ImageContent)[] | undefined): number {
	if (!content) return 0;
	let n = 0;
	for (const part of content) {
		if (part.type === "text") n += part.text.length;
	}
	return n;
}

function truncateToolContent(
	content: readonly (TextContent | ImageContent)[],
	limit: number,
): { content: (TextContent | ImageContent)[]; truncated: boolean; originalChars: number } {
	const originalChars = contentTextLength(content);
	if (originalChars <= limit) {
		return { content: [...content], truncated: false, originalChars };
	}

	let remaining = limit;
	const out: (TextContent | ImageContent)[] = [];
	for (const part of content) {
		if (part.type !== "text") {
			// Drop images when truncating for fragile models; text is what they choke on most.
			continue;
		}
		if (remaining <= 0) break;
		if (part.text.length <= remaining) {
			out.push(part);
			remaining -= part.text.length;
		} else {
			out.push({
				type: "text",
				text:
					part.text.slice(0, remaining) +
					`\n\n[truncated by gemini-flash-keepalive: kept ${limit}/${originalChars} chars. Re-read a smaller range if you need more.]`,
			});
			remaining = 0;
		}
	}
	if (out.length === 0) {
		out.push({
			type: "text",
			text: `[truncated by gemini-flash-keepalive: original tool output was ${originalChars} chars]`,
		});
	}
	return { content: out, truncated: true, originalChars };
}

function isEmptyStop(msg: AssistantMessage): boolean {
	if (msg.stopReason !== "stop") return false;
	const content = msg.content ?? [];
	if (content.length === 0) return true;
	// Treat thinking-only / blank text as empty for keepalive purposes.
	const hasUseful = content.some((block) => {
		if (block.type === "toolCall") return true;
		if (block.type === "text" && block.text.trim().length > 0) return true;
		return false;
	});
	return !hasUseful;
}

function lastAssistant(messages: AgentMessage[]): AssistantMessage | undefined {
	for (let i = messages.length - 1; i >= 0; i--) {
		const msg = messages[i];
		if (isAssistantMessage(msg)) return msg;
	}
	return undefined;
}

function hadRecentToolResult(messages: AgentMessage[]): boolean {
	// Empty stop right after tool work is the failure mode we care about.
	for (let i = messages.length - 1; i >= 0; i--) {
		const msg = messages[i];
		if (!msg) continue;
		if (msg.role === "toolResult") return true;
		if (msg.role === "user") return false;
		if (isAssistantMessage(msg) && !isEmptyStop(msg)) return false;
	}
	return false;
}

export default function geminiFlashKeepalive(pi: ExtensionAPI) {
	let emptyRetriesThisRun = 0;
	let truncationsThisRun = 0;

	const resetRunState = () => {
		emptyRetriesThisRun = 0;
		truncationsThisRun = 0;
	};

	const notify = (ctx: ExtensionContext, message: string, level: "info" | "warning" = "warning") => {
		if (ctx.hasUI) {
			ctx.ui.notify(message, level);
			ctx.ui.setStatus("gemini-flash-keepalive", message);
		}
	};

	pi.on("agent_start", () => {
		resetRunState();
	});

	pi.on("session_start", () => {
		resetRunState();
	});

	// Soften large tool payloads for flash models only.
	pi.on("tool_result", async (event, ctx) => {
		const modelId = ctx.model?.id;
		if (!isFlashModel(modelId)) return;
		if (event.isError) return;

		const { content, truncated, originalChars } = truncateToolContent(event.content, MAX_TOOL_RESULT_CHARS);
		if (!truncated) return;

		truncationsThisRun += 1;
		if (truncationsThisRun <= 3) {
			notify(
				ctx,
				`flash keepalive: truncated ${event.toolName} result ${originalChars}→≤${MAX_TOOL_RESULT_CHARS} chars`,
				"info",
			);
		}
		return { content };
	});

	// If flash returns empty completed stop after tools, nudge it to continue.
	pi.on("agent_end", async (event, ctx) => {
		const modelId = ctx.model?.id ?? lastAssistant(event.messages)?.model;
		if (!isFlashModel(modelId)) return;

		const assistant = lastAssistant(event.messages);
		if (!assistant || !isEmptyStop(assistant)) {
			// Successful non-empty completion resets empty-retry budget for next run.
			if (assistant && !isEmptyStop(assistant)) emptyRetriesThisRun = 0;
			return;
		}

		// Prefer retrying the post-tool empty-stop case. Also retry pure empty first replies.
		const afterTools = hadRecentToolResult(event.messages);
		if (!afterTools && emptyRetriesThisRun === 0) {
			// Still retry pure empty first turns; flash sometimes no-ops there too.
		}

		if (emptyRetriesThisRun >= MAX_EMPTY_RETRIES) {
			notify(
				ctx,
				`flash keepalive: empty stop after ${MAX_EMPTY_RETRIES} retries. Manual continue or switch model.`,
				"warning",
			);
			if (ctx.hasUI) ctx.ui.setStatus("gemini-flash-keepalive", undefined);
			return;
		}

		emptyRetriesThisRun += 1;
		notify(
			ctx,
			`flash keepalive: empty stop, auto-continue ${emptyRetriesThisRun}/${MAX_EMPTY_RETRIES}`,
			"warning",
		);

		pi.sendUserMessage(
			`${RETRY_PROMPT}\n(retry ${emptyRetriesThisRun}/${MAX_EMPTY_RETRIES}; model=${modelId})`,
			{ deliverAs: "followUp" },
		);
	});

	pi.on("agent_settled", async (_event, ctx) => {
		// Clear transient status once nothing else is queued.
		if (ctx.hasUI && emptyRetriesThisRun === 0) {
			ctx.ui.setStatus("gemini-flash-keepalive", undefined);
		}
	});
}
