import { test } from "node:test";
import assert from "node:assert/strict";

import {
  cleanRefinement,
  collectText,
  DEFAULT_CONFIG,
  ENV_PREFIX,
  evaluateDraft,
  PROMPT_VERSION,
  resolveConfig,
  ResultCache,
  stripChainLines,
  stripEnclosingCodeBlock,
  type RefinerConfig,
} from "./core.ts";

const CFG: RefinerConfig = { ...DEFAULT_CONFIG, minChars: 10, resultMaxChars: 100 };

test("gate skips empty, short, and oversized drafts, and trims the rest", () => {
  assert.equal(evaluateDraft("", CFG).skip, true);
  assert.equal(evaluateDraft("   \n ", CFG).skip, true);
  assert.equal(evaluateDraft("too short", CFG).skip, true);

  const long = "x".repeat(CFG.maxChars + 1);
  const longResult = evaluateDraft(long, CFG);
  assert.equal(longResult.skip, true);

  const ok = evaluateDraft("  fix the parser bug  ", CFG);
  assert.equal(ok.skip, false);
  assert.equal(ok.skip === false && ok.text, "fix the parser bug");
});

test("minChars of 0 only rejects empty drafts", () => {
  const config = { ...CFG, minChars: 0 };
  const result = evaluateDraft("hi", config);
  assert.equal(result.skip, false);
});

test("collectText ignores thinking blocks and flags thinking-only replies", () => {
  const mixed = collectText([
    { type: "thinking", thinking: "let me think" } as never,
    { type: "text", text: "the answer" },
  ]);
  assert.equal(mixed.text, "the answer");
  assert.equal(mixed.thinkingOnly, false);

  const thinkingOnly = collectText([{ type: "thinking", thinking: "still thinking" } as never]);
  assert.equal(thinkingOnly.text, "");
  assert.equal(thinkingOnly.thinkingOnly, true);

  const empty = collectText([]);
  assert.equal(empty.text, "");
  assert.equal(empty.thinkingOnly, false);
});

test("stripEnclosingCodeBlock removes fences and quote wrapping", () => {
  assert.equal(stripEnclosingCodeBlock("```\n[goal] do it\n```"), "[goal] do it");
  assert.equal(stripEnclosingCodeBlock("```text\n[goal] do it\n```"), "[goal] do it");
  assert.equal(stripEnclosingCodeBlock('"do it"'), "do it");
  assert.equal(stripEnclosingCodeBlock("\u201cdo it\u201d"), "do it");
  assert.equal(stripEnclosingCodeBlock("[goal] do it"), "[goal] do it");
});

test("stripChainLines drops pure commentary but keeps substantive lines", () => {
  assert.equal(stripChainLines("Sure, here is the optimized prompt:\n[goal] x"), "[goal] x");
  assert.equal(stripChainLines("好的。\n[goal] x"), "[goal] x");
  // A line that opens with a process word but carries content must survive.
  assert.equal(stripChainLines("[goal] x\nFirst, parse the arguments"), "[goal] x\nFirst, parse the arguments");
});

test("cleanRefinement enforces the length guard and rejects empty results", () => {
  assert.deepEqual(cleanRefinement("", CFG), {
    ok: false,
    error: "The model returned no text; try again or switch models",
  });

  const tooLong = cleanRefinement("y".repeat(CFG.resultMaxChars + 1), CFG);
  assert.equal(tooLong.ok, false);

  const onlyCommentary = cleanRefinement("Sure, here is the optimized prompt:", CFG);
  assert.equal(onlyCommentary.ok, false);

  const good = cleanRefinement("```\n[goal] fix the parser\n```", CFG);
  assert.deepEqual(good, { ok: true, text: "[goal] fix the parser" });
});

test("resolveConfig layers defaults, file, then environment", () => {
  const fromFile = resolveConfig({ file: { model: "cheap-model", maxTokens: 512 } });
  assert.equal(fromFile.config.model, "cheap-model");
  assert.equal(fromFile.config.maxTokens, 512);
  assert.equal(fromFile.config.minChars, DEFAULT_CONFIG.minChars);
  assert.deepEqual(fromFile.warnings, []);

  const fromEnv = resolveConfig({
    file: { maxTokens: 512 },
    env: { [`${ENV_PREFIX}MAX_TOKENS`]: "999", [`${ENV_PREFIX}MODEL`]: "env-model" },
  });
  assert.equal(fromEnv.config.maxTokens, 999);
  assert.equal(fromEnv.config.model, "env-model");

  // null and "" both mean "follow the session model"
  assert.equal(resolveConfig({ env: { [`${ENV_PREFIX}MODEL`]: "" } }).config.model, null);
  assert.equal(resolveConfig({ env: { [`${ENV_PREFIX}MODEL`]: "  " } }).config.model, null);
});

test("resolveConfig reports bad values instead of throwing", () => {
  const bad = resolveConfig({
    file: { maxTokens: "not a number", maxChars: -5, minChars: -1 },
    env: { [`${ENV_PREFIX}RESULT_MAX_CHARS`]: "0" },
  });
  assert.equal(bad.config.maxTokens, DEFAULT_CONFIG.maxTokens);
  assert.equal(bad.config.maxChars, DEFAULT_CONFIG.maxChars);
  assert.equal(bad.config.minChars, DEFAULT_CONFIG.minChars);
  assert.equal(bad.config.resultMaxChars, DEFAULT_CONFIG.resultMaxChars);
  assert.equal(bad.warnings.length, 4);
  for (const warning of bad.warnings) assert.match(warning, /ignored/);

  // A non-object config file must not crash the extension.
  const notAnObject = resolveConfig({ file: [1, 2, 3] });
  assert.equal(notAnObject.config.maxTokens, DEFAULT_CONFIG.maxTokens);
  assert.equal(notAnObject.warnings.length, 1);
});

test("cache hits, touches, evicts the least recently used, and honors ttl 0", () => {
  const cache = new ResultCache<string>(2, 10_000);
  cache.set("a", "1");
  cache.set("b", "2");

  assert.equal(cache.get("a"), "1"); // touch a, so b is now oldest
  cache.set("c", "3");
  assert.equal(cache.get("a"), "1");
  assert.equal(cache.get("b"), null);
  assert.equal(cache.get("c"), "3");

  // max 0 disables caching entirely
  const disabled = new ResultCache<string>(0, 10_000);
  disabled.set("k", "v");
  assert.equal(disabled.get("k"), null);

  // ttl 0 means "never expire" rather than "expire immediately"
  const forever = new ResultCache<string>(4, 0);
  forever.set("k", "v");
  assert.equal(forever.get("k"), "v");
});

test("cache keys separate prompts, models, and prompt versions", () => {
  const a = ResultCache.key([String(PROMPT_VERSION), "m1", "draft"]);
  const b = ResultCache.key([String(PROMPT_VERSION), "m2", "draft"]);
  const c = ResultCache.key([String(PROMPT_VERSION + 1), "m1", "draft"]);
  assert.notEqual(a, b);
  assert.notEqual(a, c);
  assert.equal(a, ResultCache.key([String(PROMPT_VERSION), "m1", "draft"]));
});
