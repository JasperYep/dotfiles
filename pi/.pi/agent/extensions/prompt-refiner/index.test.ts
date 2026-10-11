import { test } from "node:test";
import assert from "node:assert/strict";

import promptRefinerExtension, { internals, type RefineResult } from "./index.ts";
import { DEFAULT_CONFIG, type RefinerConfig } from "./core.ts";

/**
 * Minimal stand-ins for the pi extension API, enough to drive the command
 * handler end to end: gate -> model call -> editor write.
 */

interface Calls {
  notifications: Array<{ message: string; type: string | undefined }>;
  editorWrites: string[];
  completeCalls: number;
  selectCalls: number;
}

/** Enough of a theme for the loader to render without a terminal. */
const FAKE_THEME = {
  fg: (_color: string, text: string) => text,
  bg: (_color: string, text: string) => text,
  bold: (text: string) => text,
  italic: (text: string) => text,
};

const FAKE_TUI = { requestRender: () => {}, setFocus: () => {} };

const GOOD_RESPONSE = {
  role: "assistant",
  content: [{ type: "text", text: "refined draft" }],
  stopReason: "stop",
  usage: { input: 10, output: 5 },
};

function makeCtx(options: {
  calls: Calls;
  editorText?: string;
  mode?: "tui" | "print";
  hasUI?: boolean;
  response?: unknown;
}): any {
  const { calls } = options;
  const response = options.response ?? GOOD_RESPONSE;
  return {
    mode: options.mode ?? "tui",
    hasUI: options.hasUI ?? true,
    cwd: "/tmp",
    signal: undefined,
    model: { id: "session-model" },
    modelRegistry: {
      getAll: () => [{ id: "cp" }, { id: "session-model" }],
      hasConfiguredAuth: () => true,
      complete: async () => {
        calls.completeCalls += 1;
        return response;
      },
    },
    sessionManager: { getEntries: () => [] },
    getSystemPrompt: () => "",
    ui: {
      notify: (message: string, type?: string) => calls.notifications.push({ message, type }),
      getEditorText: () => options.editorText ?? "",
      setEditorText: (text: string) => calls.editorWrites.push(text),
      editor: async () => undefined,
      select: async () => {
        calls.selectCalls += 1;
        return undefined;
      },
      custom: (factory: Function) =>
        new Promise((resolve) => {
          const loader = factory(FAKE_TUI, FAKE_THEME, {}, resolve);
          if (loader && typeof loader.dispose === "function") loader.dispose();
        }),
    },
  };
}

function makePi() {
  const commands = new Map<string, { handler: (args: string, ctx: unknown) => Promise<void> }>();
  const handlers = new Map<string, Function>();
  return {
    pi: {
      registerCommand: (name: string, options: { handler: (args: string, ctx: unknown) => Promise<void> }) =>
        void commands.set(name, options),
      on: (event: string, handler: Function) => void handlers.set(event, handler),
    },
    commands,
    handlers,
  };
}

function freshCalls(): Calls {
  return { notifications: [], editorWrites: [], completeCalls: 0, selectCalls: 0 };
}

function setup(config?: Partial<RefinerConfig>) {
  const harness = makePi();
  promptRefinerExtension(harness.pi as never);
  assert.ok(internals.current, "extension must publish its internals");
  internals.current.setConfig({ ...DEFAULT_CONFIG, ...config });
  return { ...harness, api: internals.current };
}

test("registers the /refine command and a session_start config loader", () => {
  const { commands, handlers } = setup();
  assert.ok(commands.has("refine"));
  assert.ok(handlers.has("session_start"));
});

test("applies the refinement with no confirmation dialog", async () => {
  const calls = freshCalls();
  const { commands } = setup({ minChars: 0 });
  const ctx = makeCtx({ calls, editorText: "rough draft" });

  await commands.get("refine")!.handler("", ctx);

  assert.equal(calls.editorWrites.at(-1), "refined draft");
  assert.equal(calls.selectCalls, 0, "no dialog may block the refinement");
  assert.match(calls.notifications.at(-1)!.message, /Run '\/refine undo' to revert/);
});

test("undo restores the pre-refinement draft exactly once", async () => {
  const calls = freshCalls();
  const { commands } = setup({ minChars: 0 });
  const ctx = makeCtx({ calls, editorText: "rough draft" });

  await commands.get("refine")!.handler("", ctx);
  await commands.get("refine")!.handler("undo", ctx);
  assert.equal(calls.editorWrites.at(-1), "rough draft");

  // A second undo has nothing left to restore.
  const before = calls.editorWrites.length;
  await commands.get("refine")!.handler("undo", ctx);
  assert.equal(calls.editorWrites.length, before);
  assert.match(calls.notifications.at(-1)!.message, /No previous prompt to undo/);
});

test("/refine <prompt> refines the argument instead of the editor text", async () => {
  const calls = freshCalls();
  const { commands } = setup({ minChars: 0 });
  const ctx = makeCtx({ calls, editorText: "editor text that must be ignored" });

  await commands.get("refine")!.handler("explicit draft", ctx);

  assert.equal(calls.completeCalls, 1);
  assert.equal(calls.editorWrites.at(-1), "refined draft");
});

test("print mode applies the result without touching dialogs", async () => {
  const calls = freshCalls();
  const { commands } = setup({ minChars: 0 });
  const ctx = makeCtx({ calls, editorText: "rough draft", mode: "print", hasUI: false });

  await commands.get("refine")!.handler("", ctx);
  assert.equal(calls.editorWrites.at(-1), "refined draft");
  assert.equal(calls.selectCalls, 0);
});

test("short drafts are rejected before any model call", async () => {
  const calls = freshCalls();
  const { commands } = setup({ minChars: 20 });
  const ctx = makeCtx({ calls, editorText: "too short" });

  await commands.get("refine")!.handler("", ctx);

  assert.equal(calls.completeCalls, 0);
  assert.equal(calls.editorWrites.length, 0);
  assert.match(calls.notifications.at(-1)!.message, /shorter than 20/);
});

test("an oversized draft is rejected before any model call", async () => {
  const calls = freshCalls();
  const { commands } = setup({ maxChars: 10 });
  const ctx = makeCtx({ calls, editorText: "x".repeat(400) });

  await commands.get("refine")!.handler("", ctx);

  assert.equal(calls.completeCalls, 0);
  assert.match(calls.notifications.at(-1)!.message, /longer than 10/);
});

test("a repeated identical draft is served from cache", async () => {
  const calls = freshCalls();
  const { commands } = setup({ minChars: 0 });
  const ctx = makeCtx({ calls, editorText: "a draft long enough to refine" });

  await commands.get("refine")!.handler("", ctx);
  assert.equal(calls.completeCalls, 1);

  await commands.get("refine")!.handler("", ctx);
  assert.equal(calls.completeCalls, 1, "a cache hit must not call the model again");
  assert.equal(calls.editorWrites.at(-1), "refined draft");
});

test("an empty cache config disables the cache", async () => {
  const calls = freshCalls();
  const { commands, api } = setup({ minChars: 0, cacheMax: 0 });
  const ctx = makeCtx({ calls, editorText: "a draft long enough to refine" });

  await commands.get("refine")!.handler("", ctx);
  await commands.get("refine")!.handler("", ctx);

  assert.equal(calls.completeCalls, 2);
  assert.equal(api.cacheSize(), 0);
});

test("thinking-only responses surface a readable error and leave the editor alone", async () => {
  const calls = freshCalls();
  const { commands } = setup({ minChars: 0 });
  const ctx = makeCtx({
    calls,
    editorText: "a draft long enough to refine",
    response: {
      role: "assistant",
      content: [{ type: "thinking", thinking: "reasoning only" }],
      stopReason: "stop",
      usage: { input: 1, output: 1 },
    },
  });

  await commands.get("refine")!.handler("", ctx);
  assert.match(calls.notifications.at(-1)!.message, /only reasoning/);
  assert.equal(calls.editorWrites.length, 0);
});

test("model errors are reported without touching the editor", async () => {
  const calls = freshCalls();
  const { commands } = setup({ minChars: 0 });
  const ctx = makeCtx({
    calls,
    editorText: "a draft long enough to refine",
    response: { role: "assistant", content: [], stopReason: "error", errorMessage: "upstream 500" },
  });

  await commands.get("refine")!.handler("", ctx);
  assert.match(calls.notifications.at(-1)!.message, /upstream 500/);
  assert.equal(calls.editorWrites.length, 0);
});

test("an aborted refinement reports nothing", async () => {
  const calls = freshCalls();
  const { commands } = setup({ minChars: 0 });
  const ctx = makeCtx({
    calls,
    editorText: "a draft long enough to refine",
    response: { role: "assistant", content: [], stopReason: "aborted" },
  });

  await commands.get("refine")!.handler("", ctx);
  assert.equal(calls.editorWrites.length, 0);
  assert.equal(calls.notifications.length, 0);
});

test("over-long refinements are rejected as leaked reasoning", async () => {
  const calls = freshCalls();
  const { commands } = setup({ minChars: 0, resultMaxChars: 20 });
  const ctx = makeCtx({
    calls,
    editorText: "a draft long enough to refine",
    response: {
      role: "assistant",
      content: [{ type: "text", text: "z".repeat(200) }],
      stopReason: "stop",
      usage: { input: 1, output: 1 },
    },
  });

  await commands.get("refine")!.handler("", ctx);
  assert.equal(calls.editorWrites.length, 0);
  assert.match(calls.notifications.at(-1)!.message, /longer than 20/);
});

test("/refine reload re-reads config without throwing", async () => {
  const calls = freshCalls();
  const { commands } = setup();
  const ctx = makeCtx({ calls });

  await commands.get("refine")!.handler("reload", ctx);
  assert.match(calls.notifications.at(-1)!.message, /config reloaded/);
});

test("conversation context reads the branch and skips tool payloads", () => {
  const { api } = setup();
  const entries = [
    { type: "message", message: { role: "user", content: "first question" } },
    { type: "message", message: { role: "assistant", content: [{ type: "thinking", thinking: "hmm" }] } },
    { type: "message", message: { role: "assistant", content: [{ type: "text", text: "first answer" }] } },
    { type: "message", message: { role: "toolResult", content: [{ type: "text", text: "huge output" }] } },
    { type: "message", message: { role: "user", content: [{ type: "text", text: "second question" }] } },
  ];
  const ctx = { sessionManager: { getEntries: () => entries } } as never;

  const text = api.getRecentConversationContext(ctx);
  assert.match(text, /User: first question/);
  assert.match(text, /Assistant: first answer/);
  assert.match(text, /User: second question/);
  assert.doesNotMatch(text, /huge output/);

  const empty = api.getRecentConversationContext({ sessionManager: { getEntries: () => [] } } as never);
  assert.equal(empty, "(No previous conversation in this session)");
});

test("formatMeta renders model, size change, latency, cache and tokens", () => {
  const { api } = setup();
  const result: RefineResult = {
    original: "a",
    refined: "b",
    model: "cp",
    charsBefore: 12,
    charsAfter: 38,
    latencyMs: 800,
    cached: false,
    inputTokens: 150,
    outputTokens: 90,
  };
  assert.equal(api.formatMeta(result), "cp \u00b7 12\u219238 chars \u00b7 0.8s \u00b7 150+90 tok");
  assert.match(api.formatMeta({ ...result, cached: true }), /cache hit/);
  assert.doesNotMatch(api.formatMeta({ ...result, inputTokens: null, outputTokens: null }), /tok/);
});
