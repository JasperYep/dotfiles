// Pure logic behind the prompt-refiner extension: config resolution, draft
// gating, the LRU result cache, and result cleaning. Nothing here imports pi,
// so `node --test core.test.ts` runs it without a pi runtime.

import { createHash } from "node:crypto";

/**
 * Bump whenever REFINER_SYSTEM_PROMPT changes. The cache key includes this, so
 * results produced by an older prompt can never be replayed by a newer one.
 */
export const PROMPT_VERSION = 2;

export const REFINER_SYSTEM_PROMPT = `You are a prompt refiner acting as a composer middleware in an interactive coding agent session.
Your job is to rewrite the user's draft prompt so the main agent can execute it accurately and effectively without ambiguity.

Core Principles:
1. Make implicit intent explicit: resolve pronouns ("it", "this", "the second one"), relative references, and established terminology using the session context.
2. Add minimal necessary context and constraints: specify input/output expectations and boundary conditions when missing, but do not hallucinate new requirements.
3. Anti-overengineering:
   - DO NOT add fake urgency or emotional tokens (e.g. "CRITICAL!!!", "YOU MUST", "VERY IMPORTANT").
   - DO NOT add generic personas ("You are an expert 10x developer...") or unnecessary Chain-of-Thought forcing unless sequential steps are strictly required.
   - DO NOT turn simple, clear instructions into bloated multi-page specifications.
   - If the draft is already clear, concise, and unambiguous, keep it as-is with minimal edits.
4. DO NOT answer or perform the task. Only rewrite the instruction.
5. Preserve the language of the draft: always write the refined prompt in the same language as the user's original input (e.g. a Chinese draft must stay Chinese, an English draft must stay English). Never translate or switch languages, even if the surrounding context, code, or technical terms are in another language.

Output requirement:
Output ONLY the rewritten prompt text. Do not include introductory notes, explanations, or enclosing markdown code fences around the entire response.`;

export interface RefinerConfig {
  /** Model id used for refinement. `null` follows the session model. */
  model: string | null;
  maxTokens: number;
  /** Drafts shorter than this are skipped. 0 means only empty drafts skip. */
  minChars: number;
  maxChars: number;
  /** Results longer than this are rejected as leaked reasoning. */
  resultMaxChars: number;
  /** 0 disables the cache entirely. */
  cacheMax: number;
  cacheTtlMs: number;
}

export const DEFAULT_CONFIG: RefinerConfig = {
  // Local default for the author's own provider; override with the config file
  // or PI_PROMPT_REFINER_MODEL, or set null to follow the session model.
  model: "cp",
  maxTokens: 2048,
  minChars: 0,
  maxChars: 8000,
  resultMaxChars: 4000,
  cacheMax: 100,
  cacheTtlMs: 30 * 60 * 1000,
};

export const ENV_PREFIX = "PI_PROMPT_REFINER_";

const ENV_SUFFIX: Record<keyof RefinerConfig, string> = {
  model: "MODEL",
  maxTokens: "MAX_TOKENS",
  minChars: "MIN_CHARS",
  maxChars: "MAX_CHARS",
  resultMaxChars: "RESULT_MAX_CHARS",
  cacheMax: "CACHE_MAX",
  cacheTtlMs: "CACHE_TTL_MS",
};

/** Fields that must stay positive or the guard they power stops guarding. */
const POSITIVE_FIELDS = new Set<keyof RefinerConfig>(["maxTokens", "maxChars", "resultMaxChars"]);

export interface ConfigResolution {
  config: RefinerConfig;
  /** Human-readable notes about ignored values; never throws on bad input. */
  warnings: string[];
}

function applyField(
  target: RefinerConfig,
  key: keyof RefinerConfig,
  raw: unknown,
  source: string,
  warnings: string[],
): void {
  if (raw === undefined) return;

  if (key === "model") {
    if (raw === null) {
      target.model = null;
      return;
    }
    if (typeof raw === "string") {
      const trimmed = raw.trim();
      target.model = trimmed === "" ? null : trimmed;
      return;
    }
    warnings.push(`${source}: "model" must be a string or null; ignored`);
    return;
  }

  let value: number | undefined;
  if (typeof raw === "number" && Number.isFinite(raw)) {
    value = raw;
  } else if (typeof raw === "string" && raw.trim() !== "") {
    const parsed = Number(raw);
    if (Number.isFinite(parsed)) value = parsed;
  }
  if (value === undefined) {
    warnings.push(`${source}: "${key}" must be a number; ignored`);
    return;
  }
  if (POSITIVE_FIELDS.has(key) && value <= 0) {
    warnings.push(`${source}: "${key}" must be greater than 0; ignored`);
    return;
  }
  if (value < 0) {
    warnings.push(`${source}: "${key}" must not be negative; ignored`);
    return;
  }
  target[key] = value;
}

/**
 * Merge defaults <- config file <- environment variables.
 *
 * `file` is the parsed JSON config; `env` is normally `process.env`. Invalid
 * values are reported in `warnings` and skipped rather than thrown, so one typo
 * cannot take the whole extension down.
 */
export function resolveConfig(input: {
  file?: unknown;
  env?: Record<string, string | undefined>;
  defaults?: RefinerConfig;
}): ConfigResolution {
  const config: RefinerConfig = { ...(input.defaults ?? DEFAULT_CONFIG) };
  const warnings: string[] = [];

  if (input.file !== undefined && input.file !== null) {
    if (typeof input.file !== "object" || Array.isArray(input.file)) {
      warnings.push("Config file is not a JSON object; ignored");
    } else {
      const source = input.file as Record<string, unknown>;
      for (const key of Object.keys(config) as (keyof RefinerConfig)[]) {
        applyField(config, key, source[key], "Config file", warnings);
      }
    }
  }

  const env = input.env ?? {};
  for (const key of Object.keys(config) as (keyof RefinerConfig)[]) {
    applyField(config, key, env[ENV_PREFIX + ENV_SUFFIX[key]], `${ENV_PREFIX}${ENV_SUFFIX[key]}`, warnings);
  }

  return { config, warnings };
}

export type GateResult = { skip: true; reason: string } | { skip: false; text: string };

/** Decide whether a draft is worth a model call, and normalize it. */
export function evaluateDraft(rawText: string, config: RefinerConfig): GateResult {
  const text = (rawText ?? "").trim();
  if (text === "") return { skip: true, reason: "Nothing to refine: the draft is empty" };
  if (text.length < config.minChars) {
    return { skip: true, reason: `Nothing to refine: the draft is shorter than ${config.minChars} characters` };
  }
  if (text.length > config.maxChars) {
    return { skip: true, reason: `Draft is longer than ${config.maxChars} characters; edit it manually instead` };
  }
  return { skip: false, text };
}

/**
 * Small LRU with a TTL. Disabled when `max` is 0, so a config value can turn
 * it off without a separate branch at the call site.
 */
export class ResultCache<V> {
  private readonly entries = new Map<string, { value: V; at: number }>();
  private readonly max: number;
  private readonly ttlMs: number;

  // Plain fields rather than constructor parameter properties: Node's
  // type-stripping cannot run those, and this file is loaded by node --test.
  constructor(max: number, ttlMs: number) {
    this.max = max;
    this.ttlMs = ttlMs;
  }

  /** Stable hash over the parts that determine the result. */
  static key(parts: readonly string[]): string {
    return createHash("sha256").update(parts.join("\u0000")).digest("hex");
  }

  get size(): number {
    return this.entries.size;
  }

  get(key: string): V | null {
    const hit = this.entries.get(key);
    if (hit === undefined) return null;
    if (this.ttlMs > 0 && Date.now() - hit.at > this.ttlMs) {
      this.entries.delete(key);
      return null;
    }
    // Touch: reinsert so the oldest entry is always first in iteration order.
    this.entries.delete(key);
    this.entries.set(key, hit);
    return hit.value;
  }

  set(key: string, value: V): void {
    if (this.max <= 0) return;
    this.entries.delete(key);
    this.entries.set(key, { value, at: Date.now() });
    while (this.entries.size > this.max) {
      const oldest = this.entries.keys().next().value;
      if (oldest === undefined) break;
      this.entries.delete(oldest);
    }
  }
}

export interface ContentBlockLike {
  type: string;
  text?: string;
}

/**
 * Join the text blocks of an assistant message, ignoring thinking blocks
 * (reasoning traces must never be applied to the user's editor).
 */
export function collectText(blocks: readonly ContentBlockLike[]): { text: string; thinkingOnly: boolean } {
  const texts: string[] = [];
  let sawThinking = false;
  for (const block of blocks) {
    if (block.type === "text" && typeof block.text === "string") {
      texts.push(block.text);
    } else if (block.type === "thinking") {
      sawThinking = true;
    }
  }
  const text = texts.join("\n").trim();
  return { text, thinkingOnly: text === "" && sawThinking };
}

/** Trim an accidental markdown fence or a pair of enclosing quotes. */
export function stripEnclosingCodeBlock(text: string): string {
  let trimmed = text.trim();
  const match = trimmed.match(/^```(?:markdown|text|prompt)?\s*\n([\s\S]*?)\n```$/i);
  if (match && match[1]) {
    trimmed = match[1].trim();
  }
  if (
    (trimmed.startsWith('"') && trimmed.endsWith('"') && trimmed.length >= 2) ||
    (trimmed.startsWith("\u201c") && trimmed.endsWith("\u201d") && trimmed.length >= 2)
  ) {
    trimmed = trimmed.slice(1, -1).trim();
  }
  return trimmed;
}

/**
 * Words and phrases that carry no instruction on their own. A line built only
 * from these (plus punctuation) is meta-commentary and gets dropped.
 */
const FILLER_PHRASES =
  /(好的|没问题|收到|我来|让我|首先|其次|然后|接下来|总结|总的来说|综上所述|我的思考|思考过程|推理过程|分析如下|优化后的提示词如下|精炼后的提示词如下|以下是优化结果|以下是精炼结果|结果如下|sure|of course|here is|here's|below is|the optimized prompt|the refined prompt|optimized prompt|refined prompt|as follows)/giu;

/** Punctuation and spacing left over once the filler phrases are removed. */
const PUNCTUATION_ONLY = /[\s,，、;；:：.。!！?？'"`“”‘’()（）【】\[\]{}<>—–\-~*#>]+/gu;

/**
 * Openers that make a short line a process note ("Let me analyze this a bit").
 * Deliberately narrow: correctness words like "first" are absent so that
 * "First, parse the arguments" survives the filter.
 */
const PROCESS_OPENER = /^(我想|我认为|我觉得|让我|我先|我们可以|我们需要|我的思路|思路如下|简短分析|重写如下|正文如下|let me|i think|i'll|i will)[\s\S]{0,40}$/u;

/**
 * Drop whole lines that are pure meta-commentary ("Sure, here is the
 * optimized prompt:"). Conservative on purpose: a line carrying substance is
 * kept even when it opens with a process word.
 */
export function stripChainLines(text: string): string {
  const kept: string[] = [];
  for (const line of text.split("\n")) {
    const trimmed = line.trim();
    if (trimmed !== "") {
      const leftover = trimmed.replace(FILLER_PHRASES, "").replace(PUNCTUATION_ONLY, "");
      if (leftover === "" || PROCESS_OPENER.test(trimmed)) continue;
    }
    kept.push(line);
  }
  return kept.join("\n").trim();
}

export type CleanResult = { ok: true; text: string } | { ok: false; error: string };

/**
 * Turn a raw model response into the text we are willing to put in the editor:
 * fence/quote removal, a length guard against leaked reasoning, and
 * meta-commentary removal.
 */
export function cleanRefinement(rawText: string, config: RefinerConfig): CleanResult {
  let text = stripEnclosingCodeBlock(rawText);
  if (text === "") {
    return { ok: false, error: "The model returned no text; try again or switch models" };
  }
  if (text.length > config.resultMaxChars) {
    return {
      ok: false,
      error: `Refinement is longer than ${config.resultMaxChars} characters; it probably contains reasoning. Try again`,
    };
  }
  text = stripChainLines(text);
  if (text === "") {
    return { ok: false, error: "The refinement was only commentary; try again" };
  }
  return { ok: true, text };
}
