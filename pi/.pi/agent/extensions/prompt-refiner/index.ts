import type { AssistantMessage, Context, Model, UserMessage } from "@earendil-works/pi-ai";
import type { ExtensionAPI, ExtensionCommandContext, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { getAgentDir } from "@earendil-works/pi-coding-agent";
import * as fs from "node:fs";
import * as path from "node:path";
import { RefineLoader } from "./loader.ts";
import {
  cleanRefinement,
  collectText,
  DEFAULT_CONFIG,
  evaluateDraft,
  REFINER_SYSTEM_PROMPT,
  ResultCache,
  resolveConfig,
  type RefinerConfig,
} from "./core.ts";

/** Preview/metadata for a completed refinement. */
export interface RefineResult {
  original: string;
  refined: string;
  model: string;
  charsBefore: number;
  charsAfter: number;
  latencyMs: number;
  cached: boolean;
  inputTokens: number | null;
  outputTokens: number | null;
}

export type RefineOutcome = { ok: true; result: RefineResult } | { ok: false; error: string };

export interface PromptRefinerInternals {
  refine(
    draft: string,
    ctx: ExtensionCommandContext,
    signal: AbortSignal | undefined,
    onModelResolved: (modelId: string) => void,
  ): Promise<RefineOutcome>;
  cacheLookup(draft: string, modelId: string): RefineResult | null;
  applyResult(outcome: RefineOutcome, ctx: ExtensionCommandContext): void;
  refineWithUi(draft: string, ctx: ExtensionCommandContext): Promise<RefineOutcome | null>;
  getProjectContext(ctx: ExtensionContext): string;
  getRecentConversationContext(ctx: ExtensionContext, maxTurns?: number): string;
  formatMeta(result: RefineResult): string;
  loadConfig(ctx: ExtensionContext): void;
  reloadConfigFile(): { value?: unknown; error?: string };
  configPath(): string;
  getConfig(): RefinerConfig;
  setConfig(next: RefinerConfig): void;
  getConfigWarnings(): readonly string[];
  cacheSize(): number;
}

/** Extract project context from AGENTS.md, CLAUDE.md, or the system prompt. */
export function getProjectContext(ctx: ExtensionContext): string {
  const cwd = ctx.cwd;
  const projectCandidates = [
    path.join(cwd, "AGENTS.md"),
    path.join(cwd, "CLAUDE.md"),
    path.join(cwd, ".pi", "AGENTS.md"),
  ];

  for (const file of projectCandidates) {
    if (fs.existsSync(file)) {
      try {
        const content = fs.readFileSync(file, "utf-8").trim();
        if (content.length > 0) {
          return content.slice(0, 2000);
        }
      } catch {
        // Ignore read errors and continue
      }
    }
  }

  try {
    const sp = ctx.getSystemPrompt();
    if (sp) {
      return sp.slice(0, 1500);
    }
  } catch {
    // Ignore
  }

  return "";
}

/**
 * Extract recent conversation turns without bulky tool result payloads.
 *
 * Reads the session branch through `getEntries()` (the documented read-only
 * surface) rather than `buildSessionContext()`, which the read-only session
 * manager does not expose to extensions.
 */
export function getRecentConversationContext(ctx: ExtensionContext, maxTurns = 6): string {
  const entries = ctx.sessionManager.getEntries();
  if (!entries || entries.length === 0) {
    return "(No previous conversation in this session)";
  }

  // Collect the text-bearing turns first, then keep the last N of them, so a
  // long tool-heavy stretch cannot crowd out the conversation itself.
  const turns: string[] = [];
  for (const entry of entries) {
    if (entry.type !== "message") continue;
    const message = entry.message;
    if (!message || typeof message !== "object") continue;

    if (message.role === "user") {
      const text = textOf(message.content);
      if (text) turns.push(`User: ${text.slice(0, 800)}`);
    } else if (message.role === "assistant") {
      const text = textOf(message.content);
      if (text) turns.push(`Assistant: ${text.slice(0, 800)}`);
    }
  }

  if (turns.length === 0) return "(No previous text conversation)";
  return turns.slice(-maxTurns * 2).join("\n\n");
}

/** Flatten a message content payload into its plain text, if any. */
function textOf(content: unknown): string {
  if (typeof content === "string") return content.trim();
  if (!Array.isArray(content)) return "";
  const parts: string[] = [];
  for (const block of content) {
    if (
      block &&
      typeof block === "object" &&
      (block as { type?: unknown }).type === "text" &&
      typeof (block as { text?: unknown }).text === "string"
    ) {
      parts.push((block as { text: string }).text);
    }
  }
  return parts.join("\n").trim();
}

/** "cp · 12→38 chars · 0.8s · cache hit · 150+90 tok" */
export function formatMeta(result: RefineResult): string {
  const parts = [
    result.model,
    `${result.charsBefore}\u2192${result.charsAfter} chars`,
    `${(result.latencyMs / 1000).toFixed(1)}s`,
  ];
  if (result.cached) parts.push("cache hit");
  if (result.inputTokens !== null && result.outputTokens !== null) {
    parts.push(`${result.inputTokens}+${result.outputTokens} tok`);
  }
  return parts.join(" \u00b7 ");
}

/** Resolve the model used for refinement; falls back to the session model. */
export function resolveRefinerModel(ctx: ExtensionContext, config: RefinerConfig): Model<any> | undefined {
  const wanted = config.model?.trim();
  if (!wanted) return ctx.model;

  const allModels = ctx.modelRegistry.getAll();
  const exact = allModels.find((m) => m.id === wanted);
  const candidate = exact ?? allModels.find((m) => m.id.toLowerCase().includes(wanted.toLowerCase()));

  if (candidate && ctx.modelRegistry.hasConfiguredAuth(candidate)) {
    return candidate;
  }

  return ctx.model;
}

export function buildRefinerPayload(draft: string, projectContext: string, recentConversation: string): string {
  return `<project_context>
${projectContext || "(None)"}
</project_context>

<recent_conversation>
${recentConversation}
</recent_conversation>

<draft_instruction>
${draft}
</draft_instruction>`;
}

export default function promptRefinerExtension(pi: ExtensionAPI): void {
  const configPath = () => path.join(getAgentDir(), "extensions", "prompt-refiner", "config.json");

  let lastOriginalText: string | null = null;
  // Read once per session; edit the file and run /refine reload to pick it up.
  let config: RefinerConfig = { ...DEFAULT_CONFIG };
  let configWarnings: string[] = [];
  let cache = new ResultCache<RefineResult>(DEFAULT_CONFIG.cacheMax, DEFAULT_CONFIG.cacheTtlMs);

  function readConfigFile(): { value?: unknown; error?: string } {
    const file = configPath();
    if (!fs.existsSync(file)) return {};
    try {
      return { value: JSON.parse(fs.readFileSync(file, "utf-8")) };
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      return { error: `Could not read ${file}: ${message}` };
    }
  }

  function loadConfig(ctx: ExtensionContext): void {
    const file = readConfigFile();
    const resolved = resolveConfig({ file: file.value, env: process.env });
    config = resolved.config;
    configWarnings = file.error ? [file.error, ...resolved.warnings] : resolved.warnings;
    // New config means the old cache was keyed by a different prompt/model set.
    cache = new ResultCache<RefineResult>(config.cacheMax, config.cacheTtlMs);
    for (const warning of configWarnings) {
      ctx.ui.notify(`prompt-refiner: ${warning}`, "warning");
    }
  }

  async function refine(
    draft: string,
    ctx: ExtensionCommandContext,
    signal: AbortSignal | undefined,
    onModelResolved: (modelId: string) => void,
  ): Promise<RefineOutcome> {
    const gate = evaluateDraft(draft, config);
    if (gate.skip) return { ok: false, error: gate.reason };

    const refinerModel = resolveRefinerModel(ctx, config);
    if (!refinerModel) {
      return { ok: false, error: "No model is available for refinement" };
    }
    onModelResolved(refinerModel.id);

    const started = Date.now();
    const key = ResultCache.key([REFINER_SYSTEM_PROMPT, refinerModel.id, gate.text]);

    const requestContext: Context = {
      systemPrompt: REFINER_SYSTEM_PROMPT,
      messages: [
        {
          role: "user",
          content: [
            {
              type: "text",
              text: buildRefinerPayload(gate.text, getProjectContext(ctx), getRecentConversationContext(ctx)),
            },
          ],
          timestamp: Date.now(),
        } satisfies UserMessage,
      ],
    };

    let response: AssistantMessage;
    try {
      response = await ctx.modelRegistry.complete(refinerModel, requestContext, {
        signal,
        maxTokens: config.maxTokens,
      });
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      return { ok: false, error: `Refinement failed: ${message}` };
    }

    if (response.stopReason === "aborted") {
      return { ok: false, error: "" };
    }
    if (response.stopReason === "error") {
      return { ok: false, error: `Refinement failed: ${response.errorMessage || "Unknown error"}` };
    }

    const { text: rawText, thinkingOnly } = collectText(response.content);
    if (thinkingOnly) {
      return {
        ok: false,
        error: "The model returned only reasoning; try again or switch to a non-reasoning model",
      };
    }

    const cleaned = cleanRefinement(rawText, config);
    if (!cleaned.ok) return cleaned;

    const result: RefineResult = {
      original: gate.text,
      refined: cleaned.text,
      model: refinerModel.id,
      charsBefore: gate.text.length,
      charsAfter: cleaned.text.length,
      latencyMs: Date.now() - started,
      cached: false,
      inputTokens: response.usage?.input ?? null,
      outputTokens: response.usage?.output ?? null,
    };
    cache.set(key, result);
    return { ok: true, result };
  }

  function cacheLookup(draft: string, modelId: string): RefineResult | null {
    const hit = cache.get(ResultCache.key([REFINER_SYSTEM_PROMPT, modelId, draft]));
    if (!hit) return null;
    return { ...hit, cached: true, latencyMs: 0 };
  }

  async function refineWithUi(draft: string, ctx: ExtensionCommandContext): Promise<RefineOutcome | null> {
    const gate = evaluateDraft(draft, config);
    if (gate.skip) {
      ctx.ui.notify(gate.reason, "warning");
      return null;
    }

    const refinerModel = resolveRefinerModel(ctx, config);
    if (refinerModel) {
      const cached = cacheLookup(gate.text, refinerModel.id);
      if (cached) {
        ctx.ui.notify(`Reused a cached refinement from ${refinerModel.id}`, "info");
        return { ok: true, result: cached };
      }
    }

    if (ctx.mode !== "tui") {
      return refine(gate.text, ctx, ctx.signal, () => {});
    }

    const modelLabel = refinerModel?.id ?? "model";
    return ctx.ui.custom<RefineOutcome | null>((tui, theme, _kb, done) => {
      const loader = new RefineLoader(tui, theme, `Refining with ${modelLabel}`);
      loader.onAbort = () => done(null);

      refine(gate.text, ctx, loader.signal, () => {})
        .then((outcome) => {
          loader.dispose();
          done(outcome);
        })
        .catch((err) => {
          loader.dispose();
          const message = err instanceof Error ? err.message : String(err);
          ctx.ui.notify(`Refinement error: ${message}`, "error");
          done(null);
        });

      return loader;
    });
  }

  /**
   * Put the refinement straight into the editor. No confirmation dialog: the
   * result is one Escape-free `/refine undo` away, and a modal between the user
   * and every refinement costs more than it protects.
   */
  function applyResult(outcome: RefineOutcome, ctx: ExtensionCommandContext): void {
    if (!outcome.ok) {
      if (outcome.error !== "") ctx.ui.notify(outcome.error, "error");
      return;
    }

    const result = outcome.result;
    ctx.ui.setEditorText(result.refined);
    lastOriginalText = result.original;
    ctx.ui.notify(`Prompt refined with ${formatMeta(result)} (Run '/refine undo' to revert)`, "info");
  }

  internals.current = {
    refine,
    cacheLookup,
    applyResult,
    refineWithUi,
    getProjectContext,
    getRecentConversationContext,
    formatMeta,
    loadConfig,
    reloadConfigFile: readConfigFile,
    configPath,
    getConfig: () => config,
    setConfig: (next) => {
      config = next;
      cache = new ResultCache<RefineResult>(config.cacheMax, config.cacheTtlMs);
    },
    getConfigWarnings: () => configWarnings,
    cacheSize: () => cache.size,
  };

  pi.on("session_start", (_event, ctx) => {
    loadConfig(ctx);
  });

  pi.registerCommand("refine", {
    description: "Refine the draft prompt (Usage: /refine [prompt] | /refine undo | /refine reload)",
    getArgumentCompletions: (prefix) => {
      const options: Array<{ value: string; label: string; description: string }> = [
        { value: "undo", label: "undo", description: "Restore the pre-refinement draft" },
        { value: "reload", label: "reload", description: "Re-read config.json" },
      ];
      const matches = options.filter((o) => o.value.startsWith(prefix.trim()));
      return matches.length > 0 ? matches : null;
    },
    handler: async (args, ctx) => {
      const trimmedArgs = args?.trim() ?? "";
      const lower = trimmedArgs.toLowerCase();

      if (lower === "undo") {
        if (!lastOriginalText) {
          ctx.ui.notify("No previous prompt to undo", "warning");
          return;
        }
        ctx.ui.setEditorText(lastOriginalText);
        lastOriginalText = null;
        ctx.ui.notify("Reverted to the original prompt", "info");
        return;
      }

      if (lower === "reload") {
        loadConfig(ctx);
        const count = configWarnings.length;
        ctx.ui.notify(
          count === 0
            ? "prompt-refiner config reloaded"
            : `prompt-refiner config reloaded with ${count} warning(s)`,
          count === 0 ? "info" : "warning",
        );
        return;
      }

      let draft = trimmedArgs;
      if (draft === "") {
        draft = ctx.ui.getEditorText().trim();
      }
      if (draft === "" && ctx.hasUI) {
        const input = await ctx.ui.editor("Enter prompt to refine:", "");
        draft = input?.trim() ?? "";
      }
      if (draft === "") {
        ctx.ui.notify("Please provide a prompt to refine: /refine <prompt>", "warning");
        return;
      }

      const outcome = await refineWithUi(draft, ctx);
      if (outcome === null) return;
      applyResult(outcome, ctx);
    },
  });
}

/**
 * Test seam. The pi extension factory returns nothing, so the command-level
 * helpers are published here for tests that drive a fake pi API instead of
 * booting the real runtime.
 */
export const internals: { current?: PromptRefinerInternals } = {};
