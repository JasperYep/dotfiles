import type { AssistantMessage, Context, Model, UserMessage } from "@earendil-works/pi-ai";
import type { ExtensionAPI, ExtensionCommandContext, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { BorderedLoader } from "@earendil-works/pi-coding-agent";
import * as fs from "node:fs";
import * as path from "node:path";

const TARGET_MODEL_ID = "gemini-3.7-flash-high";

const REFINER_SYSTEM_PROMPT = `You are a prompt refiner acting as a composer middleware in an interactive coding agent session.
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

Output requirement:
Output ONLY the rewritten prompt text. Do not include introductory notes, explanations, or enclosing markdown code fences around the entire response.`;

/** Clean up accidental markdown code fence wrapper or enclosing quotes if the model emitted one */
function stripEnclosingCodeBlock(text: string): string {
  let trimmed = text.trim();
  const match = trimmed.match(/^```(?:markdown|text|prompt)?\s*\n([\s\S]*?)\n```$/i);
  if (match && match[1]) {
    trimmed = match[1].trim();
  }
  if (
    (trimmed.startsWith('"') && trimmed.endsWith('"') && trimmed.length >= 2) ||
    (trimmed.startsWith('“') && trimmed.endsWith('”') && trimmed.length >= 2)
  ) {
    trimmed = trimmed.slice(1, -1).trim();
  }
  return trimmed;
}

/** Extract project context from AGENTS.md, CLAUDE.md, or system prompt */
function getProjectContext(ctx: ExtensionContext): string {
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

  // Fallback to basic system prompt snippet
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

/** Extract recent conversation turns cleanly without bulky tool result payloads */
function getRecentConversationContext(ctx: ExtensionContext, maxTurns = 6): string {
  const sessionCtx = ctx.sessionManager.buildSessionContext();
  const messages = sessionCtx.messages;
  if (!messages || messages.length === 0) {
    return "(No previous conversation in this session)";
  }

  const recent = messages.slice(-maxTurns * 2);
  const formatted: string[] = [];

  for (const msg of recent) {
    if (msg.role === "user") {
      let text = "";
      if (typeof msg.content === "string") {
        text = msg.content;
      } else if (Array.isArray(msg.content)) {
        text = msg.content
          .filter((c): c is { type: "text"; text: string } => c.type === "text")
          .map((c) => c.text)
          .join("\n");
      }
      if (text.trim()) {
        formatted.push(`User: ${text.trim().slice(0, 800)}`);
      }
    } else if (msg.role === "assistant") {
      const textParts = msg.content
        .filter((c): c is { type: "text"; text: string } => c.type === "text")
        .map((c) => c.text)
        .join("\n")
        .trim();
      if (textParts) {
        formatted.push(`Assistant: ${textParts.slice(0, 800)}`);
      }
    }
  }

  return formatted.length > 0 ? formatted.join("\n\n") : "(No previous text conversation)";
}

/** Resolve the target model for refinement (preferred gemini-3.7-flash-high, fallback to active model) */
function resolveRefinerModel(ctx: ExtensionContext): Model<any> | undefined {
  const allModels = ctx.modelRegistry.getAll();
  const match = allModels.find(
    (m) => m.id === TARGET_MODEL_ID || m.id.toLowerCase().includes(TARGET_MODEL_ID.toLowerCase()),
  );

  if (match && ctx.modelRegistry.hasConfiguredAuth(match)) {
    return match;
  }

  return ctx.model;
}

export default function promptRefinerExtension(pi: ExtensionAPI) {
  let lastOriginalText: string | null = null;

  async function performRefinement(draft: string, ctx: ExtensionCommandContext): Promise<void> {
    const rawDraft = draft.trim();
    if (!rawDraft) {
      ctx.ui.notify("No prompt content to refine", "warning");
      return;
    }

    const refinerModel = resolveRefinerModel(ctx);
    if (!refinerModel) {
      ctx.ui.notify("No available model found for refinement", "error");
      return;
    }

    const projectContext = getProjectContext(ctx);
    const recentConversation = getRecentConversationContext(ctx);

    const userPromptPayload = `<project_context>
${projectContext || "(None)"}
</project_context>

<recent_conversation>
${recentConversation}
</recent_conversation>

<draft_instruction>
${rawDraft}
</draft_instruction>`;

    const userMessage: UserMessage = {
      role: "user",
      content: [{ type: "text", text: userPromptPayload }],
      timestamp: Date.now(),
    };

    const requestContext: Context = {
      systemPrompt: REFINER_SYSTEM_PROMPT,
      messages: [userMessage],
    };

    let refinedText: string | null = null;

    if (ctx.mode === "tui") {
      refinedText = await ctx.ui.custom<string | null>((tui, theme, _kb, done) => {
        const loader = new BorderedLoader(
          tui,
          theme,
          `Refining prompt with ${refinerModel.id}...`,
        );
        loader.onAbort = () => done(null);

        const run = async () => {
          try {
            const response: AssistantMessage = await ctx.modelRegistry.complete(
              refinerModel,
              requestContext,
              { signal: loader.signal, maxTokens: 2048 },
            );

            if (response.stopReason === "aborted") {
              return null;
            }

            if (response.stopReason === "error") {
              ctx.ui.notify(`Refinement failed: ${response.errorMessage || "Unknown error"}`, "error");
              return null;
            }

            const text = response.content
              .filter((c): c is { type: "text"; text: string } => c.type === "text")
              .map((c) => c.text)
              .join("\n");

            return stripEnclosingCodeBlock(text);
          } catch (err) {
            const msg = err instanceof Error ? err.message : String(err);
            ctx.ui.notify(`Refinement error: ${msg}`, "error");
            return null;
          }
        };

        run()
          .then(done)
          .catch(() => done(null));

        return loader;
      });
    } else {
      try {
        const response = await ctx.modelRegistry.complete(refinerModel, requestContext, {
          signal: ctx.signal,
          maxTokens: 2048,
        });
        if (response.stopReason === "error") {
          ctx.ui.notify(`Refinement failed: ${response.errorMessage || "Unknown error"}`, "error");
          return;
        }
        const text = response.content
          .filter((c): c is { type: "text"; text: string } => c.type === "text")
          .map((c) => c.text)
          .join("\n");
        refinedText = stripEnclosingCodeBlock(text);
      } catch (err) {
        const msg = err instanceof Error ? err.message : String(err);
        ctx.ui.notify(`Refinement error: ${msg}`, "error");
        return;
      }
    }

    if (!refinedText) {
      return;
    }

    lastOriginalText = rawDraft;
    ctx.ui.setEditorText(refinedText);
    ctx.ui.notify(`Prompt refined with ${refinerModel.id} (Run '/refine undo' to revert)`, "info");
  }

  // Register /refine command
  pi.registerCommand("refine", {
    description: "Refine draft prompt using gemini-3.7-flash-high (Usage: /refine [prompt] | /refine undo)",
    handler: async (args, ctx) => {
      const trimmedArgs = args?.trim() ?? "";

      if (trimmedArgs.toLowerCase() === "undo") {
        if (!lastOriginalText) {
          ctx.ui.notify("No previous prompt to undo", "warning");
          return;
        }
        ctx.ui.setEditorText(lastOriginalText);
        ctx.ui.notify("Reverted to original prompt", "info");
        return;
      }

      if (trimmedArgs.length > 0) {
        await performRefinement(trimmedArgs, ctx);
        return;
      }

      // If no arguments passed, read from current editor
      const editorText = ctx.ui.getEditorText().trim();
      if (editorText.length > 0) {
        await performRefinement(editorText, ctx);
        return;
      }

      // If editor is also empty, open an interactive input/editor dialog
      if (ctx.hasUI) {
        const input = await ctx.ui.editor("Enter prompt to refine:", "");
        if (input && input.trim()) {
          await performRefinement(input.trim(), ctx);
        }
      } else {
        ctx.ui.notify("Please provide a prompt to refine: /refine <prompt>", "warning");
      }
    },
  });
}
